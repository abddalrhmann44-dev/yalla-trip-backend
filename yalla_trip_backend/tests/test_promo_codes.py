"""Promo-code admin CRUD + redemption tests."""

from __future__ import annotations

from datetime import datetime, timedelta, timezone

import pytest
from httpx import AsyncClient
from sqlalchemy import select

from app.models.promo_code import PromoCode, PromoRedemption
from tests.conftest import TestSession


async def _seed_property(owner: AsyncClient, price: int = 1000) -> int:
    resp = await owner.post("/properties", json={
        "name": "شاليه اختبار الكود",
        "area": "الساحل الشمالي",
        "category": "شاليه",
        "price_per_night": price,
        "bedrooms": 2,
        "max_guests": 4,
    })
    assert resp.status_code == 201, resp.text
    return resp.json()["id"]


async def _create_code(admin: AsyncClient, **overrides) -> dict:
    body = {
        "code": "WELCOME10",
        "type": "percent",
        "value": 10,
        "is_active": True,
    }
    body.update(overrides)
    resp = await admin.post("/promo-codes/admin", json=body)
    assert resp.status_code == 201, resp.text
    return resp.json()


# ══════════════════════════════════════════════════════════════
#  Admin CRUD
# ══════════════════════════════════════════════════════════════
@pytest.mark.asyncio
async def test_admin_can_crud_promo_code(admin_client: AsyncClient):
    created = await _create_code(admin_client, code="save20", value=20)
    assert created["code"] == "SAVE20"   # normalised to upper
    assert created["uses_count"] == 0

    # List
    listed = await admin_client.get("/promo-codes/admin")
    assert listed.status_code == 200
    assert any(c["id"] == created["id"] for c in listed.json())

    # Update
    patched = await admin_client.patch(
        f"/promo-codes/admin/{created['id']}",
        json={"value": 25, "is_active": False},
    )
    assert patched.status_code == 200
    assert patched.json()["value"] == 25
    assert patched.json()["is_active"] is False

    # Delete
    deleted = await admin_client.delete(
        f"/promo-codes/admin/{created['id']}"
    )
    assert deleted.status_code == 204

    gone = await admin_client.get(f"/promo-codes/admin/{created['id']}")
    assert gone.status_code == 404


@pytest.mark.asyncio
async def test_non_admin_cannot_manage(guest_client: AsyncClient):
    resp = await guest_client.post("/promo-codes/admin", json={
        "code": "X", "type": "fixed", "value": 5,
    })
    assert resp.status_code == 403


@pytest.mark.asyncio
async def test_duplicate_code_rejected(admin_client: AsyncClient):
    await _create_code(admin_client, code="DUP")
    resp = await admin_client.post("/promo-codes/admin", json={
        "code": "dup", "type": "percent", "value": 15,
    })
    assert resp.status_code == 409


# ══════════════════════════════════════════════════════════════
#  Validation endpoint
# ══════════════════════════════════════════════════════════════
@pytest.mark.asyncio
async def test_validate_percent_code(
    admin_client: AsyncClient, guest_client: AsyncClient
):
    await _create_code(admin_client, code="OFF20", value=20)
    resp = await guest_client.post("/promo-codes/validate", json={
        "code": "off20", "booking_amount": 1000,
    })
    assert resp.status_code == 200
    body = resp.json()
    assert body["valid"] is True
    assert body["discount_amount"] == 200
    assert body["final_amount"] == 800


@pytest.mark.asyncio
async def test_validate_fixed_code_capped_at_total(
    admin_client: AsyncClient, guest_client: AsyncClient
):
    await _create_code(admin_client, code="FIX500", type="fixed", value=500)
    resp = await guest_client.post("/promo-codes/validate", json={
        "code": "FIX500", "booking_amount": 300,
    })
    assert resp.status_code == 200
    # Discount can never exceed the booking amount itself.
    assert resp.json()["discount_amount"] == 300
    assert resp.json()["final_amount"] == 0


@pytest.mark.asyncio
async def test_validate_max_discount_cap(
    admin_client: AsyncClient, guest_client: AsyncClient
):
    await _create_code(
        admin_client, code="BIG", value=50, max_discount=100,
    )
    resp = await guest_client.post("/promo-codes/validate", json={
        "code": "BIG", "booking_amount": 1000,   # 50% = 500, but capped at 100
    })
    assert resp.json()["discount_amount"] == 100


@pytest.mark.asyncio
async def test_validate_expired_code(
    admin_client: AsyncClient, guest_client: AsyncClient
):
    await _create_code(
        admin_client, code="GONE",
        valid_until=(datetime.now(timezone.utc) - timedelta(days=1))
            .isoformat().replace("+00:00", "Z"),
    )
    resp = await guest_client.post("/promo-codes/validate", json={
        "code": "GONE", "booking_amount": 500,
    })
    assert resp.status_code == 200
    assert resp.json()["valid"] is False
    assert "منتهي" in resp.json()["reason_ar"]


@pytest.mark.asyncio
async def test_validate_inactive_code(
    admin_client: AsyncClient, guest_client: AsyncClient
):
    created = await _create_code(admin_client, code="OFF")
    await admin_client.patch(
        f"/promo-codes/admin/{created['id']}", json={"is_active": False},
    )
    resp = await guest_client.post("/promo-codes/validate", json={
        "code": "OFF", "booking_amount": 500,
    })
    assert resp.json()["valid"] is False


@pytest.mark.asyncio
async def test_validate_min_amount_not_met(
    admin_client: AsyncClient, guest_client: AsyncClient
):
    await _create_code(
        admin_client, code="MIN2000", min_booking_amount=2000,
    )
    resp = await guest_client.post("/promo-codes/validate", json={
        "code": "MIN2000", "booking_amount": 1000,
    })
    assert resp.json()["valid"] is False


@pytest.mark.asyncio
async def test_validate_unknown_code(guest_client: AsyncClient):
    resp = await guest_client.post("/promo-codes/validate", json={
        "code": "NOPE", "booking_amount": 500,
    })
    assert resp.json()["valid"] is False


# ══════════════════════════════════════════════════════════════
#  Booking integration
# ══════════════════════════════════════════════════════════════
@pytest.mark.asyncio
async def test_booking_applies_promo_discount(
    admin_client: AsyncClient,
    owner_client: AsyncClient,
    guest_client: AsyncClient,
):
    pid = await _seed_property(owner_client, price=1000)
    await _create_code(admin_client, code="HALF", value=50)

    resp = await guest_client.post("/bookings", json={
        "property_id": pid,
        "check_in": "2027-02-01",
        "check_out": "2027-02-03",
        "guests_count": 2,
        "promo_code": "half",
    })
    assert resp.status_code == 201, resp.text
    b = resp.json()
    # 2 nights × 1000 = 2000; 50% = 1000 discount, final = 1000
    assert b["promo_discount"] == 1000
    assert b["total_price"] == 1000

    # Redemption row exists
    async with TestSession() as s:
        rows = (await s.execute(select(PromoRedemption))).scalars().all()
        assert len(rows) == 1
        assert rows[0].discount_amount == 1000
        assert rows[0].booking_id == b["id"]

        # uses_count ticked up
        promo = (
            await s.execute(select(PromoCode).where(PromoCode.code == "HALF"))
        ).scalar_one()
        assert promo.uses_count == 1


@pytest.mark.asyncio
async def test_booking_rejects_invalid_code(
    admin_client: AsyncClient,
    owner_client: AsyncClient,
    guest_client: AsyncClient,
):
    pid = await _seed_property(owner_client)
    resp = await guest_client.post("/bookings", json={
        "property_id": pid,
        "check_in": "2027-02-01",
        "check_out": "2027-02-03",
        "guests_count": 2,
        "promo_code": "DOES_NOT_EXIST",
    })
    assert resp.status_code == 400


@pytest.mark.asyncio
async def test_booking_respects_max_uses(
    admin_client: AsyncClient,
    owner_client: AsyncClient,
    guest_client: AsyncClient,
):
    """Second booking with the same single-use code must fail."""
    pid = await _seed_property(owner_client)
    await _create_code(admin_client, code="ONCE", value=10, max_uses=1)

    r1 = await guest_client.post("/bookings", json={
        "property_id": pid,
        "check_in": "2027-03-01",
        "check_out": "2027-03-02",
        "guests_count": 1,
        "promo_code": "ONCE",
    })
    assert r1.status_code == 201

    r2 = await guest_client.post("/bookings", json={
        "property_id": pid,
        "check_in": "2027-04-01",
        "check_out": "2027-04-02",
        "guests_count": 1,
        "promo_code": "ONCE",
    })
    assert r2.status_code in (400, 409)


@pytest.mark.asyncio
async def test_booking_respects_max_uses_per_user(
    admin_client: AsyncClient,
    owner_client: AsyncClient,
    guest_client: AsyncClient,
):
    pid = await _seed_property(owner_client)
    await _create_code(
        admin_client, code="ONCE_EACH", value=10, max_uses_per_user=1,
    )

    r1 = await guest_client.post("/bookings", json={
        "property_id": pid,
        "check_in": "2027-05-01",
        "check_out": "2027-05-02",
        "guests_count": 1,
        "promo_code": "ONCE_EACH",
    })
    assert r1.status_code == 201

    r2 = await guest_client.post("/bookings", json={
        "property_id": pid,
        "check_in": "2027-06-01",
        "check_out": "2027-06-02",
        "guests_count": 1,
        "promo_code": "ONCE_EACH",
    })
    assert r2.status_code == 400


@pytest.mark.asyncio
async def test_admin_sees_redemptions_and_stats(
    admin_client: AsyncClient,
    owner_client: AsyncClient,
    guest_client: AsyncClient,
):
    pid = await _seed_property(owner_client)
    created = await _create_code(admin_client, code="TRACK", value=25)

    await guest_client.post("/bookings", json={
        "property_id": pid,
        "check_in": "2027-07-01",
        "check_out": "2027-07-02",
        "guests_count": 1,
        "promo_code": "TRACK",
    })

    redemptions = await admin_client.get(
        f"/promo-codes/admin/{created['id']}/redemptions"
    )
    assert redemptions.status_code == 200
    assert len(redemptions.json()) == 1

    stats = await admin_client.get("/promo-codes/admin/stats/overview")
    assert stats.status_code == 200
    body = stats.json()
    assert body["total_codes"] >= 1
    assert body["total_redemptions"] >= 1
    assert body["total_discount_given"] > 0


@pytest.mark.asyncio
async def test_admin_delete_cascades_to_redemptions(
    admin_client: AsyncClient,
    owner_client: AsyncClient,
    guest_client: AsyncClient,
):
    pid = await _seed_property(owner_client)
    created = await _create_code(admin_client, code="DEL", value=10)
    await guest_client.post("/bookings", json={
        "property_id": pid,
        "check_in": "2027-08-01",
        "check_out": "2027-08-02",
        "guests_count": 1,
        "promo_code": "DEL",
    })

    resp = await admin_client.delete(f"/promo-codes/admin/{created['id']}")
    assert resp.status_code == 204

    async with TestSession() as s:
        rows = (await s.execute(select(PromoRedemption))).scalars().all()
        # Redemptions are cascade-deleted along with the code.
        assert rows == []
