"""Payments router – checkout + per-gateway webhooks.

Endpoints
---------
POST   /payments/initiate           → start a payment (returns checkout URL / ref)
GET    /payments/my                 → list my payments
GET    /payments/{id}               → single payment status
POST   /payments/webhook/fawry      → Fawry → backend callback
POST   /payments/webhook/paymob     → Paymob → backend callback
"""

from __future__ import annotations

from datetime import datetime, timezone

import structlog
from fastapi import APIRouter, Depends, HTTPException, Request, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.middleware.auth_middleware import get_current_active_user
from app.models.booking import Booking, BookingStatus, PaymentStatus
from app.models.notification import NotificationType
from app.models.payment import (
    Payment,
    PaymentProvider,
    PaymentState,
)
from app.models.user import User
from app.schemas.common import MessageResponse
from app.schemas.payment import (
    PaymentInitiateRequest,
    PaymentInitiateResponse,
    PaymentOut,
)
from app.services.gateways import GatewayError, get_gateway
from app.services.notification_service import create_notification
from app.services.wallet_service import reward_referrer_for_booking

logger = structlog.get_logger(__name__)
router = APIRouter(prefix="/payments", tags=["Payments"])


# ── helpers ──────────────────────────────────────────────────
async def _find_booking(
    db: AsyncSession, booking_id: int, user: User
) -> Booking:
    booking = (
        await db.execute(select(Booking).where(Booking.id == booking_id))
    ).scalar_one_or_none()
    if booking is None:
        raise HTTPException(status_code=404, detail="Booking not found")
    if booking.guest_id != user.id:
        raise HTTPException(status_code=403, detail="Not your booking")
    return booking


async def _apply_state(
    db: AsyncSession, payment: Payment, booking: Booking, state: PaymentState
) -> None:
    """Move a ``Payment`` into ``state`` and mirror to the booking."""
    if payment.state == state:
        return
    payment.state = state

    if state == PaymentState.paid:
        payment.paid_at = datetime.now(timezone.utc)
        booking.payment_status = PaymentStatus.paid
        booking.status = BookingStatus.confirmed
        await create_notification(
            db, booking.guest_id,
            title="تم الدفع بنجاح",
            body=f"تم تأكيد دفع حجز {booking.booking_code}",
            notif_type=NotificationType.payment_received,
        )
        await create_notification(
            db, booking.owner_id,
            title="دفعة جديدة",
            body=f"تم استلام دفعة لحجز {booking.booking_code}",
            notif_type=NotificationType.payment_received,
        )
        # Pay out the referral reward once the invitee's first booking
        # is confirmed + paid.  Silent no-op for users without a
        # referrer or already-rewarded referrals.
        try:
            await reward_referrer_for_booking(db, booking)
        except Exception as exc:  # pragma: no cover
            logger.error("referral_reward_failed", err=str(exc))
    elif state == PaymentState.refunded:
        booking.payment_status = PaymentStatus.refunded
    elif state == PaymentState.failed:
        # Booking itself stays pending so the guest can retry.
        booking.payment_status = PaymentStatus.pending


# ── initiate ────────────────────────────────────────────────
@router.post(
    "/initiate",
    response_model=PaymentInitiateResponse,
    status_code=status.HTTP_201_CREATED,
)
async def initiate_payment(
    body: PaymentInitiateRequest,
    user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db),
):
    booking = await _find_booking(db, body.booking_id, user)
    if booking.payment_status == PaymentStatus.paid:
        raise HTTPException(status_code=400, detail="Already paid")

    gateway = get_gateway(body.provider)
    if body.method not in gateway.supported_methods:
        raise HTTPException(
            status_code=400,
            detail=(
                f"Gateway {body.provider.value} does not support "
                f"method {body.method.value}"
            ),
        )

    merchant_ref = f"YT-{booking.booking_code}-{int(datetime.now().timestamp())}"
    payment = Payment(
        booking_id=booking.id,
        user_id=user.id,
        provider=body.provider,
        method=body.method,
        state=PaymentState.pending,
        amount=booking.total_price,
        currency="EGP",
        merchant_ref=merchant_ref,
    )
    db.add(payment)
    await db.flush()

    try:
        result = await gateway.initiate(
            merchant_ref=merchant_ref,
            amount=booking.total_price,
            method=body.method,
            customer_email=user.email or "",
            customer_phone=user.phone or "",
            customer_name=user.name or "Customer",
            description=f"Talaa Booking #{booking.booking_code}",
        )
    except GatewayError as exc:
        payment.state = PaymentState.failed
        payment.error_message = str(exc)[:1024]
        payment.response_payload = exc.raw if isinstance(exc.raw, dict) else None
        await db.flush()
        logger.warning(
            "payment_initiate_failed",
            provider=body.provider.value,
            ref=merchant_ref,
            error=str(exc),
        )
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=f"Payment gateway error: {exc}",
        )

    payment.provider_ref = result.provider_ref
    payment.checkout_url = result.checkout_url
    payment.response_payload = result.raw
    payment.state = (
        PaymentState.pending
        if body.provider != PaymentProvider.cod
        else PaymentState.pending
    )
    # COD is immediately "accepted" (no external payment needed) –
    # but we keep state = pending until the host marks the booking
    # as completed at check-in.
    await db.flush()

    logger.info(
        "payment_initiated",
        payment_id=payment.id,
        provider=body.provider.value,
        amount=payment.amount,
        ref=merchant_ref,
    )
    return PaymentInitiateResponse(
        payment_id=payment.id,
        provider=payment.provider,
        method=payment.method,
        state=payment.state,
        amount=payment.amount,
        currency=payment.currency,
        merchant_ref=payment.merchant_ref,
        provider_ref=payment.provider_ref,
        checkout_url=payment.checkout_url,
        extra=result.extra,
    )


# ── my payments ─────────────────────────────────────────────
@router.get("/my", response_model=list[PaymentOut])
async def my_payments(
    user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db),
):
    rows = (
        await db.execute(
            select(Payment)
            .where(Payment.user_id == user.id)
            .order_by(Payment.created_at.desc())
        )
    ).scalars().all()
    return [PaymentOut.model_validate(p) for p in rows]


# ── single payment ──────────────────────────────────────────
@router.get("/{payment_id}", response_model=PaymentOut)
async def get_payment(
    payment_id: int,
    user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db),
):
    payment = await db.get(Payment, payment_id)
    if payment is None or payment.user_id != user.id:
        raise HTTPException(status_code=404, detail="Payment not found")
    return PaymentOut.model_validate(payment)


# ── webhooks (no auth — gateway signed) ─────────────────────
async def _handle_webhook(
    provider: PaymentProvider, request: Request, db: AsyncSession
) -> MessageResponse:
    payload = await request.json()
    gateway = get_gateway(provider)

    if not gateway.verify_webhook(payload):
        logger.warning("payment_webhook_invalid_signature", provider=provider.value)
        raise HTTPException(status_code=400, detail="Invalid signature")

    parsed = gateway.parse_webhook(payload)
    logger.info(
        "payment_webhook_received",
        provider=provider.value,
        ref=parsed.merchant_ref,
        state=parsed.state.value,
    )

    payment = (
        await db.execute(
            select(Payment).where(Payment.merchant_ref == parsed.merchant_ref)
        )
    ).scalar_one_or_none()
    if payment is None:
        logger.warning(
            "payment_webhook_unknown_ref",
            provider=provider.value,
            ref=parsed.merchant_ref,
        )
        return MessageResponse(message="OK", message_ar="تم")

    booking = await db.get(Booking, payment.booking_id)
    if booking is None:
        return MessageResponse(message="OK", message_ar="تم")

    if parsed.provider_ref and not payment.provider_ref:
        payment.provider_ref = parsed.provider_ref
    payment.response_payload = parsed.raw

    await _apply_state(db, payment, booking, parsed.state)
    await db.flush()
    return MessageResponse(message="OK", message_ar="تم")


@router.post("/webhook/fawry", response_model=MessageResponse)
async def fawry_webhook(request: Request, db: AsyncSession = Depends(get_db)):
    return await _handle_webhook(PaymentProvider.fawry, request, db)


@router.post("/webhook/paymob", response_model=MessageResponse)
async def paymob_webhook(request: Request, db: AsyncSession = Depends(get_db)):
    return await _handle_webhook(PaymentProvider.paymob, request, db)
