"""Property verification / KYC router (Wave 18).

Hosts submit ownership documents; admins review them.

Flow:
1. Host POSTs ``/verifications/{property_id}/submit`` with document URLs
   (already uploaded to S3 via ``POST /properties/{pid}/images`` or a
   future dedicated endpoint).
2. Admin reviews via ``/verifications/pending`` + ``/verifications/{vid}``.
3. Admin flips status to approved / rejected / needs_edit.  Approving
   also sets ``Property.is_verified = True``.
"""

from __future__ import annotations

from datetime import datetime, timezone
from typing import Optional

import structlog
from fastapi import APIRouter, Depends, HTTPException, Query, status
from pydantic import BaseModel, Field
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.middleware.auth_middleware import get_current_active_user, require_role
from app.models.notification import NotificationType
from app.models.property import Property
from app.models.property_verification import (
    DocumentType,
    PropertyVerification,
    VerificationStatus,
)
from app.models.user import User, UserRole
from app.services.notification_service import create_notification

logger = structlog.get_logger(__name__)
router = APIRouter(prefix="/verifications", tags=["Verifications"])

_admin_only = require_role(UserRole.admin)


# ── Schemas ──────────────────────────────────────────────

class VerificationSubmit(BaseModel):
    document_urls: list[str] = Field(..., min_length=1, max_length=10)
    primary_document_type: DocumentType = DocumentType.ownership_contract
    host_note: Optional[str] = Field(None, max_length=2000)


class VerificationReview(BaseModel):
    admin_note: Optional[str] = Field(None, max_length=2000)


class VerificationOut(BaseModel):
    id: int
    property_id: int
    submitted_by: Optional[int]
    reviewed_by: Optional[int]
    status: VerificationStatus
    document_urls: list[str]
    primary_document_type: DocumentType
    host_note: Optional[str]
    admin_note: Optional[str]
    submitted_at: datetime
    reviewed_at: Optional[datetime]

    model_config = {"from_attributes": True}


# ══════════════════════════════════════════════════════════════
#  Host endpoints
# ══════════════════════════════════════════════════════════════

@router.post(
    "/{property_id}/submit",
    response_model=VerificationOut,
    status_code=status.HTTP_201_CREATED,
)
async def submit_verification(
    property_id: int,
    body: VerificationSubmit,
    user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db),
):
    """Host uploads ownership documents for admin review."""
    prop = (await db.execute(
        select(Property).where(Property.id == property_id)
    )).scalar_one_or_none()
    if prop is None:
        raise HTTPException(status_code=404, detail="العقار غير موجود / Property not found")
    if prop.owner_id != user.id and user.role != UserRole.admin:
        raise HTTPException(status_code=403, detail="ليس لديك صلاحية / Forbidden")

    # Allow only one pending verification at a time per property.
    existing = (await db.execute(
        select(PropertyVerification).where(
            PropertyVerification.property_id == property_id,
            PropertyVerification.status == VerificationStatus.pending,
        )
    )).scalar_one_or_none()
    if existing is not None:
        raise HTTPException(
            status_code=409,
            detail="يوجد طلب توثيق قيد المراجعة / Pending verification already exists",
        )

    verification = PropertyVerification(
        property_id=property_id,
        submitted_by=user.id,
        status=VerificationStatus.pending,
        document_urls=body.document_urls,
        primary_document_type=body.primary_document_type,
        host_note=body.host_note,
    )
    db.add(verification)
    await db.flush()
    await db.refresh(verification)
    logger.info("verification_submitted", verif_id=verification.id, property_id=property_id)
    return VerificationOut.model_validate(verification)


@router.get(
    "/my/{property_id}",
    response_model=list[VerificationOut],
)
async def my_verifications(
    property_id: int,
    user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db),
):
    """Host lists verification history for one of their properties."""
    prop = (await db.execute(
        select(Property).where(Property.id == property_id)
    )).scalar_one_or_none()
    if prop is None:
        raise HTTPException(status_code=404, detail="العقار غير موجود / Property not found")
    if prop.owner_id != user.id and user.role != UserRole.admin:
        raise HTTPException(status_code=403, detail="ليس لديك صلاحية / Forbidden")

    rows = (await db.execute(
        select(PropertyVerification)
        .where(PropertyVerification.property_id == property_id)
        .order_by(PropertyVerification.submitted_at.desc())
    )).scalars().all()
    return [VerificationOut.model_validate(r) for r in rows]


# ══════════════════════════════════════════════════════════════
#  Admin endpoints
# ══════════════════════════════════════════════════════════════

@router.get("/pending", response_model=list[VerificationOut])
async def list_pending(
    limit: int = Query(50, ge=1, le=200),
    _: User = Depends(_admin_only),
    db: AsyncSession = Depends(get_db),
):
    rows = (await db.execute(
        select(PropertyVerification)
        .where(PropertyVerification.status == VerificationStatus.pending)
        .order_by(PropertyVerification.submitted_at.asc())
        .limit(limit)
    )).scalars().all()
    return [VerificationOut.model_validate(r) for r in rows]


@router.get("/{verification_id}", response_model=VerificationOut)
async def get_verification(
    verification_id: int,
    _: User = Depends(_admin_only),
    db: AsyncSession = Depends(get_db),
):
    row = (await db.execute(
        select(PropertyVerification)
        .where(PropertyVerification.id == verification_id)
    )).scalar_one_or_none()
    if row is None:
        raise HTTPException(status_code=404, detail="Verification not found")
    return VerificationOut.model_validate(row)


async def _transition(
    db: AsyncSession,
    verification_id: int,
    reviewer: User,
    new_status: VerificationStatus,
    admin_note: Optional[str],
) -> PropertyVerification:
    row = (await db.execute(
        select(PropertyVerification)
        .where(PropertyVerification.id == verification_id)
    )).scalar_one_or_none()
    if row is None:
        raise HTTPException(status_code=404, detail="Verification not found")
    if row.status != VerificationStatus.pending:
        raise HTTPException(
            status_code=409,
            detail="تمت مراجعة الطلب بالفعل / Already reviewed",
        )

    row.status = new_status
    row.reviewed_by = reviewer.id
    row.reviewed_at = datetime.now(timezone.utc)
    if admin_note is not None:
        row.admin_note = admin_note

    # Flip property's is_verified flag if approved
    if new_status == VerificationStatus.approved:
        prop = (await db.execute(
            select(Property).where(Property.id == row.property_id)
        )).scalar_one_or_none()
        if prop is not None:
            prop.is_verified = True

    # Notify the host
    if row.submitted_by:
        status_labels = {
            VerificationStatus.approved: ("✅ تم توثيق العقار", "Property verified"),
            VerificationStatus.rejected: ("❌ رُفض طلب التوثيق", "Verification rejected"),
            VerificationStatus.needs_edit: ("✏️ مطلوب تعديل", "Verification needs edits"),
        }
        title_ar, title_en = status_labels.get(new_status, ("", ""))
        try:
            await create_notification(
                db,
                user_id=row.submitted_by,
                title=title_ar,
                body=(admin_note or title_en or ""),
                notif_type=NotificationType.system,
                data={"verification_id": str(row.id), "property_id": str(row.property_id)},
            )
        except Exception as exc:
            logger.warning("verification_notif_failed", error=str(exc))

    await db.flush()
    await db.refresh(row)
    logger.info(
        "verification_reviewed",
        verif_id=row.id, new_status=new_status.value, admin_id=reviewer.id,
    )
    return row


@router.post("/{verification_id}/approve", response_model=VerificationOut)
async def approve_verification(
    verification_id: int,
    body: VerificationReview | None = None,
    me: User = Depends(_admin_only),
    db: AsyncSession = Depends(get_db),
):
    row = await _transition(
        db, verification_id, me,
        VerificationStatus.approved,
        body.admin_note if body else None,
    )
    return VerificationOut.model_validate(row)


@router.post("/{verification_id}/reject", response_model=VerificationOut)
async def reject_verification(
    verification_id: int,
    body: VerificationReview,
    me: User = Depends(_admin_only),
    db: AsyncSession = Depends(get_db),
):
    row = await _transition(
        db, verification_id, me,
        VerificationStatus.rejected,
        body.admin_note,
    )
    return VerificationOut.model_validate(row)


@router.post("/{verification_id}/needs-edit", response_model=VerificationOut)
async def needs_edit_verification(
    verification_id: int,
    body: VerificationReview,
    me: User = Depends(_admin_only),
    db: AsyncSession = Depends(get_db),
):
    row = await _transition(
        db, verification_id, me,
        VerificationStatus.needs_edit,
        body.admin_note,
    )
    return VerificationOut.model_validate(row)
