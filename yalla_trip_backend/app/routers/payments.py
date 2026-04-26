"""Payments router – checkout + per-gateway webhooks.

Endpoints
---------
POST   /payments/initiate                        → start a payment (returns checkout URL / ref)
GET    /payments/my                              → list my payments
GET    /payments/{id}                            → single payment status
POST   /payments/webhook/fawry                   → Fawry → backend callback
POST   /payments/webhook/paymob                  → Paymob → backend callback
GET    /payments/mock-checkout/{merchant_ref}    → hosted mock checkout page (PAYMENTS_MOCK_MODE)
POST   /payments/mock-checkout/{merchant_ref}/complete
                                                 → mock callback button (success/failure/cancel)
"""

from __future__ import annotations

from datetime import datetime, timezone

import structlog
from fastapi import APIRouter, Depends, HTTPException, Request, status
from fastapi.responses import HTMLResponse, RedirectResponse
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import get_settings
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
    # Wave 25 — for hybrid bookings the gateway only charges the
    # online deposit; the rest is collected as cash on arrival.  For
    # legacy 100 %-online bookings ``deposit_amount`` equals
    # ``total_price`` so this branch is a no-op.
    online_amount = booking.deposit_amount or booking.total_price
    payment = Payment(
        booking_id=booking.id,
        user_id=user.id,
        provider=body.provider,
        method=body.method,
        state=PaymentState.pending,
        amount=online_amount,
        currency="EGP",
        merchant_ref=merchant_ref,
        # Persist the client's hint blob so Mock/Kashier/etc. can read
        # ``wallet_type`` later, and so support staff have a forensic
        # trail of "what did the app actually send?".
        request_payload=dict(body.extra) if body.extra else None,
    )
    db.add(payment)
    await db.flush()

    try:
        result = await gateway.initiate(
            merchant_ref=merchant_ref,
            amount=online_amount,
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
# Terminal states must never roll back.  Once a payment is recorded as
# paid / refunded / failed, a later webhook claiming a different
# outcome is treated as a replay or out-of-order delivery and ignored.
_TERMINAL_STATES: frozenset[PaymentState] = frozenset({
    PaymentState.paid,
    PaymentState.refunded,
    PaymentState.partially_refunded,
    PaymentState.expired,
    PaymentState.cancelled,
})


def _amount_matches(declared: float, expected: float) -> bool:
    """Floats compared at one-cent tolerance.  Gateways occasionally
    round trip-through cents and back, so an exact equality test is
    too brittle; one paisa of slack is plenty."""
    return abs(declared - expected) < 0.01


async def _handle_webhook(
    provider: PaymentProvider, request: Request, db: AsyncSession
) -> MessageResponse:
    # ── 1. Parse + verify signature ─────────────────────────────
    # We always read the raw payload first so signature failures can
    # still log the merchant ref for forensics — useful when a real
    # provider rotates an HMAC secret and we briefly start rejecting
    # legitimate webhooks.
    try:
        payload = await request.json()
    except Exception:
        logger.warning("payment_webhook_unparseable", provider=provider.value)
        raise HTTPException(status_code=400, detail="Malformed JSON")

    gateway = get_gateway(provider)
    if not gateway.verify_webhook(payload):
        logger.warning(
            "payment_webhook_invalid_signature",
            provider=provider.value,
            payload_keys=list(payload.keys()) if isinstance(payload, dict) else None,
        )
        raise HTTPException(status_code=400, detail="Invalid signature")

    parsed = gateway.parse_webhook(payload)
    logger.info(
        "payment_webhook_received",
        provider=provider.value,
        ref=parsed.merchant_ref,
        provider_ref=parsed.provider_ref,
        state=parsed.state.value,
        amount=parsed.amount,
    )

    if not parsed.merchant_ref:
        # Some gateways send keep-alive / handshake calls with no
        # business payload — accept them so the gateway doesn't keep
        # retrying, but don't touch any rows.
        return MessageResponse(message="OK", message_ar="تم")

    # ── 2. Lock the payment row ─────────────────────────────────
    # ``with_for_update`` serialises duplicate webhook deliveries —
    # gateways routinely retry until they get a 2xx, and on busy
    # nights the second attempt can land before the first has
    # committed.  Without the row lock we would double-credit
    # ``owner_payout`` and double-fire the referral reward.
    payment = (
        await db.execute(
            select(Payment)
            .where(Payment.merchant_ref == parsed.merchant_ref)
            .with_for_update()
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
        logger.error(
            "payment_webhook_orphan_booking",
            ref=parsed.merchant_ref,
            booking_id=payment.booking_id,
        )
        return MessageResponse(message="OK", message_ar="تم")

    # ── 3. Idempotency / terminal-state guard ───────────────────
    # If the payment already settled, refuse to mutate it — but still
    # ack the webhook with 200 so the gateway stops retrying.
    if payment.state in _TERMINAL_STATES and payment.state != parsed.state:
        logger.info(
            "payment_webhook_terminal_replay",
            ref=parsed.merchant_ref,
            current=payment.state.value,
            incoming=parsed.state.value,
        )
        return MessageResponse(message="OK", message_ar="تم")

    if payment.state == parsed.state:
        # Same state → record the latest payload for audit but skip
        # all the side-effects (notifications, referral reward, etc.).
        payment.response_payload = parsed.raw
        await db.flush()
        return MessageResponse(message="OK", message_ar="تم")

    # ── 4. Anti-tampering: amount must match what we stored ─────
    # When a webhook claims the payment succeeded we cross-check the
    # captured amount against the price we computed server-side at
    # ``initiate``.  A forged or replayed webhook with a smaller
    # amount would otherwise mark the booking as paid for cents.
    if parsed.state == PaymentState.paid and parsed.amount is not None:
        if not _amount_matches(parsed.amount, payment.amount):
            logger.error(
                "payment_webhook_amount_mismatch",
                ref=parsed.merchant_ref,
                declared=parsed.amount,
                expected=payment.amount,
            )
            payment.error_message = (
                f"Amount mismatch: webhook said {parsed.amount} "
                f"but invoice was {payment.amount}"
            )
            payment.response_payload = parsed.raw
            await db.flush()
            # Refuse to mark as paid — the gateway side will keep
            # retrying or operations will reconcile manually.
            raise HTTPException(status_code=400, detail="Amount mismatch")

    # ── 5. Apply the new state ──────────────────────────────────
    if parsed.provider_ref and not payment.provider_ref:
        payment.provider_ref = parsed.provider_ref
    payment.response_payload = parsed.raw

    await _apply_state(db, payment, booking, parsed.state)
    await db.flush()
    logger.info(
        "payment_webhook_applied",
        ref=parsed.merchant_ref,
        new_state=parsed.state.value,
    )
    return MessageResponse(message="OK", message_ar="تم")


@router.post("/webhook/fawry", response_model=MessageResponse)
async def fawry_webhook(request: Request, db: AsyncSession = Depends(get_db)):
    return await _handle_webhook(PaymentProvider.fawry, request, db)


@router.post("/webhook/paymob", response_model=MessageResponse)
async def paymob_webhook(request: Request, db: AsyncSession = Depends(get_db)):
    return await _handle_webhook(PaymentProvider.paymob, request, db)


# ── mock checkout (PAYMENTS_MOCK_MODE only) ─────────────────
# These two endpoints are the in-house "iframe" served by our backend
# when no real gateway contract exists yet.  ``MockGateway.initiate``
# returns the GET URL below as the ``checkout_url`` and the Flutter
# WebView loads it like a normal payment page.  The user picks
# Success / Failure / Cancel; the button POSTs back here, we mutate
# the matching ``Payment`` row, and 302-redirect to a URL the
# WebView's success/fail matchers are watching for.
def _ensure_mock_mode() -> None:
    if not get_settings().PAYMENTS_MOCK_MODE:
        raise HTTPException(
            status_code=404, detail="Mock checkout is disabled"
        )


_MOCK_CHECKOUT_HTML = """<!doctype html>
<html lang="ar" dir="rtl">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Talaa — صفحة دفع تجريبية</title>
<style>
  * {{ box-sizing: border-box; }}
  body {{
    margin: 0;
    font-family: -apple-system, "Segoe UI", Roboto, "Cairo", sans-serif;
    background: linear-gradient(180deg, #FFF8F1 0%, #FFFFFF 60%);
    color: #1F2937;
    min-height: 100vh;
    display: flex;
    align-items: center;
    justify-content: center;
    padding: 24px;
  }}
  .card {{
    width: 100%;
    max-width: 420px;
    background: white;
    border-radius: 24px;
    padding: 28px 24px;
    box-shadow: 0 12px 40px rgba(0,0,0,0.08);
    border: 1px solid #F3E5C9;
  }}
  .pill {{
    display: inline-block;
    background: #FFF3E0;
    color: #B45309;
    font-size: 11px;
    font-weight: 800;
    padding: 4px 10px;
    border-radius: 999px;
    letter-spacing: 0.5px;
  }}
  h1 {{
    margin: 14px 0 4px;
    font-size: 22px;
    font-weight: 900;
  }}
  .muted {{
    margin: 0;
    color: #6B7280;
    font-size: 13px;
    line-height: 1.6;
  }}
  .summary {{
    margin: 20px 0 18px;
    padding: 16px;
    background: #FAFAFA;
    border-radius: 14px;
    border: 1px solid #E5E7EB;
  }}
  .row {{
    display: flex;
    justify-content: space-between;
    margin: 6px 0;
    font-size: 13px;
  }}
  .row .k {{ color: #6B7280; }}
  .row .v {{ font-weight: 700; }}
  .total {{
    margin-top: 10px;
    padding-top: 10px;
    border-top: 1px dashed #E5E7EB;
    font-size: 18px;
    font-weight: 900;
    color: #FF6D00;
  }}
  .btn {{
    display: block;
    width: 100%;
    border: 0;
    padding: 14px;
    font-size: 15px;
    font-weight: 800;
    border-radius: 14px;
    margin: 8px 0;
    cursor: pointer;
    transition: transform 0.1s ease;
  }}
  .btn:active {{ transform: scale(0.98); }}
  .btn-success {{ background: #16A34A; color: white; }}
  .btn-fail {{ background: #DC2626; color: white; }}
  .btn-cancel {{ background: #F3F4F6; color: #1F2937; }}
  .small {{
    text-align: center;
    color: #9CA3AF;
    font-size: 11px;
    margin-top: 14px;
  }}
</style>
</head>
<body>
  <div class="card">
    <span class="pill">🧪 وضع تجريبى — لا يتم تحصيل أى فلوس فعلية</span>
    <h1>صفحة دفع تجريبية</h1>
    <p class="muted">دى صفحة محاكاة لبوابة الدفع — اختر النتيجة اللى عايز تختبرها.</p>

    <div class="summary">
      <div class="row"><span class="k">رقم الحجز</span><span class="v">{merchant_ref}</span></div>
      <div class="row"><span class="k">طريقة الدفع</span><span class="v">{method}</span></div>
      <div class="row total"><span class="k">الإجمالى</span><span class="v">{amount:.0f} EGP</span></div>
    </div>

    <form method="POST" action="{action}">
      <button class="btn btn-success" name="outcome" value="success">✅ نجاح الدفع</button>
      <button class="btn btn-fail" name="outcome" value="failure">❌ فشل الدفع</button>
      <button class="btn btn-cancel" name="outcome" value="cancel">↩️ إلغاء</button>
    </form>

    <p class="small">Talaa Mock Gateway · مش هيتم استبداله بـ Paymob/Kashier إلا بعد التعاقد.</p>
  </div>
</body>
</html>"""


# Friendly Arabic labels for the method/wallet shown on the mock page,
# so the tester sees "فودافون كاش" instead of the raw enum "wallet".
_METHOD_LABELS_AR: dict[str, str] = {
    "card": "بطاقة بنكية (فيزا / ماستر / ميزة)",
    "wallet": "محفظة إلكترونية",
    "fawry_voucher": "إيصال فورى",
    "instapay": "إنستاباى",
    "cod": "الدفع نقداً",
}
_WALLET_LABELS_AR: dict[str, str] = {
    "vodafone_cash": "فودافون كاش",
    "orange_cash": "اورنچ كاش",
    "etisalat_cash": "e& money (اتصالات)",
    "we_pay": "WE Pay",
}


def _method_label_ar(payment: Payment) -> str:
    """Resolve the prettiest possible label for the payment row."""
    extra = payment.request_payload or {}
    wallet_type = extra.get("wallet_type") if isinstance(extra, dict) else None
    if wallet_type and wallet_type in _WALLET_LABELS_AR:
        return _WALLET_LABELS_AR[wallet_type]
    return _METHOD_LABELS_AR.get(payment.method.value, payment.method.value)


@router.get("/mock-checkout/{merchant_ref}", response_class=HTMLResponse)
async def mock_checkout_page(
    merchant_ref: str, db: AsyncSession = Depends(get_db)
):
    _ensure_mock_mode()
    payment = (
        await db.execute(
            select(Payment).where(Payment.merchant_ref == merchant_ref)
        )
    ).scalar_one_or_none()
    if payment is None:
        raise HTTPException(status_code=404, detail="Unknown merchant_ref")

    return HTMLResponse(
        _MOCK_CHECKOUT_HTML.format(
            merchant_ref=merchant_ref,
            method=_method_label_ar(payment),
            amount=payment.amount,
            action=f"/payments/mock-checkout/{merchant_ref}/complete",
        )
    )


@router.post("/mock-checkout/{merchant_ref}/complete")
async def mock_checkout_complete(
    merchant_ref: str,
    request: Request,
    db: AsyncSession = Depends(get_db),
):
    _ensure_mock_mode()
    form = await request.form()
    raw_outcome = form.get("outcome")
    # form fields may be either ``str`` (regular field) or ``UploadFile``
    # (multipart binary).  We only ever submit a plain string here, so
    # coerce defensively.
    outcome = (
        raw_outcome.lower() if isinstance(raw_outcome, str) else ""
    )

    payment = (
        await db.execute(
            select(Payment).where(Payment.merchant_ref == merchant_ref)
        )
    ).scalar_one_or_none()
    if payment is None:
        raise HTTPException(status_code=404, detail="Unknown merchant_ref")

    booking = await db.get(Booking, payment.booking_id)
    if booking is None:
        raise HTTPException(status_code=404, detail="Booking missing")

    if outcome == "success":
        await _apply_state(db, payment, booking, PaymentState.paid)
        redirect = f"/payments/mock-checkout/{merchant_ref}/done?mock-success=1"
    elif outcome == "failure":
        payment.error_message = "Mock gateway: failure outcome"
        await _apply_state(db, payment, booking, PaymentState.failed)
        redirect = f"/payments/mock-checkout/{merchant_ref}/done?mock-failure=1"
    else:  # cancel
        await _apply_state(db, payment, booking, PaymentState.cancelled)
        redirect = f"/payments/mock-checkout/{merchant_ref}/done?mock-failure=1"

    payment.response_payload = {"mock_outcome": outcome}
    await db.flush()

    logger.info(
        "payment_mock_completed",
        ref=merchant_ref,
        outcome=outcome,
    )
    return RedirectResponse(url=redirect, status_code=302)


@router.get("/mock-checkout/{merchant_ref}/done", response_class=HTMLResponse)
async def mock_checkout_done(merchant_ref: str):
    """Tiny terminal page — the WebView's URL matchers fire on the
    redirect to this URL (?mock-success / ?mock-failure) and pop the
    user back into the status screen, so this page only flashes for a
    split second on real devices.  We still render something legible
    in case the matcher is mis-configured."""
    _ensure_mock_mode()
    return HTMLResponse(
        """<!doctype html><html lang="ar" dir="rtl"><body style="font-family:sans-serif;
        text-align:center;padding:40px;color:#374151">
        <h2>تم — يمكنك العودة للتطبيق</h2>
        <p style="color:#6B7280">جارى تحديث حالة الدفع...</p>
        </body></html>"""
    )
