"""Admin notification-campaign router.

Lets admins compose broadcast push notifications, preview audience size,
and fire them off.  Actual delivery is performed inline (async) against
every target user via :func:`app.services.push_service.push_to_user`.

All endpoints require the admin role.
"""

from __future__ import annotations

from datetime import datetime, timezone
from typing import Optional

import structlog
from fastapi import APIRouter, Depends, HTTPException, Query, Request, status
from pydantic import BaseModel, Field
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.middleware.auth_middleware import require_role
from app.models.booking import Booking
from app.models.notification_campaign import (
    CampaignAudience,
    CampaignStatus,
    NotificationCampaign,
)
from app.models.property import Property
from app.models.user import User, UserRole
from app.services.notification_service import create_notification
from app.services.push_service import push_to_user
from app.models.notification import NotificationType

logger = structlog.get_logger(__name__)
router = APIRouter(prefix="/campaigns", tags=["Campaigns"])

_admin_only = require_role(UserRole.admin)


# ── Schemas ──────────────────────────────────────────────

class CampaignCreate(BaseModel):
    title_ar: str = Field(..., min_length=1, max_length=200)
    body_ar: str = Field(..., min_length=1)
    title_en: Optional[str] = Field(None, max_length=200)
    body_en: Optional[str] = None
    audience: CampaignAudience
    filter_area: Optional[str] = Field(None, max_length=100)
    filter_recent_days: Optional[int] = Field(None, ge=1, le=365)
    deeplink: Optional[str] = Field(None, max_length=500)
    scheduled_at: Optional[datetime] = None


class CampaignUpdate(BaseModel):
    title_ar: Optional[str] = Field(None, min_length=1, max_length=200)
    body_ar: Optional[str] = Field(None, min_length=1)
    title_en: Optional[str] = Field(None, max_length=200)
    body_en: Optional[str] = None
    audience: Optional[CampaignAudience] = None
    filter_area: Optional[str] = Field(None, max_length=100)
    filter_recent_days: Optional[int] = Field(None, ge=1, le=365)
    deeplink: Optional[str] = Field(None, max_length=500)
    scheduled_at: Optional[datetime] = None


class CampaignOut(BaseModel):
    id: int
    created_by: Optional[int]
    title_ar: str
    title_en: Optional[str]
    body_ar: str
    body_en: Optional[str]
    deeplink: Optional[str]
    audience: CampaignAudience
    filter_area: Optional[str]
    filter_recent_days: Optional[int]
    status: CampaignStatus
    scheduled_at: Optional[datetime]
    sent_at: Optional[datetime]
    target_count: int
    success_count: int
    created_at: datetime

    model_config = {"from_attributes": True}


class AudiencePreview(BaseModel):
    count: int


# ── Audience resolution ──────────────────────────────────

async def _resolve_audience_users(
    db: AsyncSession, campaign: NotificationCampaign,
) -> list[int]:
    """Return user IDs matching the campaign's audience filters."""
    stmt = select(User.id).where(User.is_active.is_(True))

    if campaign.audience == CampaignAudience.hosts:
        stmt = stmt.where(User.role == UserRole.owner)
    elif campaign.audience == CampaignAudience.guests:
        stmt = stmt.where(User.role == UserRole.guest)
    elif campaign.audience == CampaignAudience.by_area:
        if not campaign.filter_area:
            raise HTTPException(
                status_code=422,
                detail="filter_area required for by_area audience",
            )
        # Users who own a property in this area OR who've booked one.
        owner_ids_sq = (
            select(Property.owner_id)
            .where(Property.area == campaign.filter_area)
        )
        booker_ids_sq = (
            select(Booking.guest_id)
            .join(Property, Property.id == Booking.property_id)
            .where(Property.area == campaign.filter_area)
        )
        stmt = stmt.where(
            User.id.in_(owner_ids_sq) | User.id.in_(booker_ids_sq)
        )
    elif campaign.audience == CampaignAudience.recent_bookers:
        days = campaign.filter_recent_days or 30
        from datetime import timedelta
        cutoff = datetime.now(timezone.utc) - timedelta(days=days)
        recent_sq = (
            select(Booking.guest_id)
            .where(Booking.created_at >= cutoff)
        )
        stmt = stmt.where(User.id.in_(recent_sq))
    # all_users → no extra filter

    rows = (await db.execute(stmt)).all()
    return [r[0] for r in rows]


# ══════════════════════════════════════════════════════════════
#  CRUD
# ══════════════════════════════════════════════════════════════

@router.get("", response_model=list[CampaignOut])
async def list_campaigns(
    status_filter: CampaignStatus | None = Query(None, alias="status"),
    _: User = Depends(_admin_only),
    db: AsyncSession = Depends(get_db),
):
    stmt = (
        select(NotificationCampaign)
        .order_by(NotificationCampaign.created_at.desc())
        .limit(100)
    )
    if status_filter:
        stmt = stmt.where(NotificationCampaign.status == status_filter)
    rows = (await db.execute(stmt)).scalars().all()
    return [CampaignOut.model_validate(r) for r in rows]


@router.post("", response_model=CampaignOut, status_code=status.HTTP_201_CREATED)
async def create_campaign(
    body: CampaignCreate,
    me: User = Depends(_admin_only),
    db: AsyncSession = Depends(get_db),
):
    initial_status = (
        CampaignStatus.scheduled
        if body.scheduled_at and body.scheduled_at > datetime.now(timezone.utc)
        else CampaignStatus.draft
    )
    camp = NotificationCampaign(
        created_by=me.id,
        title_ar=body.title_ar,
        title_en=body.title_en,
        body_ar=body.body_ar,
        body_en=body.body_en,
        deeplink=body.deeplink,
        audience=body.audience,
        filter_area=body.filter_area,
        filter_recent_days=body.filter_recent_days,
        status=initial_status,
        scheduled_at=body.scheduled_at,
    )
    db.add(camp)
    await db.flush()
    await db.refresh(camp)
    logger.info("campaign_created", campaign_id=camp.id, admin_id=me.id)
    return CampaignOut.model_validate(camp)


@router.get("/{campaign_id}", response_model=CampaignOut)
async def get_campaign(
    campaign_id: int,
    _: User = Depends(_admin_only),
    db: AsyncSession = Depends(get_db),
):
    camp = (await db.execute(
        select(NotificationCampaign).where(NotificationCampaign.id == campaign_id)
    )).scalar_one_or_none()
    if camp is None:
        raise HTTPException(status_code=404, detail="الحملة غير موجودة / Campaign not found")
    return CampaignOut.model_validate(camp)


@router.put("/{campaign_id}", response_model=CampaignOut)
async def update_campaign(
    campaign_id: int,
    body: CampaignUpdate,
    _: User = Depends(_admin_only),
    db: AsyncSession = Depends(get_db),
):
    camp = (await db.execute(
        select(NotificationCampaign).where(NotificationCampaign.id == campaign_id)
    )).scalar_one_or_none()
    if camp is None:
        raise HTTPException(status_code=404, detail="الحملة غير موجودة / Campaign not found")
    if camp.status not in (CampaignStatus.draft, CampaignStatus.scheduled):
        raise HTTPException(
            status_code=409,
            detail="لا يمكن تعديل الحملة في هذه الحالة / Cannot edit sent/cancelled campaign",
        )
    for field, value in body.model_dump(exclude_unset=True).items():
        setattr(camp, field, value)
    await db.flush()
    await db.refresh(camp)
    return CampaignOut.model_validate(camp)


@router.delete("/{campaign_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_campaign(
    campaign_id: int,
    _: User = Depends(_admin_only),
    db: AsyncSession = Depends(get_db),
):
    camp = (await db.execute(
        select(NotificationCampaign).where(NotificationCampaign.id == campaign_id)
    )).scalar_one_or_none()
    if camp is None:
        raise HTTPException(status_code=404, detail="الحملة غير موجودة / Campaign not found")
    if camp.status == CampaignStatus.sending:
        raise HTTPException(status_code=409, detail="Campaign is currently sending")
    await db.delete(camp)
    await db.flush()


# ══════════════════════════════════════════════════════════════
#  Audience preview & send
# ══════════════════════════════════════════════════════════════

@router.get("/{campaign_id}/preview", response_model=AudiencePreview)
async def preview_audience(
    campaign_id: int,
    _: User = Depends(_admin_only),
    db: AsyncSession = Depends(get_db),
):
    """Return the number of users that match the campaign's audience."""
    camp = (await db.execute(
        select(NotificationCampaign).where(NotificationCampaign.id == campaign_id)
    )).scalar_one_or_none()
    if camp is None:
        raise HTTPException(status_code=404, detail="الحملة غير موجودة / Campaign not found")
    user_ids = await _resolve_audience_users(db, camp)
    return AudiencePreview(count=len(user_ids))


@router.post("/{campaign_id}/send", response_model=CampaignOut)
async def send_campaign(
    campaign_id: int,
    request: Request,
    _: User = Depends(_admin_only),
    db: AsyncSession = Depends(get_db),
):
    """Fire the campaign – create in-app notifications + push to every target."""
    camp = (await db.execute(
        select(NotificationCampaign).where(NotificationCampaign.id == campaign_id)
    )).scalar_one_or_none()
    if camp is None:
        raise HTTPException(status_code=404, detail="الحملة غير موجودة / Campaign not found")
    if camp.status in (CampaignStatus.sending, CampaignStatus.sent):
        raise HTTPException(
            status_code=409,
            detail="تم إرسال الحملة بالفعل / Already sent",
        )

    user_ids = await _resolve_audience_users(db, camp)
    camp.status = CampaignStatus.sending
    camp.target_count = len(user_ids)
    await db.flush()

    # Prefer Arabic for in-app notifications (Flutter picks via locale).
    # A future iteration can per-user localise; for now we send the AR text
    # and fall back to EN if AR is empty.
    title = camp.title_ar or camp.title_en or ""
    body = camp.body_ar or camp.body_en or ""

    success = 0
    data = {"campaign_id": str(camp.id)}
    if camp.deeplink:
        data["deeplink"] = camp.deeplink

    for uid in user_ids:
        try:
            # Create an in-app notification row (also pushes via push_to_user
            # when push=True and the service is enabled)
            await create_notification(
                db,
                user_id=uid,
                title=title,
                body=body,
                notif_type=NotificationType.system,
                data=data,
                push=False,  # we push separately below to avoid duplicate sends
            )
            pushed = await push_to_user(db, uid, title=title, body=body, data=data)
            if pushed > 0:
                success += 1
        except Exception as exc:  # pragma: no cover - best-effort
            logger.warning("campaign_user_send_failed", user_id=uid, error=str(exc))

    camp.status = CampaignStatus.sent
    camp.sent_at = datetime.now(timezone.utc)
    camp.success_count = success
    await db.flush()
    await db.refresh(camp)

    logger.info(
        "campaign_sent",
        campaign_id=camp.id,
        targets=camp.target_count,
        pushed=success,
    )
    return CampaignOut.model_validate(camp)


@router.post("/{campaign_id}/cancel", response_model=CampaignOut)
async def cancel_campaign(
    campaign_id: int,
    _: User = Depends(_admin_only),
    db: AsyncSession = Depends(get_db),
):
    """Cancel a draft or scheduled campaign before it is sent."""
    camp = (await db.execute(
        select(NotificationCampaign).where(NotificationCampaign.id == campaign_id)
    )).scalar_one_or_none()
    if camp is None:
        raise HTTPException(status_code=404, detail="الحملة غير موجودة / Campaign not found")
    if camp.status not in (CampaignStatus.draft, CampaignStatus.scheduled):
        raise HTTPException(
            status_code=409,
            detail="لا يمكن إلغاء الحملة / Cannot cancel this campaign",
        )
    camp.status = CampaignStatus.cancelled
    await db.flush()
    await db.refresh(camp)
    return CampaignOut.model_validate(camp)
