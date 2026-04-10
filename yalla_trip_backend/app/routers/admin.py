"""Admin router – user/property management, stats dashboard."""

from __future__ import annotations

import math

import structlog
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.middleware.auth_middleware import require_role
from app.models.booking import Booking, BookingStatus, PaymentStatus
from app.models.property import Property
from app.models.review import Review
from app.models.user import User, UserRole
from app.schemas.common import MessageResponse, PaginatedResponse
from app.schemas.property import PropertyOut
from app.schemas.user import UserOut

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
    _: User = Depends(_admin_only),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()
    if user is None:
        raise HTTPException(status_code=404, detail="المستخدم غير موجود / User not found")
    user.is_active = False
    await db.flush()
    logger.info("admin_deactivated_user", user_id=user_id)
    return MessageResponse(
        message="User deactivated",
        message_ar="تم تعطيل المستخدم",
    )


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


@router.put("/properties/{property_id}/approve", response_model=PropertyOut)
async def approve_property(
    property_id: int,
    _: User = Depends(_admin_only),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(Property).where(Property.id == property_id))
    prop = result.scalar_one_or_none()
    if prop is None:
        raise HTTPException(status_code=404, detail="العقار غير موجود / Property not found")
    prop.is_available = True
    await db.flush()
    await db.refresh(prop)
    logger.info("admin_approved_property", property_id=property_id)
    return PropertyOut.model_validate(prop)


# ── Stats dashboard ───────────────────────────────────────
@router.get("/stats")
async def dashboard_stats(
    _: User = Depends(_admin_only),
    db: AsyncSession = Depends(get_db),
):
    """Return aggregated platform statistics."""
    total_users = (await db.execute(select(func.count(User.id)))).scalar() or 0
    total_owners = (
        await db.execute(select(func.count(User.id)).where(User.role == UserRole.owner))
    ).scalar() or 0
    total_properties = (await db.execute(select(func.count(Property.id)))).scalar() or 0
    total_bookings = (await db.execute(select(func.count(Booking.id)))).scalar() or 0
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
        "total_owners": total_owners,
        "total_properties": total_properties,
        "total_bookings": total_bookings,
        "confirmed_bookings": confirmed_bookings,
        "total_reviews": total_reviews,
        "total_revenue": float(total_revenue),
        "total_platform_fees": float(total_platform_fees),
        "total_owner_payouts": float(total_owner_payouts),
        "currency": "EGP",
    }
