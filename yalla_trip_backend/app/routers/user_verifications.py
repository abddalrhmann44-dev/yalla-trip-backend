"""Guest / user identity verification router (Wave 19).

Flow:
1. User POSTs ``/me/verification`` with ID-front, ID-back (optional),
   and a selfie URL already uploaded to S3.
2. Admin lists pending via ``/admin/user-verifications/pending``.
3. Admin approves / rejects.  Approval sets ``User.is_verified = True``.

Hosts can optionally require verified guests via a future
``Property.require_verified_guests`` flag; this router only builds the
verification primitives.
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
from app.models.user import User, UserRole
from app.models.user_verification import (
    UserIdDocType,
    UserVerification,
    UserVerificationStatus,
)
from app.services.notification_service import create_notification

logger = structlog.get_logger(__name__)
router = APIRouter(tags=["UserVerifications"])

_admin_only = require_role(UserRole.admin)


# ── Schemas ──────────────────────────────────────────────

class UserVerificationSubmit(BaseModel):
    id_doc_type: UserIdDocType = UserIdDocType.national_id
    id_front_url: str = Field(..., max_length=512)
    id_back_url: Optional[str] = Field(None, max_length=512)
    selfie_url: str = Field(..., max_length=512)


class UserVerificationReview(BaseModel):
    admin_note: Optional[str] = Field(None, max_length=2000)


class UserVerificationOut(BaseModel):
    id: int
    user_id: int
    reviewed_by: Optional[int]
    status: UserVerificationStatus
    id_doc_type: UserIdDocType
    id_front_url: str
    id_back_url: Optional[str]
    selfie_url: str
    admin_note: Optional[str]
    submitted_at: datetime
    reviewed_at: Optional[datetime]

    model_config = {"from_attributes": True}


# ══════════════════════════════════════════════════════════════
#  User endpoints
# ══════════════════════════════════════════════════════════════

@router.post(
    "/me/verification",
    response_model=UserVerificationOut,
    status_code=status.HTTP_201_CREATED,
)
async def submit_my_verification(
    body: UserVerificationSubmit,
    user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db),
):
    """Upload ID + selfie for admin review."""
    # Reject if a pending submission already exists
    existing = (await db.execute(
        select(UserVerification).where(
            UserVerification.user_id == user.id,
            UserVerification.status == UserVerificationStatus.pending,
        )
    )).scalar_one_or_none()
    if existing is not None:
        raise HTTPException(
            status_code=409,
            detail="يوجد طلب قيد المراجعة / Pending verification already exists",
        )

    row = UserVerification(
        user_id=user.id,
        status=UserVerificationStatus.pending,
        id_doc_type=body.id_doc_type,
        id_front_url=body.id_front_url,
        id_back_url=body.id_back_url,
        selfie_url=body.selfie_url,
    )
    db.add(row)
    await db.flush()
    await db.refresh(row)
    logger.info("user_verification_submitted", verif_id=row.id, user_id=user.id)
    return UserVerificationOut.model_validate(row)


@router.get(
    "/me/verification",
    response_model=list[UserVerificationOut],
)
async def my_verifications(
    user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db),
):
    """List current user's KYC submissions (newest first)."""
    rows = (await db.execute(
        select(UserVerification)
        .where(UserVerification.user_id == user.id)
        .order_by(UserVerification.submitted_at.desc())
    )).scalars().all()
    return [UserVerificationOut.model_validate(r) for r in rows]


# ══════════════════════════════════════════════════════════════
#  Admin endpoints
# ══════════════════════════════════════════════════════════════

@router.get(
    "/admin/user-verifications/pending",
    response_model=list[UserVerificationOut],
)
async def list_pending_user_verifications(
    limit: int = Query(50, ge=1, le=200),
    _: User = Depends(_admin_only),
    db: AsyncSession = Depends(get_db),
):
    rows = (await db.execute(
        select(UserVerification)
        .where(UserVerification.status == UserVerificationStatus.pending)
        .order_by(UserVerification.submitted_at.asc())
        .limit(limit)
    )).scalars().all()
    return [UserVerificationOut.model_validate(r) for r in rows]


@router.get(
    "/admin/user-verifications/{verification_id}",
    response_model=UserVerificationOut,
)
async def get_user_verification(
    verification_id: int,
    _: User = Depends(_admin_only),
    db: AsyncSession = Depends(get_db),
):
    row = (await db.execute(
        select(UserVerification).where(UserVerification.id == verification_id)
    )).scalar_one_or_none()
    if row is None:
        raise HTTPException(status_code=404, detail="Verification not found")
    return UserVerificationOut.model_validate(row)


async def _transition(
    db: AsyncSession,
    verification_id: int,
    reviewer: User,
    new_status: UserVerificationStatus,
    admin_note: Optional[str],
) -> UserVerification:
    row = (await db.execute(
        select(UserVerification).where(UserVerification.id == verification_id)
    )).scalar_one_or_none()
    if row is None:
        raise HTTPException(status_code=404, detail="Verification not found")
    if row.status != UserVerificationStatus.pending:
        raise HTTPException(
            status_code=409,
            detail="تمت مراجعة الطلب بالفعل / Already reviewed",
        )

    row.status = new_status
    row.reviewed_by = reviewer.id
    row.reviewed_at = datetime.now(timezone.utc)
    if admin_note is not None:
        row.admin_note = admin_note

    # Flip user's is_verified flag on approval
    if new_status == UserVerificationStatus.approved:
        target = (await db.execute(
            select(User).where(User.id == row.user_id)
        )).scalar_one_or_none()
        if target is not None:
            target.is_verified = True

    # Notify the submitter
    status_labels = {
        UserVerificationStatus.approved: "✅ تم توثيق حسابك",
        UserVerificationStatus.rejected: "❌ رُفض طلب التوثيق",
        UserVerificationStatus.needs_edit: "✏️ مطلوب تعديل في بيانات التوثيق",
    }
    try:
        await create_notification(
            db,
            user_id=row.user_id,
            title=status_labels.get(new_status, ""),
            body=(admin_note or ""),
            notif_type=NotificationType.system,
            data={"verification_id": str(row.id)},
        )
    except Exception as exc:
        logger.warning("user_verif_notif_failed", error=str(exc))

    await db.flush()
    await db.refresh(row)
    logger.info(
        "user_verification_reviewed",
        verif_id=row.id, new_status=new_status.value, admin_id=reviewer.id,
    )
    return row


@router.post(
    "/admin/user-verifications/{verification_id}/approve",
    response_model=UserVerificationOut,
)
async def approve_user_verification(
    verification_id: int,
    body: UserVerificationReview | None = None,
    me: User = Depends(_admin_only),
    db: AsyncSession = Depends(get_db),
):
    row = await _transition(
        db, verification_id, me,
        UserVerificationStatus.approved,
        body.admin_note if body else None,
    )
    return UserVerificationOut.model_validate(row)


@router.post(
    "/admin/user-verifications/{verification_id}/reject",
    response_model=UserVerificationOut,
)
async def reject_user_verification(
    verification_id: int,
    body: UserVerificationReview,
    me: User = Depends(_admin_only),
    db: AsyncSession = Depends(get_db),
):
    row = await _transition(
        db, verification_id, me,
        UserVerificationStatus.rejected,
        body.admin_note,
    )
    return UserVerificationOut.model_validate(row)


@router.post(
    "/admin/user-verifications/{verification_id}/needs-edit",
    response_model=UserVerificationOut,
)
async def needs_edit_user_verification(
    verification_id: int,
    body: UserVerificationReview,
    me: User = Depends(_admin_only),
    db: AsyncSession = Depends(get_db),
):
    row = await _transition(
        db, verification_id, me,
        UserVerificationStatus.needs_edit,
        body.admin_note,
    )
    return UserVerificationOut.model_validate(row)
