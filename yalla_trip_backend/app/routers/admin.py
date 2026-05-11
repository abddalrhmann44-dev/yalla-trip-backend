"""Admin router – user/property management, stats dashboard."""

from __future__ import annotations

import math
from datetime import date, datetime

import structlog
from fastapi import APIRouter, Depends, HTTPException, Query, Request
from sqlalchemy import delete as sa_delete, func, select
from sqlalchemy.ext.asyncio import AsyncSession

from pydantic import BaseModel

from app.database import get_db
from app.middleware.auth_middleware import require_role
from app.models.api_key import ApiKey
from app.models.booking import Booking, BookingStatus, PaymentStatus
from app.models.chat import Conversation, Message
from app.models.feature_flag import (
    FeatureFlag, FeatureFlagAssignment, FlagKind,
)
from app.models.payment import Payment, PaymentState
from app.models.platform_setting import PlatformSetting
from app.models.promo_banner import BannerCtaKind, PromoBanner
from app.models.property import Property, PropertyStatus
from app.models.review import Review
from app.models.user import User, UserRole
from app.services.api_key_service import (
    ALLOWED_SCOPES, mint_new_key, validate_scopes,
)
from app.schemas.booking import BookingOut
from app.schemas.common import MessageResponse, PaginatedResponse
from app.schemas.property import PropertyOut
from app.schemas.user import UserOut
from app.services.audit_service import log_action


class _AdminNote(BaseModel):
    note: str | None = None


class _AdminRoleChange(BaseModel):
    role: UserRole


class _AdminVerifyFlag(BaseModel):
    is_verified: bool = True

logger = structlog.get_logger(__name__)
router = APIRouter(prefix="/admin", tags=["Admin"])

_admin_only = require_role(UserRole.admin)


# ── Users ─────────────────────────────────────────────────
@router.get("/users", response_model=PaginatedResponse[UserOut])
async def list_users(
    page: int = Query(1, ge=1),
    limit: int = Query(20, ge=1, le=100),
    role: UserRole | None = None,
    search: str | None = None,
    _: User = Depends(_admin_only),
    db: AsyncSession = Depends(get_db),
):
    stmt = select(User)
    if role:
        stmt = stmt.where(User.role == role)
    if search:
        stmt = stmt.where(User.name.ilike(f"%{search}%"))
    stmt = stmt.order_by(User.created_at.desc())

    total = (await db.execute(select(func.count()).select_from(stmt.subquery()))).scalar() or 0
    pages = math.ceil(total / limit) if total else 0

    rows = (await db.execute(stmt.offset((page - 1) * limit).limit(limit))).scalars().all()
    return PaginatedResponse(
        items=[UserOut.model_validate(r) for r in rows],
        total=total, page=page, limit=limit, pages=pages,
    )


@router.delete("/users/{user_id}", response_model=MessageResponse)
async def deactivate_user(
    user_id: int,
    request: Request,
    me: User = Depends(_admin_only),
    db: AsyncSession = Depends(get_db),
):
    if user_id == me.id:
        raise HTTPException(status_code=400, detail="لا يمكن تعطيل حسابك / Cannot disable yourself")
    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()
    if user is None:
        raise HTTPException(status_code=404, detail="المستخدم غير موجود / User not found")
    before = {"is_active": user.is_active}
    user.is_active = False
    await db.flush()
    await log_action(
        db, request=request, actor=me,
        action="user.deactivate",
        target_type="user", target_id=user_id,
        before=before, after={"is_active": False},
    )
    logger.info("admin_deactivated_user", user_id=user_id)
    return MessageResponse(
        message="User deactivated",
        message_ar="تم تعطيل المستخدم",
    )


@router.patch("/users/{user_id}/activate", response_model=UserOut)
async def activate_user(
    user_id: int,
    request: Request,
    me: User = Depends(_admin_only),
    db: AsyncSession = Depends(get_db),
):
    """Re-enable a previously deactivated account."""
    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()
    if user is None:
        raise HTTPException(status_code=404, detail="المستخدم غير موجود / User not found")
    before = {"is_active": user.is_active}
    user.is_active = True
    await db.flush()
    await db.refresh(user)
    await log_action(
        db, request=request, actor=me,
        action="user.activate",
        target_type="user", target_id=user_id,
        before=before, after={"is_active": True},
    )
    logger.info("admin_activated_user", user_id=user_id)
    return UserOut.model_validate(user)


@router.patch("/users/{user_id}/role", response_model=UserOut)
async def change_user_role(
    user_id: int,
    body: _AdminRoleChange,
    request: Request,
    me: User = Depends(_admin_only),
    db: AsyncSession = Depends(get_db),
):
    """Promote / demote a user (guest ↔ owner ↔ admin)."""
    if user_id == me.id and body.role != UserRole.admin:
        raise HTTPException(
            status_code=400,
            detail="لا يمكن تغيير صلاحياتك / Cannot demote yourself",
        )
    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()
    if user is None:
        raise HTTPException(status_code=404, detail="المستخدم غير موجود / User not found")
    before = {"role": user.role.value if user.role else None}
    user.role = body.role
    await db.flush()
    await db.refresh(user)
    await log_action(
        db, request=request, actor=me,
        action="user.role_change",
        target_type="user", target_id=user_id,
        before=before, after={"role": body.role.value},
    )
    logger.info("admin_changed_role", user_id=user_id, role=body.role.value)
    return UserOut.model_validate(user)


@router.patch("/users/{user_id}/verify", response_model=UserOut)
async def set_user_verified(
    user_id: int,
    body: _AdminVerifyFlag | None = None,
    _: User = Depends(_admin_only),
    db: AsyncSession = Depends(get_db),
):
    """Toggle the KYC-verified flag (blue checkmark) on a user."""
    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()
    if user is None:
        raise HTTPException(status_code=404, detail="المستخدم غير موجود / User not found")
    user.is_verified = body.is_verified if body else True
    await db.flush()
    await db.refresh(user)
    logger.info("admin_verified_user", user_id=user_id, verified=user.is_verified)
    return UserOut.model_validate(user)


# ── Properties ────────────────────────────────────────────
@router.get("/properties", response_model=PaginatedResponse[PropertyOut])
async def list_all_properties(
    page: int = Query(1, ge=1),
    limit: int = Query(20, ge=1, le=100),
    search: str | None = None,
    _: User = Depends(_admin_only),
    db: AsyncSession = Depends(get_db),
):
    stmt = select(Property)
    if search:
        stmt = stmt.where(Property.name.ilike(f"%{search}%"))
    stmt = stmt.order_by(Property.created_at.desc())

    total = (await db.execute(select(func.count()).select_from(stmt.subquery()))).scalar() or 0
    pages = math.ceil(total / limit) if total else 0

    rows = (await db.execute(stmt.offset((page - 1) * limit).limit(limit))).scalars().all()
    return PaginatedResponse(
        items=[PropertyOut.model_validate(r) for r in rows],
        total=total, page=page, limit=limit, pages=pages,
    )


@router.get("/properties/pending", response_model=PaginatedResponse[PropertyOut])
async def pending_properties_queue(
    page: int = Query(1, ge=1),
    limit: int = Query(20, ge=1, le=100),
    _: User = Depends(_admin_only),
    db: AsyncSession = Depends(get_db),
):
    """Convenience queue of properties awaiting admin approval.

    Equivalent to ``/admin/properties?status=pending`` but uses a
    dedicated URL so the admin UI can poll it without building filters.
    """
    stmt = (
        select(Property)
        .where(Property.status == PropertyStatus.pending)
        .order_by(Property.created_at.asc())
    )
    total = (
        await db.execute(select(func.count()).select_from(stmt.subquery()))
    ).scalar() or 0
    pages = math.ceil(total / limit) if total else 0
    rows = (
        await db.execute(stmt.offset((page - 1) * limit).limit(limit))
    ).scalars().all()
    return PaginatedResponse(
        items=[PropertyOut.model_validate(r) for r in rows],
        total=total, page=page, limit=limit, pages=pages,
    )


@router.put("/properties/{property_id}/approve", response_model=PropertyOut)
async def approve_property(
    property_id: int,
    request: Request,
    me: User = Depends(_admin_only),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(Property).where(Property.id == property_id))
    prop = result.scalar_one_or_none()
    if prop is None:
        raise HTTPException(status_code=404, detail="العقار غير موجود / Property not found")
    before = {"status": prop.status.value, "is_available": prop.is_available}
    prop.status = PropertyStatus.approved
    prop.is_available = True
    prop.admin_note = None
    await db.flush()
    await db.refresh(prop)
    await log_action(
        db, request=request, actor=me,
        action="property.approve",
        target_type="property", target_id=property_id,
        before=before,
        after={"status": "approved", "is_available": True},
    )
    logger.info("admin_approved_property", property_id=property_id)
    return PropertyOut.model_validate(prop)


@router.put("/properties/{property_id}/reject", response_model=PropertyOut)
async def reject_property(
    property_id: int,
    request: Request,
    body: _AdminNote | None = None,
    me: User = Depends(_admin_only),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(Property).where(Property.id == property_id))
    prop = result.scalar_one_or_none()
    if prop is None:
        raise HTTPException(status_code=404, detail="العقار غير موجود / Property not found")
    before = {"status": prop.status.value}
    prop.status = PropertyStatus.rejected
    prop.is_available = False
    prop.admin_note = body.note if body else None
    await db.flush()
    await db.refresh(prop)
    await log_action(
        db, request=request, actor=me,
        action="property.reject",
        target_type="property", target_id=property_id,
        before=before,
        after={"status": "rejected", "note": prop.admin_note},
    )
    logger.info("admin_rejected_property", property_id=property_id)
    return PropertyOut.model_validate(prop)


@router.put("/properties/{property_id}/needs-edit", response_model=PropertyOut)
async def needs_edit_property(
    property_id: int,
    body: _AdminNote | None = None,
    _: User = Depends(_admin_only),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(Property).where(Property.id == property_id))
    prop = result.scalar_one_or_none()
    if prop is None:
        raise HTTPException(status_code=404, detail="العقار غير موجود / Property not found")
    prop.status = PropertyStatus.needs_edit
    prop.is_available = False
    prop.admin_note = body.note if body else None
    await db.flush()
    await db.refresh(prop)
    logger.info("admin_needs_edit_property", property_id=property_id)
    return PropertyOut.model_validate(prop)


class _AdminFeaturedFlag(BaseModel):
    is_featured: bool = True


@router.patch(
    "/properties/{property_id}/featured",
    response_model=PropertyOut,
)
async def set_property_featured(
    property_id: int,
    body: _AdminFeaturedFlag,
    request: Request,
    me: User = Depends(_admin_only),
    db: AsyncSession = Depends(get_db),
):
    """Toggle the ``is_featured`` flag on a property.

    Featured properties bubble up on the home page's "أبرز العقارات"
    rail and are highlighted with a star badge throughout the app.
    The action is audit-logged so we can track which admin curated
    the homepage at any point in time.
    """
    prop = await db.get(Property, property_id)
    if prop is None:
        raise HTTPException(
            status_code=404,
            detail="العقار غير موجود / Property not found",
        )
    before = {"is_featured": prop.is_featured}
    prop.is_featured = body.is_featured
    await db.flush()
    await db.refresh(prop)
    await log_action(
        db, request=request, actor=me,
        action="property.feature" if body.is_featured else "property.unfeature",
        target_type="property", target_id=property_id,
        before=before, after={"is_featured": prop.is_featured},
    )
    logger.info(
        "admin_property_featured_flag",
        property_id=property_id, featured=body.is_featured,
    )
    return PropertyOut.model_validate(prop)


@router.delete("/properties/{property_id}", response_model=MessageResponse)
async def delete_property(
    property_id: int,
    request: Request,
    me: User = Depends(_admin_only),
    db: AsyncSession = Depends(get_db),
):
    """Hard-delete a property. Cascades to bookings / reviews via FK."""
    result = await db.execute(select(Property).where(Property.id == property_id))
    prop = result.scalar_one_or_none()
    if prop is None:
        raise HTTPException(status_code=404, detail="العقار غير موجود / Property not found")
    snapshot = {
        "name": prop.name, "owner_id": prop.owner_id,
        "status": prop.status.value if prop.status else None,
    }
    await db.delete(prop)
    await db.flush()
    await log_action(
        db, request=request, actor=me,
        action="property.delete",
        target_type="property", target_id=property_id,
        before=snapshot,
    )
    logger.info("admin_deleted_property", property_id=property_id)
    return MessageResponse(message="Property deleted", message_ar="تم حذف العقار")


# ── Bookings ──────────────────────────────────────────────
@router.get("/bookings", response_model=PaginatedResponse[BookingOut])
async def list_all_bookings(
    page: int = Query(1, ge=1),
    limit: int = Query(20, ge=1, le=100),
    status_filter: BookingStatus | None = Query(None, alias="status"),
    payment_status: PaymentStatus | None = None,
    _: User = Depends(_admin_only),
    db: AsyncSession = Depends(get_db),
):
    stmt = select(Booking)
    if status_filter:
        stmt = stmt.where(Booking.status == status_filter)
    if payment_status:
        stmt = stmt.where(Booking.payment_status == payment_status)
    stmt = stmt.order_by(Booking.created_at.desc())

    total = (
        await db.execute(select(func.count()).select_from(stmt.subquery()))
    ).scalar() or 0
    pages = math.ceil(total / limit) if total else 0

    rows = (
        await db.execute(stmt.offset((page - 1) * limit).limit(limit))
    ).scalars().all()

    return PaginatedResponse(
        items=[BookingOut.model_validate(r) for r in rows],
        total=total, page=page, limit=limit, pages=pages,
    )


# ── Refunds queue ─────────────────────────────────────────
class _AdminRefundRow(BaseModel):
    """Single row in the admin refund queue.

    A "refund row" is any paid booking that has either been
    cancelled or has a non-zero ``refund_amount`` recorded — i.e.
    any case where the platform owes the guest money back.
    """

    booking_id: int
    booking_status: str
    payment_status: str
    total_price: float
    refund_amount: float | None = None
    cancelled_at: datetime | None = None
    check_in: date | None = None
    check_out: date | None = None
    guest_id: int
    guest_name: str | None = None
    guest_phone: str | None = None
    property_id: int
    property_name: str | None = None
    property_image: str | None = None
    payment_provider: str | None = None
    payment_provider_ref: str | None = None
    payment_state: str | None = None


class _AdminMarkRefundedBody(BaseModel):
    """Body for ``POST /admin/refunds/{booking_id}/mark-processed``.

    The admin uses this when the gateway refund was processed
    out-of-band (e.g. Paymob admin dashboard, bank chargeback) and
    we just need to flip the row state inside our own DB.
    """

    partial: bool = False
    note: str | None = None


@router.get(
    "/refunds",
    response_model=PaginatedResponse[_AdminRefundRow],
)
async def list_refunds(
    page: int = Query(1, ge=1),
    limit: int = Query(20, ge=1, le=100),
    state: str = Query(
        "pending",
        description=(
            "``pending`` = paid + cancelled bookings whose refund hasn't "
            "been marked refunded yet.  ``processed`` = already "
            "refunded.  ``all`` = both."
        ),
    ),
    _: User = Depends(_admin_only),
    db: AsyncSession = Depends(get_db),
):
    """Paginated refund queue for the finance team."""
    stmt = select(Booking, Property, User).join(
        Property, Property.id == Booking.property_id
    ).join(User, User.id == Booking.guest_id)

    if state == "pending":
        stmt = stmt.where(
            Booking.status == BookingStatus.cancelled,
            Booking.payment_status == PaymentStatus.paid,
        )
    elif state == "processed":
        stmt = stmt.where(
            Booking.payment_status.in_(
                [PaymentStatus.refunded, PaymentStatus.partially_refunded]
            ),
        )
    else:  # all
        stmt = stmt.where(
            Booking.payment_status.in_(
                [
                    PaymentStatus.paid,
                    PaymentStatus.refunded,
                    PaymentStatus.partially_refunded,
                ]
            ),
            (
                (Booking.status == BookingStatus.cancelled)
                | (Booking.refund_amount.isnot(None))
            ),
        )

    count_stmt = select(func.count()).select_from(Booking)
    if state == "pending":
        count_stmt = count_stmt.where(
            Booking.status == BookingStatus.cancelled,
            Booking.payment_status == PaymentStatus.paid,
        )
    elif state == "processed":
        count_stmt = count_stmt.where(
            Booking.payment_status.in_(
                [PaymentStatus.refunded, PaymentStatus.partially_refunded]
            ),
        )
    else:
        count_stmt = count_stmt.where(
            Booking.payment_status.in_(
                [
                    PaymentStatus.paid,
                    PaymentStatus.refunded,
                    PaymentStatus.partially_refunded,
                ]
            ),
            (
                (Booking.status == BookingStatus.cancelled)
                | (Booking.refund_amount.isnot(None))
            ),
        )
    total = (await db.execute(count_stmt)).scalar() or 0

    stmt = stmt.order_by(Booking.cancelled_at.desc().nullslast(),
                         Booking.created_at.desc()).offset(
        (page - 1) * limit
    ).limit(limit)
    rows = (await db.execute(stmt)).all()

    items: list[_AdminRefundRow] = []
    for booking, prop, guest in rows:
        # Latest paid/refunded payment, if any — surface the gateway
        # provider + reference so the admin can match it against the
        # gateway dashboard.
        payment_q = await db.execute(
            select(Payment)
            .where(Payment.booking_id == booking.id)
            .order_by(Payment.id.desc())
            .limit(1)
        )
        payment = payment_q.scalar_one_or_none()
        first_image = (prop.images or [None])[0] if prop.images else None
        items.append(
            _AdminRefundRow(
                booking_id=booking.id,
                booking_status=booking.status.value,
                payment_status=booking.payment_status.value,
                total_price=booking.total_price,
                refund_amount=booking.refund_amount,
                cancelled_at=booking.cancelled_at,
                check_in=booking.check_in,
                check_out=booking.check_out,
                guest_id=guest.id,
                guest_name=guest.name,
                guest_phone=guest.phone,
                property_id=prop.id,
                property_name=prop.name,
                property_image=first_image,
                payment_provider=payment.provider.value if payment else None,
                payment_provider_ref=payment.provider_ref if payment else None,
                payment_state=payment.state.value if payment else None,
            )
        )

    return PaginatedResponse[_AdminRefundRow](
        items=items,
        total=total,
        page=page,
        limit=limit,
        pages=math.ceil(total / limit) if total else 0,
    )


@router.post(
    "/refunds/{booking_id}/mark-processed",
    response_model=_AdminRefundRow,
)
async def mark_refund_processed(
    booking_id: int,
    body: _AdminMarkRefundedBody,
    request: Request,
    me: User = Depends(_admin_only),
    db: AsyncSession = Depends(get_db),
):
    """Flip a booking to ``refunded`` after a manual gateway refund.

    Use cases:
      - The gateway processed the refund through its own admin UI and
        our auto-refund failed (e.g. because the original Paymob
        order_id was lost).
      - The bank issued a chargeback so the money is already back with
        the guest and we just need to reconcile our own state.

    The endpoint flips both the booking's ``payment_status`` and the
    latest payment row's ``state`` so reports and analytics stay
    consistent.  Audit-logged.
    """
    booking = await db.get(Booking, booking_id)
    if booking is None:
        raise HTTPException(
            status_code=404,
            detail="الحجز غير موجود / Booking not found",
        )
    if booking.payment_status not in (
        PaymentStatus.paid,
        PaymentStatus.partially_refunded,
    ):
        raise HTTPException(
            status_code=400,
            detail="الحجز ليس قابلاً للاسترداد / Booking is not refundable",
        )

    before = {
        "payment_status": booking.payment_status.value,
    }
    new_status = (
        PaymentStatus.partially_refunded if body.partial else PaymentStatus.refunded
    )
    booking.payment_status = new_status

    # Mirror the latest payment row.
    payment = (
        await db.execute(
            select(Payment)
            .where(Payment.booking_id == booking.id)
            .order_by(Payment.id.desc())
            .limit(1)
        )
    ).scalar_one_or_none()
    if payment is not None:
        payment.state = (
            PaymentState.partially_refunded if body.partial else PaymentState.refunded
        )

    await db.flush()
    await log_action(
        db, request=request, actor=me,
        action="refund.mark_processed",
        target_type="booking", target_id=booking_id,
        before=before,
        after={
            "payment_status": booking.payment_status.value,
            "note": body.note,
            "partial": body.partial,
        },
    )
    logger.info(
        "admin_refund_marked",
        booking_id=booking_id, partial=body.partial,
    )

    # Re-load joined row so the response is identical-shaped to GET
    # /admin/refunds entries.
    prop = await db.get(Property, booking.property_id)
    guest = await db.get(User, booking.guest_id)
    first_image = (
        (prop.images if prop else None) or [None]
    )[0]
    return _AdminRefundRow(
        booking_id=booking.id,
        booking_status=booking.status.value,
        payment_status=booking.payment_status.value,
        total_price=booking.total_price,
        refund_amount=booking.refund_amount,
        cancelled_at=booking.cancelled_at,
        check_in=booking.check_in,
        check_out=booking.check_out,
        guest_id=guest.id if guest else booking.guest_id,
        guest_name=guest.name if guest else None,
        guest_phone=guest.phone if guest else None,
        property_id=booking.property_id,
        property_name=prop.name if prop else None,
        property_image=first_image,
        payment_provider=payment.provider.value if payment else None,
        payment_provider_ref=payment.provider_ref if payment else None,
        payment_state=payment.state.value if payment else None,
    )


# ── Reviews moderation ────────────────────────────────────
class _AdminReviewOut(BaseModel):
    """Enriched review row for the admin moderation page.

    We surface everything a moderator needs in one row to make a
    decision without having to drill into the property page:
    reviewer name + avatar, property name + cover image, the rating
    itself, the body of the review, the moderation flags (hidden,
    report_count), and the host's public reply if any.
    """

    id: int
    booking_id: int
    property_id: int
    property_name: str | None = None
    property_image: str | None = None
    reviewer_id: int
    reviewer_name: str | None = None
    reviewer_avatar: str | None = None
    rating: float
    comment: str | None = None
    owner_response: str | None = None
    owner_response_at: datetime | None = None
    is_hidden: bool = False
    report_count: int = 0
    created_at: datetime


class _AdminReviewHideBody(BaseModel):
    is_hidden: bool = True


@router.get("/reviews", response_model=PaginatedResponse[_AdminReviewOut])
async def list_all_reviews(
    page: int = Query(1, ge=1),
    limit: int = Query(20, ge=1, le=100),
    hidden: bool | None = Query(
        None,
        description=(
            "Filter by hidden flag.  ``true`` = only soft-hidden reviews, "
            "``false`` = only visible reviews, ``null`` = no filter."
        ),
    ),
    flagged_only: bool = Query(
        False,
        description="If true return only reviews with report_count > 0.",
    ),
    min_rating: float | None = Query(None, ge=1, le=5),
    max_rating: float | None = Query(None, ge=1, le=5),
    property_id: int | None = Query(None, ge=1),
    search: str | None = Query(
        None,
        description="Substring match against the review comment (case-insensitive).",
    ),
    _: User = Depends(_admin_only),
    db: AsyncSession = Depends(get_db),
):
    """Paginated review list for the admin moderation panel.

    Joins Property + User so the response has everything needed to
    render a row without a follow-up request.  Ordered ``newest``
    first so brand-new abuse surfaces immediately at the top.
    """
    stmt = select(Review, Property, User).join(
        Property, Property.id == Review.property_id
    ).join(User, User.id == Review.reviewer_id)

    if hidden is True:
        stmt = stmt.where(Review.is_hidden.is_(True))
    elif hidden is False:
        stmt = stmt.where(Review.is_hidden.is_(False))
    if flagged_only:
        stmt = stmt.where(Review.report_count > 0)
    if min_rating is not None:
        stmt = stmt.where(Review.rating >= min_rating)
    if max_rating is not None:
        stmt = stmt.where(Review.rating <= max_rating)
    if property_id is not None:
        stmt = stmt.where(Review.property_id == property_id)
    if search:
        like = f"%{search}%"
        stmt = stmt.where(Review.comment.ilike(like))

    # Total count for pagination — has to use the same WHERE filters
    # but a much cheaper SELECT count(*) shape.
    count_stmt = select(func.count()).select_from(Review)
    if hidden is True:
        count_stmt = count_stmt.where(Review.is_hidden.is_(True))
    elif hidden is False:
        count_stmt = count_stmt.where(Review.is_hidden.is_(False))
    if flagged_only:
        count_stmt = count_stmt.where(Review.report_count > 0)
    if min_rating is not None:
        count_stmt = count_stmt.where(Review.rating >= min_rating)
    if max_rating is not None:
        count_stmt = count_stmt.where(Review.rating <= max_rating)
    if property_id is not None:
        count_stmt = count_stmt.where(Review.property_id == property_id)
    if search:
        count_stmt = count_stmt.where(Review.comment.ilike(f"%{search}%"))
    total = (await db.execute(count_stmt)).scalar() or 0

    stmt = stmt.order_by(
        # Flagged-but-not-hidden reviews float to the top so the
        # moderator drains them fastest, then newest first.
        (Review.report_count > 0).desc(),
        Review.created_at.desc(),
    ).offset((page - 1) * limit).limit(limit)

    rows = (await db.execute(stmt)).all()

    items: list[_AdminReviewOut] = []
    for review, prop, user in rows:
        first_image = (prop.images or [None])[0] if prop.images else None
        items.append(
            _AdminReviewOut(
                id=review.id,
                booking_id=review.booking_id,
                property_id=review.property_id,
                property_name=prop.name,
                property_image=first_image,
                reviewer_id=review.reviewer_id,
                reviewer_name=user.name,
                reviewer_avatar=user.avatar_url,
                rating=review.rating,
                comment=review.comment,
                owner_response=review.owner_response,
                owner_response_at=review.owner_response_at,
                is_hidden=review.is_hidden,
                report_count=review.report_count,
                created_at=review.created_at,
            )
        )

    return PaginatedResponse[_AdminReviewOut](
        items=items,
        total=total,
        page=page,
        limit=limit,
        pages=math.ceil(total / limit) if total else 0,
    )


@router.patch("/reviews/{review_id}/hide", response_model=_AdminReviewOut)
async def set_review_hidden(
    review_id: int,
    body: _AdminReviewHideBody,
    request: Request,
    me: User = Depends(_admin_only),
    db: AsyncSession = Depends(get_db),
):
    """Toggle a review's ``is_hidden`` flag.

    Soft-hide is preferred over delete for borderline content because
    it keeps the booking ↔ review link intact (so a guest can never
    "review-bomb" the same booking twice) while still removing the
    text from public listings.  When unhidden the review reappears
    everywhere instantly.
    """
    result = await db.execute(
        select(Review, Property, User)
        .join(Property, Property.id == Review.property_id)
        .join(User, User.id == Review.reviewer_id)
        .where(Review.id == review_id)
    )
    row = result.first()
    if row is None:
        raise HTTPException(
            status_code=404,
            detail="التقييم غير موجود / Review not found",
        )
    review, prop, user = row
    before = {"is_hidden": review.is_hidden}
    review.is_hidden = body.is_hidden
    await db.flush()
    await log_action(
        db, request=request, actor=me,
        action="review.hide" if body.is_hidden else "review.unhide",
        target_type="review", target_id=review_id,
        before=before, after={"is_hidden": review.is_hidden},
    )
    logger.info(
        "admin_review_hidden_flag",
        review_id=review_id, hidden=body.is_hidden,
    )
    first_image = (prop.images or [None])[0] if prop.images else None
    return _AdminReviewOut(
        id=review.id,
        booking_id=review.booking_id,
        property_id=review.property_id,
        property_name=prop.name,
        property_image=first_image,
        reviewer_id=review.reviewer_id,
        reviewer_name=user.name,
        reviewer_avatar=user.avatar_url,
        rating=review.rating,
        comment=review.comment,
        owner_response=review.owner_response,
        owner_response_at=review.owner_response_at,
        is_hidden=review.is_hidden,
        report_count=review.report_count,
        created_at=review.created_at,
    )


@router.delete("/reviews/{review_id}", response_model=MessageResponse)
async def delete_review(
    review_id: int,
    request: Request,
    me: User = Depends(_admin_only),
    db: AsyncSession = Depends(get_db),
):
    """Remove an inappropriate review and recompute the property rating."""
    result = await db.execute(select(Review).where(Review.id == review_id))
    review = result.scalar_one_or_none()
    if review is None:
        raise HTTPException(status_code=404, detail="التقييم غير موجود / Review not found")
    prop_id = review.property_id
    snapshot = {
        "rating": review.rating, "comment": review.comment,
        "reviewer_id": review.reviewer_id,
    }
    await db.delete(review)
    await db.flush()
    await log_action(
        db, request=request, actor=me,
        action="review.delete",
        target_type="review", target_id=review_id,
        before=snapshot,
    )

    # Recompute average rating for the property
    avg_q = await db.execute(
        select(func.avg(Review.rating)).where(Review.property_id == prop_id)
    )
    count_q = await db.execute(
        select(func.count(Review.id)).where(Review.property_id == prop_id)
    )
    prop_q = await db.execute(select(Property).where(Property.id == prop_id))
    prop = prop_q.scalar_one_or_none()
    if prop is not None:
        prop.rating = round(float(avg_q.scalar() or 0.0), 2)
        prop.review_count = count_q.scalar() or 0
        await db.flush()

    logger.info("admin_deleted_review", review_id=review_id)
    return MessageResponse(message="Review deleted", message_ar="تم حذف التقييم")


# ── Fraud detection (suspicious accounts) ────────────────
class _FraudFlagRow(BaseModel):
    user_id: int
    user_name: str | None = None
    user_phone: str | None = None
    user_email: str | None = None
    is_active: bool
    is_verified: bool
    cancelled_bookings: int
    refunded_bookings: int
    pending_reports_against: int
    rejected_kycs: int
    risk_score: int  # 0-100, higher = riskier
    risk_label: str  # low | medium | high
    created_at: datetime


@router.get("/fraud-detection", response_model=list[_FraudFlagRow])
async def list_suspicious_users(
    threshold: int = Query(
        30, ge=0, le=100,
        description="Only return users whose ``risk_score`` >= threshold.",
    ),
    limit: int = Query(50, ge=1, le=200),
    _: User = Depends(_admin_only),
    db: AsyncSession = Depends(get_db),
):
    """Surface accounts with abnormal booking / report / refund patterns.

    The risk score is a simple weighted sum of independently
    measurable signals — no ML, no opaque ranking.  Admins can read
    each contributor in the row and decide whether to deactivate.

    Signals (weights):
      - ``cancelled_bookings``      ×  6
      - ``refunded_bookings``       × 10
      - ``pending_reports_against`` × 12
      - ``rejected_kycs``           × 15
      - cap at 100 so the badge stays sane.

    The cap was tuned by hand against historical data; the goal is
    not "perfect detection" but "useful triage queue".
    """
    # Pull every user with at least one suspicious signal.  We
    # subquery the per-user counts independently because joining
    # multiple aggregated tables causes Cartesian explosion in
    # PostgreSQL.
    cancelled_q = (
        select(
            Booking.guest_id.label("uid"),
            func.count(Booking.id).label("cnt"),
        )
        .where(Booking.status == BookingStatus.cancelled)
        .group_by(Booking.guest_id)
        .subquery()
    )
    refunded_q = (
        select(
            Booking.guest_id.label("uid"),
            func.count(Booking.id).label("cnt"),
        )
        .where(
            Booking.payment_status.in_(
                [PaymentStatus.refunded, PaymentStatus.partially_refunded]
            )
        )
        .group_by(Booking.guest_id)
        .subquery()
    )
    # Pending reports filed *against* this user.  ``Report.target_id``
    # carries the user id when ``target_type='user'``.
    from app.models.report import Report, ReportStatus, ReportTarget
    reports_q = (
        select(
            Report.target_id.label("uid"),
            func.count(Report.id).label("cnt"),
        )
        .where(
            Report.target_type == ReportTarget.user,
            Report.status == ReportStatus.pending,
        )
        .group_by(Report.target_id)
        .subquery()
    )
    from app.models.user_verification import (
        UserVerification, UserVerificationStatus,
    )
    rejected_kycs_q = (
        select(
            UserVerification.user_id.label("uid"),
            func.count(UserVerification.id).label("cnt"),
        )
        .where(UserVerification.status == UserVerificationStatus.rejected)
        .group_by(UserVerification.user_id)
        .subquery()
    )

    rows = (await db.execute(
        select(
            User,
            func.coalesce(cancelled_q.c.cnt, 0).label("cancelled"),
            func.coalesce(refunded_q.c.cnt, 0).label("refunded"),
            func.coalesce(reports_q.c.cnt, 0).label("reports"),
            func.coalesce(rejected_kycs_q.c.cnt, 0).label("rkyc"),
        )
        .outerjoin(cancelled_q, cancelled_q.c.uid == User.id)
        .outerjoin(refunded_q, refunded_q.c.uid == User.id)
        .outerjoin(reports_q, reports_q.c.uid == User.id)
        .outerjoin(rejected_kycs_q, rejected_kycs_q.c.uid == User.id)
    )).all()

    out: list[_FraudFlagRow] = []
    for r in rows:
        u: User = r[0]
        cancelled = int(r.cancelled or 0)
        refunded = int(r.refunded or 0)
        reports = int(r.reports or 0)
        rkyc = int(r.rkyc or 0)
        score = min(
            100,
            cancelled * 6 + refunded * 10 + reports * 12 + rkyc * 15,
        )
        if score < threshold:
            continue
        label = "high" if score >= 70 else "medium" if score >= 40 else "low"
        out.append(
            _FraudFlagRow(
                user_id=u.id,
                user_name=u.name,
                user_phone=u.phone,
                user_email=u.email,
                is_active=u.is_active,
                is_verified=u.is_verified,
                cancelled_bookings=cancelled,
                refunded_bookings=refunded,
                pending_reports_against=reports,
                rejected_kycs=rkyc,
                risk_score=score,
                risk_label=label,
                created_at=u.created_at,
            )
        )

    out.sort(key=lambda r: r.risk_score, reverse=True)
    return out[:limit]


# ── Platform settings (pricing-rules page) ───────────────
class _PlatformSettingsOut(BaseModel):
    platform_fee_percent: float
    deposit_percent_default: float
    payout_hold_days: int
    wallet_min_redeem_subtotal: float
    referral_reward_egp: float
    referral_reward_cap: int
    last_change_note: str | None = None
    updated_at: datetime | None = None
    updated_by_name: str | None = None

    model_config = {"from_attributes": True}


class _PlatformSettingsUpdate(BaseModel):
    platform_fee_percent: float | None = None
    deposit_percent_default: float | None = None
    payout_hold_days: int | None = None
    wallet_min_redeem_subtotal: float | None = None
    referral_reward_egp: float | None = None
    referral_reward_cap: int | None = None
    note: str | None = None


async def _get_or_create_settings(db: AsyncSession) -> PlatformSetting:
    """Return the singleton settings row, creating it lazily.

    The migration seeds the row on upgrade, but in environments
    bootstrapped without running migrations (rare — mainly old test
    DBs) we still want the page to "just work", so we self-heal here.
    """
    row = await db.get(PlatformSetting, 1)
    if row is None:
        row = PlatformSetting(id=1)
        db.add(row)
        await db.flush()
        await db.refresh(row)
    return row


@router.get("/settings", response_model=_PlatformSettingsOut)
async def get_platform_settings(
    _: User = Depends(_admin_only),
    db: AsyncSession = Depends(get_db),
):
    """Return the current platform-wide settings (singleton row)."""
    row = await _get_or_create_settings(db)
    return _PlatformSettingsOut.model_validate(row)


@router.patch("/settings", response_model=_PlatformSettingsOut)
async def update_platform_settings(
    body: _PlatformSettingsUpdate,
    request: Request,
    me: User = Depends(_admin_only),
    db: AsyncSession = Depends(get_db),
):
    """Patch the settings row.

    Only fields explicitly provided in the body are updated.  Each
    individual change is sanity-checked (e.g. percentages capped at
    0-100) and the entire mutation is audit-logged so the finance
    team has forensic visibility on commission changes.
    """
    row = await _get_or_create_settings(db)
    before = {
        "platform_fee_percent": row.platform_fee_percent,
        "deposit_percent_default": row.deposit_percent_default,
        "payout_hold_days": row.payout_hold_days,
        "wallet_min_redeem_subtotal": row.wallet_min_redeem_subtotal,
        "referral_reward_egp": row.referral_reward_egp,
        "referral_reward_cap": row.referral_reward_cap,
    }

    if body.platform_fee_percent is not None:
        if not 0 <= body.platform_fee_percent <= 100:
            raise HTTPException(
                status_code=400,
                detail="نسبة العمولة يجب أن تكون بين 0 و 100 / "
                       "Fee must be 0-100",
            )
        row.platform_fee_percent = body.platform_fee_percent
    if body.deposit_percent_default is not None:
        if not 0 <= body.deposit_percent_default <= 100:
            raise HTTPException(
                status_code=400,
                detail="نسبة العربون يجب أن تكون بين 0 و 100 / "
                       "Deposit must be 0-100",
            )
        row.deposit_percent_default = body.deposit_percent_default
    if body.payout_hold_days is not None:
        if not 0 <= body.payout_hold_days <= 60:
            raise HTTPException(
                status_code=400,
                detail="مدة الاحتجاز يجب أن تكون بين 0 و 60 يوم",
            )
        row.payout_hold_days = body.payout_hold_days
    if body.wallet_min_redeem_subtotal is not None:
        if body.wallet_min_redeem_subtotal < 0:
            raise HTTPException(status_code=400, detail="القيمة سالبة")
        row.wallet_min_redeem_subtotal = body.wallet_min_redeem_subtotal
    if body.referral_reward_egp is not None:
        if body.referral_reward_egp < 0:
            raise HTTPException(status_code=400, detail="القيمة سالبة")
        row.referral_reward_egp = body.referral_reward_egp
    if body.referral_reward_cap is not None:
        if not 0 <= body.referral_reward_cap <= 100:
            raise HTTPException(status_code=400, detail="القيمة خارج المدى")
        row.referral_reward_cap = body.referral_reward_cap
    if body.note is not None:
        row.last_change_note = body.note.strip()[:2000] or None
    row.updated_by_name = me.name

    await db.flush()
    await db.refresh(row)
    after = {
        "platform_fee_percent": row.platform_fee_percent,
        "deposit_percent_default": row.deposit_percent_default,
        "payout_hold_days": row.payout_hold_days,
        "wallet_min_redeem_subtotal": row.wallet_min_redeem_subtotal,
        "referral_reward_egp": row.referral_reward_egp,
        "referral_reward_cap": row.referral_reward_cap,
    }
    await log_action(
        db, request=request, actor=me,
        action="settings.update",
        target_type="platform_setting", target_id=1,
        before=before, after=after,
    )
    logger.info("admin_settings_updated", actor_id=me.id)
    return _PlatformSettingsOut.model_validate(row)


# ── Advanced analytics dashboard ─────────────────────────
class _MonthlyPoint(BaseModel):
    month: str  # ISO ``YYYY-MM`` string for stable sort
    revenue: float
    bookings: int


class _TopAreaRow(BaseModel):
    area: str
    bookings: int
    revenue: float


class _TopPropertyRow(BaseModel):
    property_id: int
    property_name: str
    bookings: int
    revenue: float


class _AdvancedStatsOut(BaseModel):
    total_revenue: float
    total_platform_fees: float
    total_bookings: int
    paid_bookings: int
    cancelled_bookings: int
    new_users_30d: int
    new_properties_30d: int
    monthly: list[_MonthlyPoint]  # 6-month trend
    top_areas: list[_TopAreaRow]
    top_properties: list[_TopPropertyRow]


@router.get("/analytics/advanced", response_model=_AdvancedStatsOut)
async def advanced_analytics(
    months: int = Query(
        6, ge=1, le=24,
        description="How many months of monthly trend to return.",
    ),
    _: User = Depends(_admin_only),
    db: AsyncSession = Depends(get_db),
):
    """One-shot advanced analytics for the admin dashboard.

    Returns the raw aggregates the dashboard needs to render its
    trend chart, top-areas leaderboard, and headline KPIs without
    making the client orchestrate 5+ round trips.

    Implementation note: we intentionally do *not* cache this
    response.  The admin dashboard is hit by humans (low QPS) and
    they expect "fresh" numbers — caching would make the page lie
    after a refund or new booking.
    """
    from datetime import timedelta

    now = datetime.now()
    cutoff_30d = now - timedelta(days=30)

    # ── Headline KPIs ─────────────────────────────────────
    total_revenue = (await db.execute(
        select(func.coalesce(func.sum(Booking.total_price), 0)).where(
            Booking.payment_status == PaymentStatus.paid,
        )
    )).scalar() or 0
    total_platform_fees = (await db.execute(
        select(func.coalesce(func.sum(Booking.platform_fee), 0)).where(
            Booking.payment_status == PaymentStatus.paid,
        )
    )).scalar() or 0
    total_bookings = (
        await db.execute(select(func.count(Booking.id)))
    ).scalar() or 0
    paid_bookings = (
        await db.execute(
            select(func.count(Booking.id)).where(
                Booking.payment_status == PaymentStatus.paid,
            )
        )
    ).scalar() or 0
    cancelled_bookings = (
        await db.execute(
            select(func.count(Booking.id)).where(
                Booking.status == BookingStatus.cancelled,
            )
        )
    ).scalar() or 0
    new_users_30d = (
        await db.execute(
            select(func.count(User.id)).where(User.created_at >= cutoff_30d)
        )
    ).scalar() or 0
    new_properties_30d = (
        await db.execute(
            select(func.count(Property.id)).where(
                Property.created_at >= cutoff_30d,
            )
        )
    ).scalar() or 0

    # ── Monthly trend ─────────────────────────────────────
    # We use ``date_trunc`` (Postgres) to bucket bookings by month.
    # ``func.to_char`` keeps the bucket name as ``YYYY-MM`` so the
    # client can sort lexicographically without timezone drift.
    bucket = func.to_char(
        func.date_trunc("month", Booking.created_at), "YYYY-MM"
    ).label("month")
    monthly_q = await db.execute(
        select(
            bucket,
            func.coalesce(
                func.sum(Booking.total_price).filter(
                    Booking.payment_status == PaymentStatus.paid
                ),
                0,
            ).label("revenue"),
            func.count(Booking.id).label("bookings"),
        )
        .where(Booking.created_at >= now - timedelta(days=months * 31))
        .group_by(bucket)
        .order_by(bucket.asc())
    )
    monthly = [
        _MonthlyPoint(
            month=r.month,
            revenue=float(r.revenue or 0),
            bookings=int(r.bookings or 0),
        )
        for r in monthly_q
    ]

    # ── Top areas (5) ─────────────────────────────────────
    top_areas_q = await db.execute(
        select(
            Property.area,
            func.count(Booking.id).label("bookings"),
            func.coalesce(
                func.sum(Booking.total_price).filter(
                    Booking.payment_status == PaymentStatus.paid
                ),
                0,
            ).label("revenue"),
        )
        .join(Property, Property.id == Booking.property_id)
        .group_by(Property.area)
        .order_by(func.count(Booking.id).desc())
        .limit(5)
    )
    top_areas = [
        _TopAreaRow(
            area=str(r.area),
            bookings=int(r.bookings or 0),
            revenue=float(r.revenue or 0),
        )
        for r in top_areas_q
    ]

    # ── Top properties (10 by revenue) ────────────────────
    top_props_q = await db.execute(
        select(
            Property.id, Property.name,
            func.count(Booking.id).label("bookings"),
            func.coalesce(
                func.sum(Booking.total_price).filter(
                    Booking.payment_status == PaymentStatus.paid
                ),
                0,
            ).label("revenue"),
        )
        .join(Booking, Booking.property_id == Property.id)
        .group_by(Property.id, Property.name)
        .order_by(
            func.coalesce(
                func.sum(Booking.total_price).filter(
                    Booking.payment_status == PaymentStatus.paid
                ),
                0,
            ).desc()
        )
        .limit(10)
    )
    top_properties = [
        _TopPropertyRow(
            property_id=int(r.id),
            property_name=str(r.name),
            bookings=int(r.bookings or 0),
            revenue=float(r.revenue or 0),
        )
        for r in top_props_q
    ]

    return _AdvancedStatsOut(
        total_revenue=float(total_revenue),
        total_platform_fees=float(total_platform_fees),
        total_bookings=int(total_bookings),
        paid_bookings=int(paid_bookings),
        cancelled_bookings=int(cancelled_bookings),
        new_users_30d=int(new_users_30d),
        new_properties_30d=int(new_properties_30d),
        monthly=monthly,
        top_areas=top_areas,
        top_properties=top_properties,
    )


# ── Stats dashboard ───────────────────────────────────────
@router.get("/stats")
async def dashboard_stats(
    _: User = Depends(_admin_only),
    db: AsyncSession = Depends(get_db),
):
    """Return aggregated platform statistics."""
    total_users = (await db.execute(select(func.count(User.id)))).scalar() or 0
    active_users = (
        await db.execute(select(func.count(User.id)).where(User.is_active.is_(True)))
    ).scalar() or 0
    total_owners = (
        await db.execute(select(func.count(User.id)).where(User.role == UserRole.owner))
    ).scalar() or 0
    total_admins = (
        await db.execute(select(func.count(User.id)).where(User.role == UserRole.admin))
    ).scalar() or 0

    total_properties = (await db.execute(select(func.count(Property.id)))).scalar() or 0
    pending_properties = (
        await db.execute(
            select(func.count(Property.id)).where(
                Property.status == PropertyStatus.pending
            )
        )
    ).scalar() or 0
    approved_properties = (
        await db.execute(
            select(func.count(Property.id)).where(
                Property.status == PropertyStatus.approved
            )
        )
    ).scalar() or 0
    rejected_properties = (
        await db.execute(
            select(func.count(Property.id)).where(
                Property.status == PropertyStatus.rejected
            )
        )
    ).scalar() or 0

    total_bookings = (await db.execute(select(func.count(Booking.id)))).scalar() or 0
    pending_bookings = (
        await db.execute(
            select(func.count(Booking.id)).where(
                Booking.status == BookingStatus.pending
            )
        )
    ).scalar() or 0
    cancelled_bookings = (
        await db.execute(
            select(func.count(Booking.id)).where(
                Booking.status == BookingStatus.cancelled
            )
        )
    ).scalar() or 0
    total_reviews = (await db.execute(select(func.count(Review.id)))).scalar() or 0

    confirmed_bookings = (
        await db.execute(
            select(func.count(Booking.id)).where(
                Booking.status.in_([BookingStatus.confirmed, BookingStatus.completed])
            )
        )
    ).scalar() or 0

    total_revenue = (
        await db.execute(
            select(func.coalesce(func.sum(Booking.total_price), 0)).where(
                Booking.payment_status == PaymentStatus.paid
            )
        )
    ).scalar() or 0

    total_platform_fees = (
        await db.execute(
            select(func.coalesce(func.sum(Booking.platform_fee), 0)).where(
                Booking.payment_status == PaymentStatus.paid
            )
        )
    ).scalar() or 0

    total_owner_payouts = (
        await db.execute(
            select(func.coalesce(func.sum(Booking.owner_payout), 0)).where(
                Booking.payment_status == PaymentStatus.paid
            )
        )
    ).scalar() or 0

    return {
        "total_users": total_users,
        "active_users": active_users,
        "total_owners": total_owners,
        "total_admins": total_admins,
        "total_properties": total_properties,
        "pending_properties": pending_properties,
        "approved_properties": approved_properties,
        "rejected_properties": rejected_properties,
        "total_bookings": total_bookings,
        "pending_bookings": pending_bookings,
        "confirmed_bookings": confirmed_bookings,
        "cancelled_bookings": cancelled_bookings,
        "total_reviews": total_reviews,
        "total_revenue": float(total_revenue),
        "total_platform_fees": float(total_platform_fees),
        "total_owner_payouts": float(total_owner_payouts),
        "currency": "EGP",
    }


# ════════════════════════════════════════════════════════════════
#  WAVE 30 — Feature flags / A-B testing
# ════════════════════════════════════════════════════════════════
class _FeatureFlagOut(BaseModel):
    id: int
    key: str
    description: str | None = None
    kind: str
    enabled: bool
    default_value: bool
    rollout_percent: int
    variant_a: str | None = None
    variant_b: str | None = None
    last_change_note: str | None = None
    created_at: datetime
    updated_at: datetime
    assignment_count: int = 0

    model_config = {"from_attributes": True}


class _FeatureFlagCreate(BaseModel):
    key: str
    description: str | None = None
    kind: str = "boolean"
    enabled: bool = False
    default_value: bool = False
    rollout_percent: int = 0
    variant_a: str | None = None
    variant_b: str | None = None


class _FeatureFlagUpdate(BaseModel):
    description: str | None = None
    enabled: bool | None = None
    default_value: bool | None = None
    rollout_percent: int | None = None
    variant_a: str | None = None
    variant_b: str | None = None
    note: str | None = None


def _flag_kind_or_400(value: str) -> FlagKind:
    """Validate the user-supplied ``kind`` string."""
    try:
        return FlagKind(value)
    except ValueError as exc:
        raise HTTPException(
            status_code=400,
            detail="نوع غير معروف / unknown flag kind",
        ) from exc


async def _flag_to_out(
    db: AsyncSession, flag: FeatureFlag,
) -> _FeatureFlagOut:
    """Hydrate a flag with its assignment count for the admin UI."""
    cnt = (
        await db.execute(
            select(func.count(FeatureFlagAssignment.id)).where(
                FeatureFlagAssignment.flag_id == flag.id,
            )
        )
    ).scalar() or 0
    out = _FeatureFlagOut.model_validate(flag)
    out.kind = flag.kind.value
    out.assignment_count = int(cnt)
    return out


@router.get("/feature-flags", response_model=list[_FeatureFlagOut])
async def list_feature_flags(
    _: User = Depends(_admin_only),
    db: AsyncSession = Depends(get_db),
):
    """List every feature flag, newest first."""
    rows = (await db.execute(
        select(FeatureFlag).order_by(FeatureFlag.created_at.desc())
    )).scalars().all()
    return [await _flag_to_out(db, r) for r in rows]


@router.post("/feature-flags", response_model=_FeatureFlagOut, status_code=201)
async def create_feature_flag(
    body: _FeatureFlagCreate,
    request: Request,
    me: User = Depends(_admin_only),
    db: AsyncSession = Depends(get_db),
):
    """Create a new feature flag.

    The key must be unique app-wide; we collide-check up-front to give
    a friendlier error than the raw IntegrityError.
    """
    key = body.key.strip().lower()
    if not key or " " in key:
        raise HTTPException(
            status_code=400,
            detail="مفتاح غير صالح (use lower-snake-case)",
        )
    existing = (await db.execute(
        select(FeatureFlag).where(FeatureFlag.key == key)
    )).scalar_one_or_none()
    if existing is not None:
        raise HTTPException(status_code=409, detail="المفتاح موجود بالفعل")
    if not 0 <= body.rollout_percent <= 100:
        raise HTTPException(
            status_code=400, detail="rollout_percent must be 0-100",
        )

    flag = FeatureFlag(
        key=key,
        description=body.description,
        kind=_flag_kind_or_400(body.kind),
        enabled=body.enabled,
        default_value=body.default_value,
        rollout_percent=body.rollout_percent,
        variant_a=body.variant_a,
        variant_b=body.variant_b,
        updated_by=me.id,
    )
    db.add(flag)
    await db.flush()
    await db.refresh(flag)
    await log_action(
        db, request=request, actor=me,
        action="feature_flag.create",
        target_type="feature_flag", target_id=flag.id,
        before=None, after={"key": key, "kind": body.kind},
    )
    return await _flag_to_out(db, flag)


@router.patch("/feature-flags/{flag_id}", response_model=_FeatureFlagOut)
async def update_feature_flag(
    flag_id: int,
    body: _FeatureFlagUpdate,
    request: Request,
    me: User = Depends(_admin_only),
    db: AsyncSession = Depends(get_db),
):
    """Patch a flag.  Only fields explicitly provided are touched.

    Toggling ``enabled`` is by far the most common mutation, so we
    dedicate a happy path with audit logging.
    """
    flag = await db.get(FeatureFlag, flag_id)
    if flag is None:
        raise HTTPException(status_code=404, detail="Flag not found")
    before = {
        "enabled": flag.enabled,
        "rollout_percent": flag.rollout_percent,
        "default_value": flag.default_value,
    }
    if body.description is not None:
        flag.description = body.description
    if body.enabled is not None:
        flag.enabled = body.enabled
    if body.default_value is not None:
        flag.default_value = body.default_value
    if body.rollout_percent is not None:
        if not 0 <= body.rollout_percent <= 100:
            raise HTTPException(
                status_code=400, detail="rollout_percent must be 0-100",
            )
        flag.rollout_percent = body.rollout_percent
    if body.variant_a is not None:
        flag.variant_a = body.variant_a
    if body.variant_b is not None:
        flag.variant_b = body.variant_b
    if body.note is not None:
        flag.last_change_note = body.note.strip()[:2000] or None
    flag.updated_by = me.id

    await db.flush()
    await db.refresh(flag)
    after = {
        "enabled": flag.enabled,
        "rollout_percent": flag.rollout_percent,
        "default_value": flag.default_value,
    }
    await log_action(
        db, request=request, actor=me,
        action="feature_flag.update",
        target_type="feature_flag", target_id=flag.id,
        before=before, after=after,
    )
    return await _flag_to_out(db, flag)


@router.delete("/feature-flags/{flag_id}", response_model=MessageResponse)
async def delete_feature_flag(
    flag_id: int,
    request: Request,
    me: User = Depends(_admin_only),
    db: AsyncSession = Depends(get_db),
):
    """Hard-delete a flag and all its sticky assignments."""
    flag = await db.get(FeatureFlag, flag_id)
    if flag is None:
        raise HTTPException(status_code=404, detail="Flag not found")
    key = flag.key
    await db.delete(flag)
    await db.flush()
    await log_action(
        db, request=request, actor=me,
        action="feature_flag.delete",
        target_type="feature_flag", target_id=flag_id,
        before={"key": key}, after=None,
    )
    return MessageResponse(message="Flag deleted", message_ar="تم حذف العلامة")


@router.post(
    "/feature-flags/{flag_id}/reset-assignments",
    response_model=MessageResponse,
)
async def reset_flag_assignments(
    flag_id: int,
    request: Request,
    me: User = Depends(_admin_only),
    db: AsyncSession = Depends(get_db),
):
    """Drop every sticky assignment for a flag.

    Useful when an A/B test wraps up and the admin wants to re-shuffle
    user buckets for the next experiment.
    """
    flag = await db.get(FeatureFlag, flag_id)
    if flag is None:
        raise HTTPException(status_code=404, detail="Flag not found")
    deleted = (await db.execute(
        select(func.count(FeatureFlagAssignment.id)).where(
            FeatureFlagAssignment.flag_id == flag_id,
        )
    )).scalar() or 0
    await db.execute(
        sa_delete(FeatureFlagAssignment).where(
            FeatureFlagAssignment.flag_id == flag_id,
        )
    )
    await db.flush()
    await log_action(
        db, request=request, actor=me,
        action="feature_flag.reset_assignments",
        target_type="feature_flag", target_id=flag_id,
        before={"assignments": int(deleted)}, after={"assignments": 0},
    )
    return MessageResponse(
        message=f"Cleared {deleted} assignments",
        message_ar=f"تم مسح {deleted} تعيينات",
    )


# ════════════════════════════════════════════════════════════════
#  WAVE 30 — Partner / integration API keys
# ════════════════════════════════════════════════════════════════
class _ApiKeyOut(BaseModel):
    id: int
    name: str
    description: str | None = None
    key_prefix: str
    scopes: list[str]
    created_by: int | None = None
    created_at: datetime
    expires_at: datetime | None = None
    revoked_at: datetime | None = None
    last_used_at: datetime | None = None
    usage_count: int

    model_config = {"from_attributes": True}


class _ApiKeyCreate(BaseModel):
    name: str
    description: str | None = None
    scopes: list[str] = []
    expires_at: datetime | None = None


class _ApiKeyCreated(_ApiKeyOut):
    """Wrapper that exposes the plaintext exactly once on creation."""
    plaintext: str


class _ApiKeyScopesOut(BaseModel):
    scopes: list[str]


@router.get("/api-keys/scopes", response_model=_ApiKeyScopesOut)
async def list_allowed_scopes(_: User = Depends(_admin_only)):
    """Return the canonical scope list so the UI can render checkboxes."""
    return _ApiKeyScopesOut(scopes=list(ALLOWED_SCOPES))


@router.get("/api-keys", response_model=list[_ApiKeyOut])
async def list_api_keys(
    _: User = Depends(_admin_only),
    db: AsyncSession = Depends(get_db),
):
    """List every API key, active rows first then revoked."""
    rows = (await db.execute(
        select(ApiKey).order_by(
            ApiKey.revoked_at.is_(None).desc(),
            ApiKey.created_at.desc(),
        )
    )).scalars().all()
    return [_ApiKeyOut.model_validate(r) for r in rows]


@router.post("/api-keys", response_model=_ApiKeyCreated, status_code=201)
async def create_api_key(
    body: _ApiKeyCreate,
    request: Request,
    me: User = Depends(_admin_only),
    db: AsyncSession = Depends(get_db),
):
    """Mint a brand-new key.

    The plaintext is included in the response **once**.  The frontend
    must show it to the admin in a copy-once dialog and warn that it
    cannot be retrieved later.
    """
    if not body.name.strip():
        raise HTTPException(status_code=400, detail="الاسم مطلوب")
    valid_scopes = validate_scopes(body.scopes)
    plaintext, prefix, key_hash = mint_new_key()
    row = ApiKey(
        name=body.name.strip()[:120],
        description=body.description,
        key_prefix=prefix,
        key_hash=key_hash,
        scopes=valid_scopes,
        expires_at=body.expires_at,
        created_by=me.id,
    )
    db.add(row)
    await db.flush()
    await db.refresh(row)
    await log_action(
        db, request=request, actor=me,
        action="api_key.create",
        target_type="api_key", target_id=row.id,
        before=None, after={"name": row.name, "scopes": valid_scopes},
    )
    base = _ApiKeyOut.model_validate(row).model_dump()
    return _ApiKeyCreated(**base, plaintext=plaintext)


@router.post("/api-keys/{key_id}/revoke", response_model=_ApiKeyOut)
async def revoke_api_key(
    key_id: int,
    request: Request,
    me: User = Depends(_admin_only),
    db: AsyncSession = Depends(get_db),
):
    """Mark a key as revoked (soft-delete).

    Revoked keys keep showing up in the list with a strike-through so
    we have a forensic record.  The hash is left in place — it just
    fails the ``revoked_at IS NULL`` check at auth time.
    """
    row = await db.get(ApiKey, key_id)
    if row is None:
        raise HTTPException(status_code=404, detail="API key not found")
    if row.revoked_at is not None:
        raise HTTPException(status_code=400, detail="Key already revoked")
    revoked = datetime.now()
    row.revoked_at = revoked
    await db.flush()
    await db.refresh(row)
    await log_action(
        db, request=request, actor=me,
        action="api_key.revoke",
        target_type="api_key", target_id=row.id,
        before={"revoked_at": None},
        after={"revoked_at": revoked.isoformat()},
    )
    return _ApiKeyOut.model_validate(row)


@router.delete("/api-keys/{key_id}", response_model=MessageResponse)
async def delete_api_key(
    key_id: int,
    request: Request,
    me: User = Depends(_admin_only),
    db: AsyncSession = Depends(get_db),
):
    """Hard-delete an API key row entirely.

    Use sparingly — this loses the audit trail.  Prefer ``/revoke``.
    """
    row = await db.get(ApiKey, key_id)
    if row is None:
        raise HTTPException(status_code=404, detail="API key not found")
    name = row.name
    await db.delete(row)
    await db.flush()
    await log_action(
        db, request=request, actor=me,
        action="api_key.delete",
        target_type="api_key", target_id=key_id,
        before={"name": name}, after=None,
    )
    return MessageResponse(
        message="API key deleted", message_ar="تم حذف المفتاح",
    )


# ════════════════════════════════════════════════════════════════
#  WAVE 30 — Promo banners (admin CRUD)
# ════════════════════════════════════════════════════════════════
class _PromoBannerOut(BaseModel):
    id: int
    title_ar: str | None = None
    title_en: str | None = None
    subtitle_ar: str | None = None
    subtitle_en: str | None = None
    image_url: str
    accent_color: str | None = None
    cta_kind: str
    cta_target: str | None = None
    priority: int
    is_active: bool
    start_at: datetime | None = None
    end_at: datetime | None = None
    impressions: int
    clicks: int
    created_by: int | None = None
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}


class _PromoBannerCreate(BaseModel):
    title_ar: str | None = None
    title_en: str | None = None
    subtitle_ar: str | None = None
    subtitle_en: str | None = None
    image_url: str
    accent_color: str | None = None
    cta_kind: str = "none"
    cta_target: str | None = None
    priority: int = 0
    is_active: bool = False
    start_at: datetime | None = None
    end_at: datetime | None = None


class _PromoBannerUpdate(BaseModel):
    title_ar: str | None = None
    title_en: str | None = None
    subtitle_ar: str | None = None
    subtitle_en: str | None = None
    image_url: str | None = None
    accent_color: str | None = None
    cta_kind: str | None = None
    cta_target: str | None = None
    priority: int | None = None
    is_active: bool | None = None
    start_at: datetime | None = None
    end_at: datetime | None = None


def _banner_cta_or_400(value: str) -> BannerCtaKind:
    try:
        return BannerCtaKind(value)
    except ValueError as exc:
        raise HTTPException(
            status_code=400,
            detail="نوع CTA غير معروف / unknown cta_kind",
        ) from exc


def _banner_to_out(b: PromoBanner) -> _PromoBannerOut:
    out = _PromoBannerOut.model_validate(b)
    out.cta_kind = b.cta_kind.value
    return out


@router.get("/promo-banners", response_model=list[_PromoBannerOut])
async def list_promo_banners(
    _: User = Depends(_admin_only),
    db: AsyncSession = Depends(get_db),
):
    """All banners (active + inactive), highest priority first."""
    rows = (await db.execute(
        select(PromoBanner).order_by(
            PromoBanner.priority.desc(),
            PromoBanner.created_at.desc(),
        )
    )).scalars().all()
    return [_banner_to_out(r) for r in rows]


@router.post(
    "/promo-banners", response_model=_PromoBannerOut, status_code=201,
)
async def create_promo_banner(
    body: _PromoBannerCreate,
    request: Request,
    me: User = Depends(_admin_only),
    db: AsyncSession = Depends(get_db),
):
    """Create a banner.

    By default the banner is created with ``is_active=False`` so the
    admin can preview & double-check the copy/image before exposing
    it on the homepage.
    """
    if not body.image_url.strip():
        raise HTTPException(status_code=400, detail="image_url مطلوب")
    row = PromoBanner(
        title_ar=body.title_ar,
        title_en=body.title_en,
        subtitle_ar=body.subtitle_ar,
        subtitle_en=body.subtitle_en,
        image_url=body.image_url.strip(),
        accent_color=body.accent_color,
        cta_kind=_banner_cta_or_400(body.cta_kind),
        cta_target=body.cta_target,
        priority=body.priority,
        is_active=body.is_active,
        start_at=body.start_at,
        end_at=body.end_at,
        created_by=me.id,
    )
    db.add(row)
    await db.flush()
    await db.refresh(row)
    await log_action(
        db, request=request, actor=me,
        action="promo_banner.create",
        target_type="promo_banner", target_id=row.id,
        before=None,
        after={"is_active": row.is_active, "priority": row.priority},
    )
    return _banner_to_out(row)


@router.patch(
    "/promo-banners/{banner_id}", response_model=_PromoBannerOut,
)
async def update_promo_banner(
    banner_id: int,
    body: _PromoBannerUpdate,
    request: Request,
    me: User = Depends(_admin_only),
    db: AsyncSession = Depends(get_db),
):
    """Patch any subset of a banner's fields."""
    row = await db.get(PromoBanner, banner_id)
    if row is None:
        raise HTTPException(status_code=404, detail="Banner not found")
    before = {"is_active": row.is_active, "priority": row.priority}
    data = body.model_dump(exclude_unset=True)
    for k, v in data.items():
        if k == "cta_kind" and v is not None:
            row.cta_kind = _banner_cta_or_400(v)
            continue
        setattr(row, k, v)
    await db.flush()
    await db.refresh(row)
    await log_action(
        db, request=request, actor=me,
        action="promo_banner.update",
        target_type="promo_banner", target_id=row.id,
        before=before,
        after={"is_active": row.is_active, "priority": row.priority},
    )
    return _banner_to_out(row)


@router.delete(
    "/promo-banners/{banner_id}", response_model=MessageResponse,
)
async def delete_promo_banner(
    banner_id: int,
    request: Request,
    me: User = Depends(_admin_only),
    db: AsyncSession = Depends(get_db),
):
    row = await db.get(PromoBanner, banner_id)
    if row is None:
        raise HTTPException(status_code=404, detail="Banner not found")
    await db.delete(row)
    await db.flush()
    await log_action(
        db, request=request, actor=me,
        action="promo_banner.delete",
        target_type="promo_banner", target_id=banner_id,
        before=None, after=None,
    )
    return MessageResponse(
        message="Banner deleted", message_ar="تم حذف البانر",
    )


# ════════════════════════════════════════════════════════════════
#  WAVE 30 — Chat moderation (admin chat-monitor page)
# ════════════════════════════════════════════════════════════════
class _ChatMessageRow(BaseModel):
    id: int
    conversation_id: int
    sender_id: int
    sender_name: str | None = None
    body: str
    kind: str
    is_flagged: bool
    is_hidden: bool
    flag_reason: str | None = None
    created_at: datetime


class _ChatConversationRow(BaseModel):
    """One row in the admin chat-monitor conversation list.

    Aggregates per-conversation metadata so the moderator can pick a
    specific thread to read instead of scrolling a flat firehose.
    """

    id: int
    guest_id: int
    guest_name: str | None = None
    owner_id: int
    owner_name: str | None = None
    property_id: int | None = None
    property_name: str | None = None
    status: str
    last_message_at: datetime | None = None
    last_message_preview: str | None = None
    message_count: int
    flagged_count: int
    hidden_count: int


@router.get(
    "/chat/conversations",
    response_model=list[_ChatConversationRow],
)
async def list_chat_conversations(
    flagged_only: bool = Query(
        False,
        description="Only conversations that contain at least one flagged message.",
    ),
    hidden_only: bool = Query(
        False,
        description="Only conversations that contain at least one hidden message.",
    ),
    limit: int = Query(100, ge=1, le=500),
    _: User = Depends(_admin_only),
    db: AsyncSession = Depends(get_db),
):
    """List conversations with moderation aggregates so the admin can
    pick a single thread to inspect.  Sorted by ``last_message_at``
    descending (most recently active first)."""

    # Aggregate per-conversation message counts.
    agg_q = (
        select(
            Message.conversation_id.label("cid"),
            func.count(Message.id).label("total"),
            func.sum(
                func.cast(Message.is_flagged, Integer)
            ).label("flagged"),
            func.sum(
                func.cast(Message.is_hidden, Integer)
            ).label("hidden"),
        )
        .group_by(Message.conversation_id)
    )
    agg_rows = (await db.execute(agg_q)).all()
    agg_map: dict[int, tuple[int, int, int]] = {
        int(r.cid): (
            int(r.total or 0),
            int(r.flagged or 0),
            int(r.hidden or 0),
        )
        for r in agg_rows
    }

    # Pick the conversation IDs that pass the filter.
    if flagged_only:
        candidate_ids = {
            cid for cid, (_, f, _h) in agg_map.items() if f > 0
        }
    elif hidden_only:
        candidate_ids = {
            cid for cid, (_, _f, h) in agg_map.items() if h > 0
        }
    else:
        candidate_ids = None  # no filter

    q = select(Conversation).order_by(
        Conversation.last_message_at.desc().nullslast(),
        Conversation.id.desc(),
    )
    if candidate_ids is not None:
        if not candidate_ids:
            return []
        q = q.where(Conversation.id.in_(candidate_ids))
    q = q.limit(limit)
    convs = (await db.execute(q)).scalars().all()

    # Resolve guest/owner names with one extra query.
    user_ids: set[int] = set()
    for c in convs:
        user_ids.add(c.guest_id)
        user_ids.add(c.owner_id)
    name_map: dict[int, str] = {}
    if user_ids:
        urows = (await db.execute(
            select(User.id, User.name).where(User.id.in_(user_ids))
        )).all()
        name_map = {int(uid): (n or "") for uid, n in urows}

    # Resolve property names.
    prop_ids = {c.property_id for c in convs if c.property_id is not None}
    prop_map: dict[int, str] = {}
    if prop_ids:
        prows = (await db.execute(
            select(Property.id, Property.name).where(
                Property.id.in_(prop_ids)
            )
        )).all()
        prop_map = {int(pid): (n or "") for pid, n in prows}

    out: list[_ChatConversationRow] = []
    for c in convs:
        total, flagged, hidden = agg_map.get(c.id, (0, 0, 0))
        out.append(_ChatConversationRow(
            id=c.id,
            guest_id=c.guest_id,
            guest_name=name_map.get(c.guest_id),
            owner_id=c.owner_id,
            owner_name=name_map.get(c.owner_id),
            property_id=c.property_id,
            property_name=(
                prop_map.get(c.property_id)
                if c.property_id is not None else None
            ),
            status=(
                c.status.value
                if hasattr(c.status, "value") else str(c.status)
            ),
            last_message_at=c.last_message_at,
            last_message_preview=c.last_message_preview,
            message_count=total,
            flagged_count=flagged,
            hidden_count=hidden,
        ))
    return out


@router.get("/chat/messages", response_model=list[_ChatMessageRow])
async def list_chat_messages(
    flagged_only: bool = Query(False),
    hidden_only: bool = Query(False),
    conversation_id: int | None = Query(None),
    limit: int = Query(100, ge=1, le=500),
    _: User = Depends(_admin_only),
    db: AsyncSession = Depends(get_db),
):
    """List the latest chat messages — full visibility for moderators.

    Defaults to "newest first" with no filter so the admin can scroll
    a unified feed.  Toggle ``flagged_only=true`` to drain the auto-
    flagged queue.  Pass ``conversation_id`` to drill into a single
    chat thread (returned in chronological order so the admin can read
    the conversation top-to-bottom).
    """
    if conversation_id is not None:
        # Chronological for single-thread inspection.
        q = (
            select(Message)
            .where(Message.conversation_id == conversation_id)
            .order_by(Message.created_at.asc())
            .limit(limit)
        )
    else:
        q = select(Message).order_by(Message.created_at.desc()).limit(limit)
    if flagged_only:
        q = q.where(Message.is_flagged.is_(True))
    if hidden_only:
        q = q.where(Message.is_hidden.is_(True))
    rows = (await db.execute(q)).scalars().all()

    # Hydrate sender names with one extra query — keeps the JSON small.
    sender_ids = {r.sender_id for r in rows}
    sender_map: dict[int, str] = {}
    if sender_ids:
        urows = (await db.execute(
            select(User.id, User.name).where(User.id.in_(sender_ids))
        )).all()
        sender_map = {int(uid): (name or "") for uid, name in urows}

    out = []
    for r in rows:
        out.append(_ChatMessageRow(
            id=r.id,
            conversation_id=r.conversation_id,
            sender_id=r.sender_id,
            sender_name=sender_map.get(r.sender_id),
            body=r.body,
            kind=r.kind.value if hasattr(r.kind, "value") else str(r.kind),
            is_flagged=r.is_flagged,
            is_hidden=r.is_hidden,
            flag_reason=r.flag_reason,
            created_at=r.created_at,
        ))
    return out


class _ChatModerationAction(BaseModel):
    note: str | None = None


@router.post(
    "/chat/messages/{message_id}/hide",
    response_model=_ChatMessageRow,
)
async def hide_chat_message(
    message_id: int,
    body: _ChatModerationAction | None = None,
    request: Request = None,  # type: ignore[assignment]
    me: User = Depends(_admin_only),
    db: AsyncSession = Depends(get_db),
):
    """Hide an offensive / off-policy message from the public chat.

    The body stays in the DB for audit/legal reasons; the public chat
    API replaces it with a placeholder.
    """
    row = await db.get(Message, message_id)
    if row is None:
        raise HTTPException(status_code=404, detail="Message not found")
    row.is_hidden = True
    if body and body.note:
        row.flag_reason = body.note.strip()[:200] or row.flag_reason
    await db.flush()
    await db.refresh(row)
    await log_action(
        db, request=request, actor=me,
        action="chat.hide",
        target_type="message", target_id=row.id,
        before={"is_hidden": False}, after={"is_hidden": True},
    )
    return _ChatMessageRow(
        id=row.id, conversation_id=row.conversation_id,
        sender_id=row.sender_id, sender_name=None, body=row.body,
        kind=row.kind.value if hasattr(row.kind, "value") else str(row.kind),
        is_flagged=row.is_flagged, is_hidden=row.is_hidden,
        flag_reason=row.flag_reason, created_at=row.created_at,
    )


@router.post(
    "/chat/messages/{message_id}/unhide",
    response_model=_ChatMessageRow,
)
async def unhide_chat_message(
    message_id: int,
    request: Request,
    me: User = Depends(_admin_only),
    db: AsyncSession = Depends(get_db),
):
    """Reverse a previous hide — the message becomes visible again."""
    row = await db.get(Message, message_id)
    if row is None:
        raise HTTPException(status_code=404, detail="Message not found")
    row.is_hidden = False
    await db.flush()
    await db.refresh(row)
    await log_action(
        db, request=request, actor=me,
        action="chat.unhide",
        target_type="message", target_id=row.id,
        before={"is_hidden": True}, after={"is_hidden": False},
    )
    return _ChatMessageRow(
        id=row.id, conversation_id=row.conversation_id,
        sender_id=row.sender_id, sender_name=None, body=row.body,
        kind=row.kind.value if hasattr(row.kind, "value") else str(row.kind),
        is_flagged=row.is_flagged, is_hidden=row.is_hidden,
        flag_reason=row.flag_reason, created_at=row.created_at,
    )


@router.post(
    "/chat/messages/{message_id}/clear-flag",
    response_model=_ChatMessageRow,
)
async def clear_chat_flag(
    message_id: int,
    request: Request,
    me: User = Depends(_admin_only),
    db: AsyncSession = Depends(get_db),
):
    """Mark an auto-flagged message as a false positive.

    Useful when the keyword filter trips on a benign sentence — clearing
    the flag drops the row out of the moderator queue.
    """
    row = await db.get(Message, message_id)
    if row is None:
        raise HTTPException(status_code=404, detail="Message not found")
    row.is_flagged = False
    row.flag_reason = None
    await db.flush()
    await db.refresh(row)
    await log_action(
        db, request=request, actor=me,
        action="chat.clear_flag",
        target_type="message", target_id=row.id,
        before={"is_flagged": True}, after={"is_flagged": False},
    )
    return _ChatMessageRow(
        id=row.id, conversation_id=row.conversation_id,
        sender_id=row.sender_id, sender_name=None, body=row.body,
        kind=row.kind.value if hasattr(row.kind, "value") else str(row.kind),
        is_flagged=row.is_flagged, is_hidden=row.is_hidden,
        flag_reason=row.flag_reason, created_at=row.created_at,
    )
