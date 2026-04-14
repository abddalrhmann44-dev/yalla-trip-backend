"""Bookings router – create, list, confirm, cancel, complete."""

from __future__ import annotations

import math
import secrets
import string
from datetime import date, timedelta

import structlog
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import and_, func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import get_settings
from app.database import get_db
from app.middleware.auth_middleware import get_current_active_user, require_role
from app.models.booking import Booking, BookingStatus, DepositStatus, PaymentStatus
from app.models.notification import NotificationType
from app.models.property import Category, Property
from app.models.user import User, UserRole
from app.schemas.booking import BookingCreate, BookingOut
from app.schemas.common import MessageResponse, PaginatedResponse
from app.services.notification_service import create_notification

logger = structlog.get_logger(__name__)
settings = get_settings()
router = APIRouter(prefix="/bookings", tags=["Bookings"])

_CODE_CHARS = string.ascii_uppercase + string.digits


async def _generate_code(db: AsyncSession) -> str:
    """Generate a unique 8-char booking code with collision check."""
    for _ in range(20):
        code = "".join(secrets.choice(_CODE_CHARS) for _ in range(8))
        exists = (
            await db.execute(select(Booking.id).where(Booking.booking_code == code))
        ).scalar_one_or_none()
        if exists is None:
            return code
    raise RuntimeError("Could not generate unique booking code")


class _PriceBreakdown:
    """Result of price calculation."""
    __slots__ = (
        "nights_total", "cleaning_fee", "electricity_fee", "water_fee",
        "security_deposit", "total_price", "platform_fee", "owner_payout",
    )

    def __init__(self, **kw):
        for k, v in kw.items():
            setattr(self, k, v)


def _calc_price(
    prop: Property,
    check_in: date,
    check_out: date,
) -> _PriceBreakdown:
    """Calculate full price breakdown including utilities and deposit."""
    nights_total = 0.0
    day = check_in
    while day < check_out:
        is_weekend = day.weekday() in (4, 5)  # Friday / Saturday (Egypt)
        rate = (prop.weekend_price or prop.price_per_night) if is_weekend else prop.price_per_night
        nights_total += rate
        day += timedelta(days=1)

    # Cleaning fee: chalets, villas, beach houses only
    _has_cleaning = prop.category in (Category.chalet, Category.villa, Category.beach_house)
    cleaning_fee = (prop.cleaning_fee or 0.0) if _has_cleaning else 0.0

    # Utility fees & security deposit apply to chalets only
    is_chalet = prop.category == Category.chalet
    electricity_fee = (prop.electricity_fee or 0.0) if is_chalet else 0.0
    water_fee = (prop.water_fee or 0.0) if is_chalet else 0.0
    security_deposit = (prop.security_deposit or 0.0) if is_chalet else 0.0

    # total = nights + cleaning + utilities (deposit is separate / refundable)
    subtotal = nights_total + cleaning_fee + electricity_fee + water_fee
    fee_pct = settings.PLATFORM_FEE_PERCENT / 100.0
    platform_fee = round(subtotal * fee_pct, 2)
    owner_payout = round(subtotal - platform_fee, 2)
    # total the guest pays = subtotal + deposit
    total_price = round(subtotal + security_deposit, 2)

    return _PriceBreakdown(
        nights_total=round(nights_total, 2),
        cleaning_fee=round(cleaning_fee, 2),
        electricity_fee=round(electricity_fee, 2),
        water_fee=round(water_fee, 2),
        security_deposit=round(security_deposit, 2),
        total_price=total_price,
        platform_fee=platform_fee,
        owner_payout=owner_payout,
    )


async def _count_overlapping(
    db: AsyncSession,
    property_id: int,
    check_in: date,
    check_out: date,
    exclude_id: int | None = None,
) -> int:
    """Count how many active bookings overlap with the given date range."""
    stmt = select(func.count()).select_from(Booking).where(
        Booking.property_id == property_id,
        Booking.status.in_([BookingStatus.pending, BookingStatus.confirmed]),
        Booking.check_in < check_out,
        Booking.check_out > check_in,
    )
    if exclude_id:
        stmt = stmt.where(Booking.id != exclude_id)
    return (await db.execute(stmt)).scalar() or 0


async def _check_availability(
    db: AsyncSession,
    prop: Property,
    check_in: date,
    check_out: date,
    exclude_id: int | None = None,
) -> bool:
    """Return True if at least one room/unit is available for the date range.

    - Chalet / Villa (total_rooms=1): blocked if any booking overlaps.
    - Hotel / Resort (total_rooms=N): blocked only when all N rooms are booked.
    - Beach / Aqua Park (total_rooms=0): unlimited — always available.
    """
    if prop.total_rooms == 0:
        return True  # unlimited capacity
    booked = await _count_overlapping(db, prop.id, check_in, check_out, exclude_id)
    return booked < prop.total_rooms


@router.post("", response_model=BookingOut, status_code=status.HTTP_201_CREATED)
async def create_booking(
    body: BookingCreate,
    user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db),
):
    # lookup property
    result = await db.execute(select(Property).where(Property.id == body.property_id))
    prop = result.scalar_one_or_none()
    if prop is None:
        raise HTTPException(status_code=404, detail="العقار غير موجود / Property not found")
    if not prop.is_available:
        raise HTTPException(status_code=400, detail="العقار غير متاح / Property not available")
    if body.guests_count > prop.max_guests:
        raise HTTPException(
            status_code=400,
            detail=f"الحد الأقصى {prop.max_guests} أشخاص / Max {prop.max_guests} guests",
        )

    # availability check (rooms vs overlapping bookings)
    if not await _check_availability(db, prop, body.check_in, body.check_out):
        if prop.total_rooms == 1:
            detail = "التواريخ محجوزة بالفعل / Dates already booked"
        else:
            detail = "جميع الغرف محجوزة في هذه التواريخ / All rooms booked for these dates"
        raise HTTPException(status_code=409, detail=detail)

    price = _calc_price(prop, body.check_in, body.check_out)
    code = await _generate_code(db)

    initial_status = (
        BookingStatus.confirmed if prop.instant_booking else BookingStatus.pending
    )

    booking = Booking(
        booking_code=code,
        property_id=prop.id,
        guest_id=user.id,
        owner_id=prop.owner_id,
        check_in=body.check_in,
        check_out=body.check_out,
        guests_count=body.guests_count,
        electricity_fee=price.electricity_fee,
        water_fee=price.water_fee,
        security_deposit=price.security_deposit,
        deposit_status=DepositStatus.held if price.security_deposit > 0 else DepositStatus.refunded,
        total_price=price.total_price,
        platform_fee=price.platform_fee,
        owner_payout=price.owner_payout,
        status=initial_status,
    )
    db.add(booking)
    await db.flush()
    await db.refresh(booking)

    # notifications
    await create_notification(
        db, prop.owner_id,
        title="حجز جديد",
        body=f"تم حجز {prop.name} من {body.check_in} إلى {body.check_out}",
        notif_type=NotificationType.booking_created,
    )

    logger.info("booking_created", booking_id=booking.id, code=code)
    return BookingOut.model_validate(booking)


@router.get("/my", response_model=PaginatedResponse[BookingOut])
async def my_bookings(
    page: int = Query(1, ge=1),
    limit: int = Query(20, ge=1, le=100),
    status_filter: BookingStatus | None = None,
    user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db),
):
    """Bookings where current user is the guest."""
    stmt = select(Booking).where(Booking.guest_id == user.id)
    if status_filter:
        stmt = stmt.where(Booking.status == status_filter)
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


@router.get("/owner", response_model=PaginatedResponse[BookingOut])
async def owner_bookings(
    page: int = Query(1, ge=1),
    limit: int = Query(20, ge=1, le=100),
    status_filter: BookingStatus | None = None,
    user: User = Depends(require_role(UserRole.owner, UserRole.admin)),
    db: AsyncSession = Depends(get_db),
):
    """Bookings where current user is the property owner."""
    stmt = select(Booking).where(Booking.owner_id == user.id)
    if status_filter:
        stmt = stmt.where(Booking.status == status_filter)
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


@router.put("/{booking_id}/confirm", response_model=BookingOut)
async def confirm_booking(
    booking_id: int,
    user: User = Depends(require_role(UserRole.owner, UserRole.admin)),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(Booking).where(Booking.id == booking_id))
    booking = result.scalar_one_or_none()
    if booking is None:
        raise HTTPException(status_code=404, detail="الحجز غير موجود / Booking not found")
    if booking.owner_id != user.id and user.role != UserRole.admin:
        raise HTTPException(status_code=403, detail="ليس لديك صلاحية / Not your booking")
    if booking.status != BookingStatus.pending:
        raise HTTPException(status_code=400, detail="لا يمكن تأكيد هذا الحجز / Cannot confirm")

    booking.status = BookingStatus.confirmed
    await db.flush()
    await db.refresh(booking)

    await create_notification(
        db, booking.guest_id,
        title="تم تأكيد حجزك",
        body=f"حجزك برقم {booking.booking_code} تم تأكيده",
        notif_type=NotificationType.booking_confirmed,
    )

    return BookingOut.model_validate(booking)


@router.put("/{booking_id}/cancel", response_model=BookingOut)
async def cancel_booking(
    booking_id: int,
    user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(Booking).where(Booking.id == booking_id))
    booking = result.scalar_one_or_none()
    if booking is None:
        raise HTTPException(status_code=404, detail="الحجز غير موجود / Booking not found")
    if booking.guest_id != user.id and booking.owner_id != user.id and user.role != UserRole.admin:
        raise HTTPException(status_code=403, detail="ليس لديك صلاحية / Not authorized")
    if booking.status in (BookingStatus.cancelled, BookingStatus.completed):
        raise HTTPException(status_code=400, detail="لا يمكن إلغاء هذا الحجز / Cannot cancel")

    booking.status = BookingStatus.cancelled
    await db.flush()
    await db.refresh(booking)

    # notify both parties
    notify_user = booking.owner_id if user.id == booking.guest_id else booking.guest_id
    await create_notification(
        db, notify_user,
        title="تم إلغاء الحجز",
        body=f"حجز {booking.booking_code} تم إلغاؤه",
        notif_type=NotificationType.booking_cancelled,
    )

    return BookingOut.model_validate(booking)


@router.put("/{booking_id}/complete", response_model=BookingOut)
async def complete_booking(
    booking_id: int,
    user: User = Depends(require_role(UserRole.owner, UserRole.admin)),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(Booking).where(Booking.id == booking_id))
    booking = result.scalar_one_or_none()
    if booking is None:
        raise HTTPException(status_code=404, detail="الحجز غير موجود / Booking not found")
    if booking.owner_id != user.id and user.role != UserRole.admin:
        raise HTTPException(status_code=403, detail="ليس لديك صلاحية / Not authorized")
    if booking.status != BookingStatus.confirmed:
        raise HTTPException(status_code=400, detail="لا يمكن إتمام هذا الحجز / Cannot complete")

    booking.status = BookingStatus.completed
    await db.flush()
    await db.refresh(booking)

    await create_notification(
        db, booking.guest_id,
        title="اكتملت إقامتك",
        body=f"نأمل أنك استمتعت! شاركنا رأيك عن {booking.booking_code}",
        notif_type=NotificationType.booking_completed,
    )

    return BookingOut.model_validate(booking)


@router.put("/{booking_id}/deposit/refund", response_model=BookingOut)
async def refund_deposit(
    booking_id: int,
    user: User = Depends(require_role(UserRole.owner, UserRole.admin)),
    db: AsyncSession = Depends(get_db),
):
    """Refund the security deposit back to the guest after checkout."""
    result = await db.execute(select(Booking).where(Booking.id == booking_id))
    booking = result.scalar_one_or_none()
    if booking is None:
        raise HTTPException(status_code=404, detail="الحجز غير موجود / Booking not found")
    if booking.owner_id != user.id and user.role != UserRole.admin:
        raise HTTPException(status_code=403, detail="ليس لديك صلاحية / Not authorized")
    if booking.status != BookingStatus.completed:
        raise HTTPException(status_code=400, detail="الحجز لم يكتمل بعد / Booking not completed yet")
    if booking.deposit_status != DepositStatus.held:
        raise HTTPException(status_code=400, detail="التأمين تم معالجته بالفعل / Deposit already processed")

    booking.deposit_status = DepositStatus.refunded
    await db.flush()
    await db.refresh(booking)

    await create_notification(
        db, booking.guest_id,
        title="تم استرداد التأمين",
        body=f"تم استرداد مبلغ التأمين {booking.security_deposit} ج.م لحجز {booking.booking_code}",
        notif_type=NotificationType.payment_received,
    )

    logger.info("deposit_refunded", booking_id=booking.id, amount=booking.security_deposit)
    return BookingOut.model_validate(booking)


@router.put("/{booking_id}/deposit/deduct", response_model=BookingOut)
async def deduct_deposit(
    booking_id: int,
    user: User = Depends(require_role(UserRole.owner, UserRole.admin)),
    db: AsyncSession = Depends(get_db),
):
    """Deduct the security deposit (e.g., property damage) — does not refund to guest."""
    result = await db.execute(select(Booking).where(Booking.id == booking_id))
    booking = result.scalar_one_or_none()
    if booking is None:
        raise HTTPException(status_code=404, detail="الحجز غير موجود / Booking not found")
    if booking.owner_id != user.id and user.role != UserRole.admin:
        raise HTTPException(status_code=403, detail="ليس لديك صلاحية / Not authorized")
    if booking.status != BookingStatus.completed:
        raise HTTPException(status_code=400, detail="الحجز لم يكتمل بعد / Booking not completed yet")
    if booking.deposit_status != DepositStatus.held:
        raise HTTPException(status_code=400, detail="التأمين تم معالجته بالفعل / Deposit already processed")

    booking.deposit_status = DepositStatus.deducted
    await db.flush()
    await db.refresh(booking)

    await create_notification(
        db, booking.guest_id,
        title="تم خصم التأمين",
        body=f"تم خصم مبلغ التأمين {booking.security_deposit} ج.م لحجز {booking.booking_code} بسبب تلفيات",
        notif_type=NotificationType.payment_received,
    )

    logger.info("deposit_deducted", booking_id=booking.id, amount=booking.security_deposit)
    return BookingOut.model_validate(booking)
