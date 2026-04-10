"""Payments router – Fawry initiate, webhook, status check."""

from __future__ import annotations

import structlog
from fastapi import APIRouter, Depends, HTTPException, Request, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.middleware.auth_middleware import get_current_active_user
from app.models.booking import Booking, PaymentStatus
from app.models.notification import NotificationType
from app.models.user import User
from app.schemas.common import MessageResponse
from app.services.notification_service import create_notification
from app.services.payment_service import (
    check_payment_status,
    initiate_payment,
    verify_webhook_signature,
)

logger = structlog.get_logger(__name__)
router = APIRouter(prefix="/payments", tags=["Payments"])


@router.post("/initiate")
async def initiate(
    booking_id: int,
    user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db),
):
    """Initiate a Fawry payment for a booking."""
    result = await db.execute(select(Booking).where(Booking.id == booking_id))
    booking = result.scalar_one_or_none()
    if booking is None:
        raise HTTPException(status_code=404, detail="الحجز غير موجود / Booking not found")
    if booking.guest_id != user.id:
        raise HTTPException(status_code=403, detail="ليس حجزك / Not your booking")
    if booking.payment_status == PaymentStatus.paid:
        raise HTTPException(status_code=400, detail="تم الدفع مسبقاً / Already paid")

    merchant_ref = f"YT-{booking.booking_code}"

    data = await initiate_payment(
        merchant_ref=merchant_ref,
        amount=booking.total_price,
        customer_email=user.email or "",
        customer_phone=user.phone or "",
        description=f"Yalla Trip Booking #{booking.booking_code}",
    )

    if data.get("statusCode") == 200:
        booking.fawry_ref = data.get("referenceNumber")
        await db.flush()
        return {
            "status": "success",
            "fawry_ref": booking.fawry_ref,
            "merchant_ref": merchant_ref,
            "data": data,
        }

    raise HTTPException(
        status_code=status.HTTP_502_BAD_GATEWAY,
        detail=f"خطأ في بوابة الدفع / Payment gateway error: {data.get('statusDescription', '')}",
    )


@router.post("/webhook", response_model=MessageResponse)
async def fawry_webhook(
    request: Request,
    db: AsyncSession = Depends(get_db),
):
    """Handle Fawry payment callback."""
    payload = await request.json()
    logger.info("fawry_webhook_received", payload=payload)

    if not verify_webhook_signature(payload):
        logger.warning("fawry_webhook_invalid_signature")
        raise HTTPException(status_code=400, detail="Invalid signature")

    merchant_ref = payload.get("merchantRefNum", "")
    order_status = payload.get("orderStatus", "")

    # extract booking code from merchant ref "YT-ABCD1234"
    code = merchant_ref.replace("YT-", "")
    result = await db.execute(select(Booking).where(Booking.booking_code == code))
    booking = result.scalar_one_or_none()

    if booking is None:
        logger.warning("fawry_webhook_booking_not_found", ref=merchant_ref)
        return MessageResponse(message="Booking not found", message_ar="الحجز غير موجود")

    if order_status == "PAID":
        booking.payment_status = PaymentStatus.paid
        booking.fawry_ref = payload.get("fawryRefNumber", booking.fawry_ref)
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
    elif order_status == "REFUNDED":
        booking.payment_status = PaymentStatus.refunded

    await db.flush()
    logger.info("fawry_webhook_processed", code=code, status=order_status)
    return MessageResponse(message="Webhook processed", message_ar="تم معالجة الإشعار")


@router.get("/status/{booking_id}")
async def payment_status(
    booking_id: int,
    user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db),
):
    """Check payment status for a booking."""
    result = await db.execute(select(Booking).where(Booking.id == booking_id))
    booking = result.scalar_one_or_none()
    if booking is None:
        raise HTTPException(status_code=404, detail="الحجز غير موجود / Booking not found")
    if booking.guest_id != user.id and booking.owner_id != user.id:
        raise HTTPException(status_code=403, detail="ليس لديك صلاحية / Not authorized")

    # if we have a fawry ref, check live status
    if booking.fawry_ref:
        merchant_ref = f"YT-{booking.booking_code}"
        data = await check_payment_status(merchant_ref)
        return {
            "booking_id": booking.id,
            "payment_status": booking.payment_status.value,
            "fawry_ref": booking.fawry_ref,
            "fawry_status": data.get("paymentStatus"),
        }

    return {
        "booking_id": booking.id,
        "payment_status": booking.payment_status.value,
        "fawry_ref": None,
    }
