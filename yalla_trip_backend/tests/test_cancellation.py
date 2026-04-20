"""Cancellation policy + refund tests.

We cover two levels:

1. **Pure calculator** (`quote_refund`) — exhaustive table of tiers.
2. **HTTP layer** — cancel preview + actual cancel with COD
   (fast: COD's gateway.refund is a no-op, so no network calls).
"""

from datetime import datetime, timedelta, timezone

import pytest
from httpx import AsyncClient
from sqlalchemy import select

from app.models.booking import Booking, PaymentStatus
from app.models.payment import Payment, PaymentState
from app.models.property import CancellationPolicy
from app.services.cancellation import quote_refund
from tests.conftest import TestSession


# ══════════════════════════════════════════════════════════════
#  Pure-function tests
# ══════════════════════════════════════════════════════════════
# Pin ``NOW`` at midnight so ``_ci(days)`` gives an *exact* ``days × 24``
# hour lead time – otherwise the hour-based threshold comparisons round
# the wrong way on the boundary cases.
NOW = datetime(2026, 1, 1, 0, 0, tzinfo=timezone.utc)


def _ci(days: int):
    return (NOW + timedelta(days=days)).date()


@pytest.mark.parametrize("policy,days_ahead,expected_pct", [
    # flexible: 24h threshold
    (CancellationPolicy.flexible, 10, 100),
    (CancellationPolicy.flexible, 2, 100),
    (CancellationPolicy.flexible, 0, 0),
    # moderate: 5 days / 24h
    (CancellationPolicy.moderate, 10, 100),
    (CancellationPolicy.moderate, 5, 100),
    (CancellationPolicy.moderate, 3, 50),
    (CancellationPolicy.moderate, 1, 50),
    (CancellationPolicy.moderate, 0, 0),
    # strict: 7 days / 24h
    (CancellationPolicy.strict, 14, 100),
    (CancellationPolicy.strict, 7, 100),
    (CancellationPolicy.strict, 3, 50),
    (CancellationPolicy.strict, 1, 50),
    (CancellationPolicy.strict, 0, 0),
    # past check-in always 0
    (CancellationPolicy.flexible, -1, 0),
    (CancellationPolicy.strict, -5, 0),
])
def test_quote_refund_table(policy, days_ahead, expected_pct):
    quote = quote_refund(
        policy=policy,
        check_in=_ci(days_ahead),
        total_price=1000.0,
        now=NOW,
    )
    assert quote.refundable_percent == expected_pct, (
        f"{policy.value} @ {days_ahead}d → expected {expected_pct}% "
        f"got {quote.refundable_percent}%"
    )
    assert quote.refund_amount == 1000.0 * expected_pct / 100


# ══════════════════════════════════════════════════════════════
#  HTTP integration
# ══════════════════════════════════════════════════════════════
async def _create_booking(
    guest: AsyncClient, owner: AsyncClient, *, days_ahead: int = 30
) -> int:
    resp = await owner.post("/properties", json={
        "name": "شاليه الاختبار",
        "area": "الساحل الشمالي",
        "category": "شاليه",
        "price_per_night": 500,
        "bedrooms": 2,
        "max_guests": 4,
    })
    assert resp.status_code == 201, resp.text
    pid = resp.json()["id"]

    ci = datetime.now(timezone.utc) + timedelta(days=days_ahead)
    co = ci + timedelta(days=2)
    resp = await guest.post("/bookings", json={
        "property_id": pid,
        "check_in": ci.date().isoformat(),
        "check_out": co.date().isoformat(),
        "guests_count": 2,
    })
    assert resp.status_code == 201, resp.text
    return resp.json()["id"]


@pytest.mark.asyncio
async def test_cancel_preview_for_unpaid_booking(
    guest_client: AsyncClient, owner_client: AsyncClient
):
    booking_id = await _create_booking(
        guest_client, owner_client, days_ahead=30
    )
    resp = await guest_client.get(f"/bookings/{booking_id}/cancel/preview")
    assert resp.status_code == 200
    body = resp.json()
    # Default policy is moderate and 30 days out → 100 % of 0.0 (unpaid)
    assert body["refundable_percent"] == 100
    assert body["refund_amount"] == 0.0
    assert body["cancellation_policy"] == "moderate"


@pytest.mark.asyncio
async def test_cancel_preview_for_paid_booking(
    guest_client: AsyncClient, owner_client: AsyncClient
):
    booking_id = await _create_booking(
        guest_client, owner_client, days_ahead=30
    )
    # Flip the booking to "paid" directly in the DB so we don't have
    # to drive the full webhook flow here.
    async with TestSession() as session:
        b = (await session.execute(
            select(Booking).where(Booking.id == booking_id)
        )).scalar_one()
        b.payment_status = PaymentStatus.paid
        await session.commit()
        total = b.total_price

    resp = await guest_client.get(f"/bookings/{booking_id}/cancel/preview")
    assert resp.status_code == 200
    body = resp.json()
    assert body["refundable_percent"] == 100
    assert body["refund_amount"] == pytest.approx(total)


@pytest.mark.asyncio
async def test_cancel_with_full_refund_via_cod(
    guest_client: AsyncClient, owner_client: AsyncClient
):
    """End-to-end: initiate COD payment, fake-mark it paid, then
    cancel with plenty of lead time → 100 % refund.

    COD's refund is a no-op, so the gateway call never hits the
    network and the test stays fast & deterministic.
    """
    booking_id = await _create_booking(
        guest_client, owner_client, days_ahead=30
    )
    resp = await guest_client.post("/payments/initiate", json={
        "booking_id": booking_id,
        "provider": "cod",
        "method": "cod",
    })
    assert resp.status_code == 201

    # Mark payment + booking as paid directly in the DB.
    async with TestSession() as session:
        p = (await session.execute(
            select(Payment).where(Payment.booking_id == booking_id)
        )).scalar_one()
        p.state = PaymentState.paid
        p.provider_ref = "cod-ref-123"
        b = (await session.execute(
            select(Booking).where(Booking.id == booking_id)
        )).scalar_one()
        b.payment_status = PaymentStatus.paid
        await session.commit()

    resp = await guest_client.put(
        f"/bookings/{booking_id}/cancel",
        json={"reason": "Plans changed"},
    )
    assert resp.status_code == 200, resp.text
    body = resp.json()
    assert body["status"] == "cancelled"
    assert body["payment_status"] == "refunded"
    assert body["refund_amount"] == pytest.approx(body["total_price"])
    assert body["cancellation_reason"] == "Plans changed"


@pytest.mark.asyncio
async def test_cancel_twice_rejected(
    guest_client: AsyncClient, owner_client: AsyncClient
):
    booking_id = await _create_booking(
        guest_client, owner_client, days_ahead=30
    )
    resp = await guest_client.put(f"/bookings/{booking_id}/cancel", json={})
    assert resp.status_code == 200

    resp = await guest_client.put(f"/bookings/{booking_id}/cancel", json={})
    assert resp.status_code == 400
