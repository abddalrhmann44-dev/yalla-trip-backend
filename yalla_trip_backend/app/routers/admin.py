"""Admin router – user/property management, stats dashboard."""

from __future__ import annotations

import math

import structlog
from fastapi import APIRouter, Depends, HTTPException, Query, Request
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from pydantic import BaseModel

from app.database import get_db
from app.middleware.auth_middleware import require_role
from app.models.booking import Booking, BookingStatus, PaymentStatus
from app.models.property import Property, PropertyStatus
from app.models.review import Review
from app.models.user import User, UserRole
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


# ── Reviews moderation ────────────────────────────────────
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
