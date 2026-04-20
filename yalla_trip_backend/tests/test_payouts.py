"""Host-payout router tests – bank accounts, batch creation, mark
paid/failed, CSV export, host summary."""

from __future__ import annotations

from datetime import date, datetime, timedelta, timezone

import pytest
from httpx import AsyncClient
from sqlalchemy import select

from app.models.booking import Booking, BookingStatus, PaymentStatus
from app.models.payout import (
    BookingPayoutStatus,
)
from tests.conftest import TestSession


# ══════════════════════════════════════════════════════════════
#  Helpers
# ══════════════════════════════════════════════════════════════
async def _seed_completed_bookings(
    *, owner_id: int, guest_id: int, count: int = 2, payout_each: float = 500,
) -> list[int]:
    """Create `count` completed+paid bookings attached to a freshly
    seeded property, bypassing the usual HTTP lifecycle."""
    from app.models.property import Category, Property

    async with TestSession() as s:
        prop = Property(
            name="Payout test property",
            area="الساحل الشمالي",
            category=Category.chalet,
            price_per_night=1000,
            bedrooms=2,
            max_guests=4,
            owner_id=owner_id,
        )
        s.add(prop)
        await s.flush()

        booking_ids: list[int] = []
        for i in range(count):
            checkout = date.today() - timedelta(days=5 + i)
            b = Booking(
                booking_code=f"P{owner_id:02d}{i:05d}"[:8],
                property_id=prop.id,
                guest_id=guest_id,
                owner_id=owner_id,
                check_in=checkout - timedelta(days=2),
                check_out=checkout,
                guests_count=1,
                total_price=payout_each + 50,
                platform_fee=50,
                owner_payout=payout_each,
                status=BookingStatus.completed,
                payment_status=PaymentStatus.paid,
            )
            s.add(b)
            await s.flush()
            booking_ids.append(b.id)
        await s.commit()
        return booking_ids


# ══════════════════════════════════════════════════════════════
#  Bank accounts
# ══════════════════════════════════════════════════════════════
@pytest.mark.asyncio
async def test_host_can_add_and_list_bank_account(owner_client: AsyncClient):
    resp = await owner_client.post("/payouts/bank-accounts", json={
        "type": "iban",
        "account_name": "Test Owner",
        "bank_name": "CIB",
        "iban": "EG380019000500000000263180002",
        "is_default": False,
    })
    assert resp.status_code == 201, resp.text
    body = resp.json()
    assert body["iban_masked"].startswith("••••")
    # First account always becomes default, even if flag was false.
    assert body["is_default"] is True

    listed = await owner_client.get("/payouts/bank-accounts")
    assert listed.status_code == 200
    assert len(listed.json()) == 1


@pytest.mark.asyncio
async def test_adding_default_unsets_previous(owner_client: AsyncClient):
    await owner_client.post("/payouts/bank-accounts", json={
        "type": "iban", "account_name": "Acc 1",
        "bank_name": "CIB", "iban": "EG380019000500000000263180001",
    })
    r2 = await owner_client.post("/payouts/bank-accounts", json={
        "type": "wallet", "account_name": "Acc 2",
        "wallet_phone": "01000000000", "is_default": True,
    })
    assert r2.status_code == 201

    accounts = (await owner_client.get("/payouts/bank-accounts")).json()
    defaults = [a for a in accounts if a["is_default"]]
    assert len(defaults) == 1
    assert defaults[0]["type"] == "wallet"


@pytest.mark.asyncio
async def test_wallet_account_requires_phone(owner_client: AsyncClient):
    resp = await owner_client.post("/payouts/bank-accounts", json={
        "type": "wallet", "account_name": "Bad",
    })
    assert resp.status_code == 422


@pytest.mark.asyncio
async def test_delete_bank_account(owner_client: AsyncClient):
    created = (await owner_client.post("/payouts/bank-accounts", json={
        "type": "iban", "account_name": "Del",
        "bank_name": "CIB", "iban": "EG380019000500000000263180007",
    })).json()
    resp = await owner_client.delete(
        f"/payouts/bank-accounts/{created['id']}"
    )
    assert resp.status_code == 204
    assert (await owner_client.get("/payouts/bank-accounts")).json() == []


# ══════════════════════════════════════════════════════════════
#  Host summary
# ══════════════════════════════════════════════════════════════
@pytest.mark.asyncio
async def test_host_summary_reflects_unpaid_balance(owner_client: AsyncClient):
    await _seed_completed_bookings(
        owner_id=2, guest_id=1, count=3, payout_each=700,
    )
    resp = await owner_client.get("/payouts/me/summary")
    assert resp.status_code == 200
    body = resp.json()
    assert body["pending_balance"] == 2100
    assert body["queued_balance"] == 0
    assert body["paid_total"] == 0
    assert body["eligible_booking_count"] == 3


# ══════════════════════════════════════════════════════════════
#  Admin batch + lifecycle
# ══════════════════════════════════════════════════════════════
@pytest.mark.asyncio
async def test_admin_batch_moves_bookings_to_queued(
    admin_client: AsyncClient, owner_client: AsyncClient,
):
    # Host has a default bank account so the payout links to it.
    await owner_client.post("/payouts/bank-accounts", json={
        "type": "iban", "account_name": "Owner",
        "bank_name": "CIB", "iban": "EG380019000500000000263180003",
    })
    booking_ids = await _seed_completed_bookings(
        owner_id=2, guest_id=1, count=2, payout_each=600,
    )

    resp = await admin_client.post("/payouts/admin/batch", json={
        "cycle_start": (date.today() - timedelta(days=30)).isoformat(),
        "cycle_end": date.today().isoformat(),
    })
    assert resp.status_code == 201, resp.text
    batches = resp.json()
    assert len(batches) == 1
    batch = batches[0]
    assert batch["status"] == "pending"
    assert batch["total_amount"] == 1200
    assert len(batch["items"]) == 2
    assert batch["bank_account_id"] is not None

    async with TestSession() as s:
        rows = (
            await s.execute(select(Booking).where(Booking.id.in_(booking_ids)))
        ).scalars().all()
        assert all(
            b.payout_status == BookingPayoutStatus.queued.value for b in rows
        )


@pytest.mark.asyncio
async def test_admin_mark_paid_advances_bookings(
    admin_client: AsyncClient, owner_client: AsyncClient,
):
    booking_ids = await _seed_completed_bookings(
        owner_id=2, guest_id=1, count=2, payout_each=400,
    )
    batches = (await admin_client.post("/payouts/admin/batch", json={
        "cycle_start": (date.today() - timedelta(days=30)).isoformat(),
        "cycle_end": date.today().isoformat(),
    })).json()
    payout_id = batches[0]["id"]

    resp = await admin_client.post(
        f"/payouts/admin/{payout_id}/mark-paid",
        json={"reference_number": "BANK-REF-001", "admin_notes": "ok"},
    )
    assert resp.status_code == 200
    body = resp.json()
    assert body["status"] == "paid"
    assert body["reference_number"] == "BANK-REF-001"
    assert body["processed_at"] is not None

    # Bookings advance to paid.
    async with TestSession() as s:
        rows = (
            await s.execute(select(Booking).where(Booking.id.in_(booking_ids)))
        ).scalars().all()
        assert all(
            b.payout_status == BookingPayoutStatus.paid.value for b in rows
        )

    # Host summary now shows paid_total.
    summary = (await owner_client.get("/payouts/me/summary")).json()
    assert summary["paid_total"] == 800
    assert summary["pending_balance"] == 0
    assert summary["queued_balance"] == 0
    assert summary["last_paid_at"] is not None


@pytest.mark.asyncio
async def test_admin_mark_failed_releases_bookings(
    admin_client: AsyncClient, owner_client: AsyncClient,
):
    booking_ids = await _seed_completed_bookings(
        owner_id=2, guest_id=1, count=1, payout_each=500,
    )
    batches = (await admin_client.post("/payouts/admin/batch", json={
        "cycle_start": (date.today() - timedelta(days=30)).isoformat(),
        "cycle_end": date.today().isoformat(),
    })).json()
    payout_id = batches[0]["id"]

    resp = await admin_client.post(
        f"/payouts/admin/{payout_id}/mark-failed",
        json={"admin_notes": "wrong IBAN"},
    )
    assert resp.status_code == 200
    assert resp.json()["status"] == "failed"

    async with TestSession() as s:
        rows = (
            await s.execute(select(Booking).where(Booking.id.in_(booking_ids)))
        ).scalars().all()
        # Released back to unpaid so a retry batch can pick them up.
        assert all(
            b.payout_status == BookingPayoutStatus.unpaid.value for b in rows
        )


@pytest.mark.asyncio
async def test_cannot_mark_paid_twice(admin_client: AsyncClient):
    await _seed_completed_bookings(
        owner_id=2, guest_id=1, count=1, payout_each=300,
    )
    batches = (await admin_client.post("/payouts/admin/batch", json={
        "cycle_start": (date.today() - timedelta(days=30)).isoformat(),
        "cycle_end": date.today().isoformat(),
    })).json()
    pid = batches[0]["id"]
    await admin_client.post(
        f"/payouts/admin/{pid}/mark-paid", json={"reference_number": "R1"},
    )
    resp = await admin_client.post(
        f"/payouts/admin/{pid}/mark-paid", json={"reference_number": "R2"},
    )
    assert resp.status_code == 400


@pytest.mark.asyncio
async def test_booking_cannot_appear_in_two_payouts(
    admin_client: AsyncClient,
):
    """The UNIQUE constraint on payout_items.booking_id means a
    second batch over the same window must return zero payouts."""
    await _seed_completed_bookings(
        owner_id=2, guest_id=1, count=2, payout_each=250,
    )
    body = {
        "cycle_start": (date.today() - timedelta(days=30)).isoformat(),
        "cycle_end": date.today().isoformat(),
    }
    first = (await admin_client.post("/payouts/admin/batch", json=body)).json()
    assert len(first) == 1

    second = (await admin_client.post("/payouts/admin/batch", json=body)).json()
    # All bookings are now queued/paid; no new work.
    assert second == []


@pytest.mark.asyncio
async def test_admin_csv_export(admin_client: AsyncClient, owner_client):
    # Need a bank account so CSV has something to write.
    await owner_client.post("/payouts/bank-accounts", json={
        "type": "iban", "account_name": "CSV Owner",
        "bank_name": "NBE", "iban": "EG380019000500000000263180009",
    })
    await _seed_completed_bookings(
        owner_id=2, guest_id=1, count=2, payout_each=777,
    )
    batches = (await admin_client.post("/payouts/admin/batch", json={
        "cycle_start": (date.today() - timedelta(days=30)).isoformat(),
        "cycle_end": date.today().isoformat(),
    })).json()
    pid = batches[0]["id"]

    resp = await admin_client.get(f"/payouts/admin/{pid}/csv")
    assert resp.status_code == 200
    assert resp.headers["content-type"].startswith("text/csv")
    text = resp.text
    assert "payout_id" in text
    assert "CSV Owner" in text
    assert "1554.00" in text   # 2 × 777
    assert "booking_id,booking_code,amount_egp" in text


@pytest.mark.asyncio
async def test_eligible_preview(admin_client: AsyncClient):
    await _seed_completed_bookings(
        owner_id=2, guest_id=1, count=3, payout_each=200,
    )
    resp = await admin_client.get(
        "/payouts/admin/eligible/preview",
        params={
            "cycle_start": (date.today() - timedelta(days=30)).isoformat(),
            "cycle_end": date.today().isoformat(),
        },
    )
    assert resp.status_code == 200
    body = resp.json()
    assert body["total_bookings"] == 3
    assert body["total_amount"] == 600
    assert len(body["hosts"]) == 1
    assert body["hosts"][0]["host_id"] == 2
    assert body["hosts"][0]["booking_count"] == 3


@pytest.mark.asyncio
async def test_hold_period_excludes_recent_bookings():
    """Bookings whose check-out is inside the hold window must NOT
    be eligible."""
    from app.models.property import Category, Property

    async with TestSession() as s:
        prop = Property(
            name="Hold test", area="الساحل الشمالي",
            category=Category.chalet, price_per_night=500,
            bedrooms=1, max_guests=2, owner_id=2,
        )
        s.add(prop)
        await s.flush()

        # Check-out today → inside the 1-day hold window.
        today = datetime.now(timezone.utc).date()
        s.add(Booking(
            booking_code="HOLD0001",
            property_id=prop.id,
            guest_id=1, owner_id=2,
            check_in=today - timedelta(days=2),
            check_out=today,
            guests_count=1,
            total_price=550, platform_fee=50, owner_payout=500,
            status=BookingStatus.completed,
            payment_status=PaymentStatus.paid,
        ))
        await s.commit()

    from app.services.payout_service import eligible_bookings_query
    async with TestSession() as s:
        stmt = await eligible_bookings_query(s)
        rows = (await s.execute(stmt)).scalars().all()
        assert rows == []


@pytest.mark.asyncio
async def test_non_admin_cannot_access_admin_endpoints(
    guest_client: AsyncClient,
):
    resp = await guest_client.post("/payouts/admin/batch", json={
        "cycle_start": "2026-01-01", "cycle_end": "2026-12-31",
    })
    assert resp.status_code == 403
