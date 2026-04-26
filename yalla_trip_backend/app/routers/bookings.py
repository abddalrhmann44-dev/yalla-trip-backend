"""Bookings router – create, list, confirm, cancel, complete."""

from __future__ import annotations

import math
import secrets
import string
from datetime import date, datetime, timedelta, timezone

import structlog
from fastapi import APIRouter, Depends, HTTPException, Query, status
from pydantic import BaseModel
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import get_settings
from app.database import get_db
from app.middleware.auth_middleware import get_current_active_user, require_role
from app.models.booking import (
    Booking,
    BookingStatus,
    CashCollectionStatus,
    DepositStatus,
    PaymentStatus,
)
from app.models.availability_rule import AvailabilityRule, RuleType
from app.models.calendar import CalendarBlock
from app.models.notification import NotificationType
from app.models.payment import Payment, PaymentState
from app.models.property import Category, Property
from app.models.user import User, UserRole
from app.schemas.booking import (
    BookingCancelRequest,
    BookingCreate,
    BookingOut,
    RefundQuoteOut,
)
from app.schemas.common import PaginatedResponse
from app.services.cancellation import quote_refund
from app.services.deposit import compute_deposit_breakdown
from app.services.gateways import GatewayError, get_gateway
from app.services.notification_service import create_notification
from app.services.promo_service import redeem_for_booking
from app.services import wallet_service

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
    pricing_rules: list | None = None,
) -> _PriceBreakdown:
    """Calculate full price breakdown including utilities and deposit.

    If *pricing_rules* is provided (list of AvailabilityRule with
    rule_type == pricing), per-day overrides are applied.  Rules are
    assumed ordered by created_at so the last matching rule wins.
    """
    nights_total = 0.0
    day = check_in
    while day < check_out:
        is_weekend = day.weekday() in (4, 5)  # Friday / Saturday (Egypt)
        rate = (prop.weekend_price or prop.price_per_night) if is_weekend else prop.price_per_night

        # Apply pricing override from availability rules (last match wins)
        if pricing_rules:
            for rule in pricing_rules:
                if rule.start_date <= day < rule.end_date and rule.price_override is not None:
                    rate = rule.price_override

        nights_total += rate
        day += timedelta(days=1)

    # Cleaning fee: chalets, villas, day-use only
    _has_cleaning = prop.category in (Category.chalet, Category.villa, Category.day_use)
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
    # ── Concurrency guard ────────────────────────────────────
    # ``with_for_update`` takes a Postgres row-level lock on the
    # Property for the duration of this transaction, so two requests
    # racing for the last available room on the same listing get
    # serialised at the database level.  Without this lock both
    # requests would see ``booked < total_rooms`` and INSERT, leading
    # to overbooking.  Keep this BEFORE any availability check.
    result = await db.execute(
        select(Property)
        .where(Property.id == body.property_id)
        .with_for_update()
    )
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

    # Also honour manual/imported calendar blocks (Wave 13).  Any
    # overlapping ``CalendarBlock`` means the host has already marked
    # the property unavailable in their Airbnb/Booking.com calendar.
    blocked = (await db.execute(
        select(func.count(CalendarBlock.id))
        .where(
            CalendarBlock.property_id == prop.id,
            CalendarBlock.start_date < body.check_out,
            CalendarBlock.end_date > body.check_in,
        )
    )).scalar() or 0
    if blocked > 0:
        raise HTTPException(
            status_code=409,
            detail="التواريخ غير متاحة / Dates blocked by host",
        )

    # ── Availability rules (Wave 14) ────────────────────────
    avail_rules = (await db.execute(
        select(AvailabilityRule)
        .where(
            AvailabilityRule.property_id == prop.id,
            AvailabilityRule.start_date < body.check_out,
            AvailabilityRule.end_date > body.check_in,
        )
        .order_by(AvailabilityRule.created_at)
    )).scalars().all()

    # Check closed days
    closed_rules = [r for r in avail_rules if r.rule_type == RuleType.closed]
    for rule in closed_rules:
        # If any day in [check_in, check_out) falls in a closed range, reject
        overlap_start = max(body.check_in, rule.start_date)
        overlap_end = min(body.check_out, rule.end_date)
        if overlap_start < overlap_end:
            raise HTTPException(
                status_code=409,
                detail="التواريخ مغلقة من قبل المالك / Dates closed by host",
            )

    # Check minimum stay
    stay_nights = (body.check_out - body.check_in).days
    min_stay_rules = [r for r in avail_rules if r.rule_type == RuleType.min_stay]
    for rule in min_stay_rules:
        # Rule applies if any day of the booking falls in its range
        overlap_start = max(body.check_in, rule.start_date)
        overlap_end = min(body.check_out, rule.end_date)
        if overlap_start < overlap_end and rule.min_nights and stay_nights < rule.min_nights:
            raise HTTPException(
                status_code=422,
                detail=(
                    f"الحد الأدنى {rule.min_nights} ليالي / "
                    f"Minimum stay {rule.min_nights} nights"
                ),
            )

    # Price calculation with pricing overrides
    pricing_rules = [r for r in avail_rules if r.rule_type == RuleType.pricing]
    price = _calc_price(prop, body.check_in, body.check_out, pricing_rules)
    code = await _generate_code(db)

    initial_status = (
        BookingStatus.confirmed if prop.instant_booking else BookingStatus.pending
    )

    # ── Promo code preview (actual redemption happens after the
    # booking row exists so we can reference its id) ─────────────
    promo_discount = 0.0
    if body.promo_code:
        from app.services.promo_service import validate_code  # local import
        preview = await validate_code(
            db, body.promo_code, price.total_price, user.id,
        )
        if not preview.valid:
            raise HTTPException(
                status_code=400,
                detail=preview.reason_ar or preview.reason or "كود غير صالح",
            )
        promo_discount = preview.discount_amount

    # Apply discount: shave it off platform_fee first (admin-issued
    # promos are a platform cost, not the owner's), then the owner
    # if the discount is bigger than the platform's cut.
    effective_total = round(price.total_price - promo_discount, 2)
    remaining_discount = promo_discount
    platform_fee_final = price.platform_fee
    owner_payout_final = price.owner_payout
    if remaining_discount > 0:
        from_platform = min(platform_fee_final, remaining_discount)
        platform_fee_final = round(platform_fee_final - from_platform, 2)
        remaining_discount -= from_platform
    if remaining_discount > 0:
        owner_payout_final = round(owner_payout_final - remaining_discount, 2)

    # ── Wallet credit (Wave 11) ──────────────────────────────
    # Applied *after* promo discount so the redemption cap is computed
    # on the post-promo total – the user cannot double-dip the same
    # EGP.  The owner's payout is untouched; wallet credit comes out
    # of the platform's pocket (it was their promo/referral rebate).
    wallet_discount = 0.0
    wallet_txn = None
    if body.wallet_amount > 0 and effective_total > 0:
        try:
            wallet_discount, wallet_txn = await wallet_service.redeem_for_booking(
                db,
                user_id=user.id,
                booking_id=None,      # patched below once we have an id
                requested=body.wallet_amount,
                subtotal=effective_total,
            )
        except ValueError as exc:
            raise HTTPException(status_code=400, detail=str(exc))

        if wallet_discount > 0:
            effective_total = round(effective_total - wallet_discount, 2)
            platform_fee_final = round(
                max(0.0, platform_fee_final - wallet_discount), 2,
            )

    # ── Wave 25 — hybrid deposit + cash-on-arrival split ────
    # Compute the up-front deposit (sized so it always covers our
    # commission and at least one nightly rate) and the cash leg the
    # host will collect on arrival.  Hosts who left
    # ``cash_on_arrival_enabled`` off get the legacy 100 %-online
    # split where ``deposit == effective_total`` and ``remaining_cash
    # == 0`` — see ``services/deposit.py`` for the full contract.
    deposit_break = compute_deposit_breakdown(
        total_price=effective_total,
        price_per_night=prop.price_per_night,
        commission_rate=settings.PLATFORM_FEE_PERCENT / 100.0,
        cash_on_arrival_enabled=prop.cash_on_arrival_enabled,
    )
    initial_cash_status = (
        CashCollectionStatus.pending
        if prop.cash_on_arrival_enabled
        else CashCollectionStatus.not_applicable
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
        total_price=effective_total,
        platform_fee=platform_fee_final,
        owner_payout=owner_payout_final,
        deposit_amount=deposit_break.deposit_amount,
        remaining_cash_amount=deposit_break.remaining_cash_amount,
        cash_collection_status=initial_cash_status,
        promo_discount=promo_discount,
        wallet_discount=wallet_discount,
        status=initial_status,
    )
    db.add(booking)
    await db.flush()
    await db.refresh(booking)

    # Patch the wallet redemption row with the real booking id.
    if wallet_txn is not None:
        wallet_txn.booking_id = booking.id
        wallet_txn.description = f"Booking #{booking.id} wallet credit"
        await db.flush()

    # Now that booking.id exists, atomically redeem the promo code.
    # A concurrent booking might have just consumed the last slot –
    # the redemption call raises ValueError in that case.
    if body.promo_code and promo_discount > 0:
        try:
            await redeem_for_booking(
                db,
                code=body.promo_code,
                booking_id=booking.id,
                user_id=user.id,
                booking_amount=price.total_price,
            )
        except ValueError as exc:
            # Undo the booking – the slot raced away from us.
            await db.delete(booking)
            await db.flush()
            raise HTTPException(status_code=409, detail=str(exc)) from exc

    # notifications
    await create_notification(
        db, prop.owner_id,
        title="حجز جديد",
        body=f"تم حجز {prop.name} من {body.check_in} إلى {body.check_out}",
        notif_type=NotificationType.booking_created,
    )

    logger.info(
        "booking_created",
        booking_id=booking.id, code=code, promo_discount=promo_discount,
    )
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


async def _load_booking_or_403(
    db: AsyncSession, booking_id: int, user: User
) -> Booking:
    booking = (
        await db.execute(select(Booking).where(Booking.id == booking_id))
    ).scalar_one_or_none()
    if booking is None:
        raise HTTPException(status_code=404, detail="الحجز غير موجود / Booking not found")
    if (
        booking.guest_id != user.id
        and booking.owner_id != user.id
        and user.role != UserRole.admin
    ):
        raise HTTPException(status_code=403, detail="ليس لديك صلاحية / Not authorized")
    return booking


# ── Contact reveal after booking is confirmed (Wave 23) ────────
class _BookingContactOut(BaseModel):
    """Contact information of the counter-party on a confirmed booking."""
    name: str
    phone: str | None = None
    role: str  # "owner" or "guest"

    model_config = {"from_attributes": True}


@router.get("/{booking_id}/contact", response_model=_BookingContactOut)
async def booking_contact(
    booking_id: int,
    user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db),
):
    """Return the counter-party's phone once the booking is confirmed.

    Before confirmation the chat is the only allowed communication
    channel, which is why numbers are sanitised there.  Once the owner
    (or the system, via a paid transaction) confirms the booking we
    reveal raw contact details so the two parties can finalise check-in
    logistics directly.
    """
    booking = await _load_booking_or_403(db, booking_id, user)
    if booking.status not in (
        BookingStatus.confirmed, BookingStatus.completed,
    ):
        raise HTTPException(
            status_code=409,
            detail=(
                "التواصل متاح بعد تأكيد الحجز فقط / "
                "Contact is shared only after booking is confirmed"
            ),
        )

    # Which side is the caller?  Reveal the *other* side.
    if user.id == booking.guest_id:
        other_id = booking.owner_id
        role = "owner"
    else:
        other_id = booking.guest_id
        role = "guest"

    other = await db.get(User, other_id)
    if other is None:
        raise HTTPException(status_code=404, detail="User not found")
    return _BookingContactOut(
        name=other.name,
        phone=other.phone if other.phone_verified else None,
        role=role,
    )


@router.get("/{booking_id}/cancel/preview", response_model=RefundQuoteOut)
async def cancel_preview(
    booking_id: int,
    user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db),
):
    """Return the refund quote the guest would get if they cancelled now.

    Used by the Flutter client to show a confirmation sheet with the
    exact amount and policy reasoning before actually cancelling.
    """
    booking = await _load_booking_or_403(db, booking_id, user)
    prop = await db.get(Property, booking.property_id)
    if prop is None:
        raise HTTPException(status_code=404, detail="Property not found")

    # If the booking was never paid, the refund is trivially zero.
    paid = booking.payment_status == PaymentStatus.paid
    quote = quote_refund(
        policy=prop.cancellation_policy,
        check_in=booking.check_in,
        total_price=booking.total_price if paid else 0.0,
    )
    return RefundQuoteOut(
        refundable_percent=quote.refundable_percent,
        refund_amount=quote.refund_amount,
        platform_fee_refunded=quote.platform_fee_refunded,
        reason_en=quote.reason_en,
        reason_ar=quote.reason_ar,
        cancellation_policy=prop.cancellation_policy.value,
    )


@router.put("/{booking_id}/cancel", response_model=BookingOut)
async def cancel_booking(
    booking_id: int,
    body: BookingCancelRequest | None = None,
    user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db),
):
    booking = await _load_booking_or_403(db, booking_id, user)
    if booking.status in (BookingStatus.cancelled, BookingStatus.completed):
        raise HTTPException(status_code=400, detail="لا يمكن إلغاء هذا الحجز / Cannot cancel")

    prop = await db.get(Property, booking.property_id)
    policy = prop.cancellation_policy if prop else None

    now = datetime.now(timezone.utc)
    booking.status = BookingStatus.cancelled
    booking.cancelled_at = now
    if body and body.reason:
        booking.cancellation_reason = body.reason.strip()[:500]

    # ── Auto-refund the latest successful payment, if any ────────
    refund_failed: str | None = None
    if booking.payment_status == PaymentStatus.paid and policy is not None:
        quote = quote_refund(
            policy=policy,
            check_in=booking.check_in,
            total_price=booking.total_price,
            now=now,
        )
        booking.refund_amount = quote.refund_amount

        if quote.refund_amount > 0:
            # Latest paid payment for the booking.
            payment = (
                await db.execute(
                    select(Payment)
                    .where(Payment.booking_id == booking.id)
                    .where(Payment.state == PaymentState.paid)
                    .order_by(Payment.paid_at.desc())
                    .limit(1)
                )
            ).scalar_one_or_none()

            if payment is not None and payment.provider_ref:
                gateway = get_gateway(payment.provider)
                try:
                    await gateway.refund(
                        payment.provider_ref, quote.refund_amount
                    )
                    # Flip payment row + booking mirror.
                    if quote.refundable_percent == 100:
                        payment.state = PaymentState.refunded
                        booking.payment_status = PaymentStatus.refunded
                    else:
                        payment.state = PaymentState.partially_refunded
                        booking.payment_status = PaymentStatus.partially_refunded
                    logger.info(
                        "booking_refund_issued",
                        booking_id=booking.id,
                        amount=quote.refund_amount,
                        percent=quote.refundable_percent,
                    )
                except GatewayError as exc:
                    # Cancellation still proceeds so the guest isn't
                    # locked in, but we flag the refund for admin
                    # reconciliation via the logs + a note.
                    refund_failed = str(exc)[:500]
                    logger.warning(
                        "booking_refund_failed",
                        booking_id=booking.id,
                        provider=payment.provider.value,
                        error=refund_failed,
                    )

    await db.flush()
    await db.refresh(booking)

    # ── Notify both parties ──────────────────────────────────
    notify_user = (
        booking.owner_id if user.id == booking.guest_id else booking.guest_id
    )
    note_body = f"حجز {booking.booking_code} تم إلغاؤه"
    if booking.refund_amount and booking.refund_amount > 0:
        note_body += f" — سيتم استرداد {booking.refund_amount:.0f} ج.م"
    await create_notification(
        db, notify_user,
        title="تم إلغاء الحجز",
        body=note_body,
        notif_type=NotificationType.booking_cancelled,
    )
    if refund_failed:
        # Also alert the guest so they know to contact support.
        await create_notification(
            db, booking.guest_id,
            title="مشكلة في استرداد المبلغ",
            body="يرجى التواصل مع الدعم لإكمال عملية الاسترداد.",
            notif_type=NotificationType.booking_cancelled,
        )

    return BookingOut.model_validate(booking)


# ── Hybrid cash-on-arrival workflow (Wave 25) ─────────────────
#
# When the property's host opted into ``cash_on_arrival_enabled``,
# the booking is paid in two legs:
#   1. ``deposit_amount`` was charged online via the gateway.
#   2. ``remaining_cash_amount`` is settled in cash on arrival.
#
# Releasing the host's online payout requires *both* parties to
# acknowledge the cash collection — the host marks "received" and the
# guest marks "paid & arrived".  This avoids the two pathological
# cases:
#   • Host claims they never got the cash to keep the deposit AND
#     re-bill the guest.
#   • Guest claims they paid cash when they actually didn't, leaving
#     the host out-of-pocket while the platform releases funds.
#
# A scheduled job (Phase 3) flips one-sided confirmations to
# ``disputed`` after 48 h so admin can step in.


def _release_payout_if_both_confirmed(booking: Booking) -> None:
    """Bump ``cash_collection_status`` to ``confirmed`` when both
    sides have signed off, and unblock the host's payout pipeline.

    No-op if either confirmation is still missing or the booking
    isn't a cash-on-arrival one in the first place.
    """

    if (
        booking.owner_cash_confirmed_at is not None
        and booking.guest_arrival_confirmed_at is not None
        and booking.cash_collection_status != CashCollectionStatus.confirmed
    ):
        booking.cash_collection_status = CashCollectionStatus.confirmed
        # Mark the booking as completed so it enters the next payout
        # batch — the host has fulfilled their side of the deal.
        if booking.status == BookingStatus.confirmed:
            booking.status = BookingStatus.completed


@router.post("/{booking_id}/confirm-cash-received", response_model=BookingOut)
async def confirm_cash_received(
    booking_id: int,
    user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db),
):
    """Host confirms they received the cash leg from the guest.

    Only the host (or an admin) may call this.  Pairs with
    ``confirm_arrival`` so the platform never releases the online
    payout on a single, unilateral claim.
    """

    booking = await _load_booking_or_403(db, booking_id, user)
    if booking.owner_id != user.id and user.role != UserRole.admin:
        raise HTTPException(
            status_code=403,
            detail="هذا الإجراء للمضيف فقط / Host-only action",
        )
    if booking.cash_collection_status == CashCollectionStatus.not_applicable:
        raise HTTPException(
            status_code=400,
            detail=(
                "الحجز مدفوع بالكامل أونلاين / "
                "Booking was fully prepaid online"
            ),
        )
    if booking.cash_collection_status in (
        CashCollectionStatus.confirmed,
        CashCollectionStatus.no_show,
    ):
        raise HTTPException(
            status_code=409,
            detail="الحجز محسوم بالفعل / Already settled",
        )
    if booking.payment_status != PaymentStatus.paid:
        raise HTTPException(
            status_code=400,
            detail="العربون لم يُدفع بعد / Deposit not paid yet",
        )
    today = date.today()
    if booking.check_in > today:
        raise HTTPException(
            status_code=400,
            detail=(
                "لا يمكن التأكيد قبل تاريخ الوصول / "
                "Cannot confirm before check-in date"
            ),
        )

    booking.owner_cash_confirmed_at = datetime.now(timezone.utc)
    if booking.cash_collection_status == CashCollectionStatus.pending:
        booking.cash_collection_status = CashCollectionStatus.owner_confirmed
    _release_payout_if_both_confirmed(booking)
    await db.flush()
    await db.refresh(booking)

    await create_notification(
        db,
        booking.guest_id,
        title="المضيف أكد استلام المبلغ",
        body=f"يرجى تأكيد وصولك ودفعك للمبلغ النقدى لحجز {booking.booking_code}.",
        notif_type=NotificationType.booking_confirmed,
    )
    logger.info(
        "cash_owner_confirmed",
        booking_id=booking.id,
        status=booking.cash_collection_status.value,
    )
    return BookingOut.model_validate(booking)


@router.post("/{booking_id}/confirm-arrival", response_model=BookingOut)
async def confirm_arrival(
    booking_id: int,
    user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db),
):
    """Guest confirms they arrived and handed over the cash leg.

    Mirror endpoint of ``confirm_cash_received`` — guest-only.
    """

    booking = await _load_booking_or_403(db, booking_id, user)
    if booking.guest_id != user.id and user.role != UserRole.admin:
        raise HTTPException(
            status_code=403,
            detail="هذا الإجراء للضيف فقط / Guest-only action",
        )
    if booking.cash_collection_status == CashCollectionStatus.not_applicable:
        raise HTTPException(
            status_code=400,
            detail=(
                "الحجز مدفوع بالكامل أونلاين / "
                "Booking was fully prepaid online"
            ),
        )
    if booking.cash_collection_status in (
        CashCollectionStatus.confirmed,
        CashCollectionStatus.no_show,
    ):
        raise HTTPException(
            status_code=409,
            detail="الحجز محسوم بالفعل / Already settled",
        )
    if booking.payment_status != PaymentStatus.paid:
        raise HTTPException(
            status_code=400,
            detail="العربون لم يُدفع بعد / Deposit not paid yet",
        )
    today = date.today()
    if booking.check_in > today:
        raise HTTPException(
            status_code=400,
            detail=(
                "لا يمكن التأكيد قبل تاريخ الوصول / "
                "Cannot confirm before check-in date"
            ),
        )

    booking.guest_arrival_confirmed_at = datetime.now(timezone.utc)
    if booking.cash_collection_status == CashCollectionStatus.pending:
        booking.cash_collection_status = CashCollectionStatus.guest_confirmed
    _release_payout_if_both_confirmed(booking)
    await db.flush()
    await db.refresh(booking)

    await create_notification(
        db,
        booking.owner_id,
        title="الضيف أكد الوصول",
        body=f"يرجى تأكيد استلامك للمبلغ النقدى لحجز {booking.booking_code}.",
        notif_type=NotificationType.booking_confirmed,
    )
    logger.info(
        "cash_guest_confirmed",
        booking_id=booking.id,
        status=booking.cash_collection_status.value,
    )
    return BookingOut.model_validate(booking)


@router.post("/{booking_id}/report-no-show", response_model=BookingOut)
async def report_no_show(
    booking_id: int,
    user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db),
):
    """Host marks the guest as a no-show after the check-in date.

    The host keeps the deposit minus a single night's commission —
    the platform doesn't double-dip on a stay that never happened.
    Cannot be filed once the guest has already confirmed arrival.
    """

    booking = await _load_booking_or_403(db, booking_id, user)
    if booking.owner_id != user.id and user.role != UserRole.admin:
        raise HTTPException(
            status_code=403,
            detail="هذا الإجراء للمضيف فقط / Host-only action",
        )
    if booking.cash_collection_status == CashCollectionStatus.not_applicable:
        raise HTTPException(
            status_code=400,
            detail=(
                "الحجز مدفوع بالكامل أونلاين — استخدم سياسة الإلغاء / "
                "Online-only booking — use the cancellation policy"
            ),
        )
    if booking.cash_collection_status in (
        CashCollectionStatus.confirmed,
        CashCollectionStatus.guest_confirmed,
        CashCollectionStatus.no_show,
    ):
        raise HTTPException(
            status_code=409,
            detail=(
                "لا يمكن الإبلاغ بعد تأكيد الضيف / "
                "Cannot report no-show after the guest confirmed"
            ),
        )
    today = date.today()
    if booking.check_in > today:
        raise HTTPException(
            status_code=400,
            detail=(
                "لا يمكن الإبلاغ قبل تاريخ الوصول / "
                "Cannot report before the check-in date"
            ),
        )

    # Recompute the no-show split using the property's nightly rate
    # so the math always matches the breakdown the guest saw at
    # checkout, even if the property's price changed afterwards.
    prop = await db.get(Property, booking.property_id)
    one_night_commission = round(
        (prop.price_per_night if prop else booking.deposit_amount)
        * (settings.PLATFORM_FEE_PERCENT / 100.0),
        2,
    )
    # Cap the commission at the deposit so we never produce a
    # negative payout for low-priced single-night stays.
    one_night_commission = min(one_night_commission, booking.deposit_amount)

    booking.platform_fee = one_night_commission
    booking.owner_payout = round(booking.deposit_amount - one_night_commission, 2)
    booking.cash_collection_status = CashCollectionStatus.no_show
    booking.no_show_reported_at = datetime.now(timezone.utc)
    booking.status = BookingStatus.completed
    await db.flush()
    await db.refresh(booking)

    await create_notification(
        db,
        booking.guest_id,
        title="تم الإبلاغ عن عدم الوصول",
        body=(
            f"المضيف أبلغ أنك لم تصل لحجز {booking.booking_code}. "
            "تواصل مع الدعم فى حال وجود اعتراض."
        ),
        notif_type=NotificationType.booking_cancelled,
    )
    logger.info(
        "cash_no_show_reported",
        booking_id=booking.id,
        owner_payout=booking.owner_payout,
        platform_fee=booking.platform_fee,
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
