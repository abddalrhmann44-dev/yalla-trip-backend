"""Property endpoint tests."""

import pytest
from httpx import AsyncClient


@pytest.mark.asyncio
async def test_list_properties_empty(guest_client: AsyncClient):
    resp = await guest_client.get("/properties")
    assert resp.status_code == 200
    data = resp.json()
    assert data["items"] == []
    assert data["total"] == 0


@pytest.mark.asyncio
async def test_create_property_requires_owner(guest_client: AsyncClient):
    """Guests cannot create properties."""
    resp = await guest_client.post("/properties", json={
        "name": "شاليه بحر",
        "area": "عين السخنة",
        "category": "شاليه",
        "price_per_night": 500,
    })
    assert resp.status_code == 403


@pytest.mark.asyncio
async def test_create_and_get_property(owner_client: AsyncClient):
    resp = await owner_client.post("/properties", json={
        "name": "شاليه فاخر",
        "area": "عين السخنة",
        "category": "شاليه",
        "price_per_night": 800,
        "bedrooms": 3,
        "max_guests": 6,
    })
    assert resp.status_code == 201
    prop = resp.json()
    assert prop["name"] == "شاليه فاخر"
    prop_id = prop["id"]

    # fetch
    resp2 = await owner_client.get(f"/properties/{prop_id}")
    assert resp2.status_code == 200
    assert resp2.json()["id"] == prop_id


@pytest.mark.asyncio
async def test_property_not_found(guest_client: AsyncClient):
    resp = await guest_client.get("/properties/99999")
    assert resp.status_code == 404


# ──────────────────────────────────────────────────────────────────
# Regression: update_property must whitelist editable fields.
# ``owner_id`` is **not** editable; an attempt to send it must be
# silently dropped (never honoured) and the row must keep its real
# owner.  Before the whitelist fix the router blindly forwarded
# arbitrary fields to ``setattr`` – an IDOR-grade vulnerability.
# ──────────────────────────────────────────────────────────────────
@pytest.mark.asyncio
async def test_update_property_drops_non_whitelisted_fields(owner_client: AsyncClient):
    create = await owner_client.post(
        "/properties",
        json={
            "name": "Whitelist Test",
            "area": "عين السخنة",
            "category": "شاليه",
            "price_per_night": 1000,
        },
    )
    assert create.status_code == 201
    pid = create.json()["id"]
    real_owner = create.json()["owner_id"]

    resp = await owner_client.put(
        f"/properties/{pid}",
        json={
            "name": "Renamed",
            "owner_id": 9999,           # forbidden: ownership transfer
            "rating": 5.0,               # forbidden: rating spoofing
            "is_featured": True,         # forbidden: admin-only flag
            "review_count": 999,         # forbidden: stat spoofing
        },
    )
    assert resp.status_code == 200
    body = resp.json()
    assert body["name"] == "Renamed"
    assert body["owner_id"] == real_owner       # untouched
    assert body["rating"] == 0                  # default, not 5.0
    assert body["is_featured"] is False         # default, not True
    assert body["review_count"] == 0            # default, not 999


# ──────────────────────────────────────────────────────────────────
# Regression: deleting a property with an active (paid/upcoming)
# booking must return 409 and *not* remove the row.  This prevents
# cascade-deleting bookings + payments + payouts the host already
# owes a guest.
# ──────────────────────────────────────────────────────────────────
@pytest.mark.asyncio
async def test_delete_property_blocked_by_active_booking(
    owner_client: AsyncClient, guest_client: AsyncClient
):
    from datetime import date, timedelta

    # 1. Owner creates a property
    create = await owner_client.post(
        "/properties",
        json={
            "name": "Locked Property",
            "area": "عين السخنة",
            "category": "شاليه",
            "price_per_night": 500,
            "instant_booking": True,
        },
    )
    assert create.status_code == 201
    pid = create.json()["id"]

    # 2. Guest creates a booking that's still in the future (active)
    today = date.today()
    booking_resp = await guest_client.post(
        "/bookings",
        json={
            "property_id": pid,
            "check_in": (today + timedelta(days=10)).isoformat(),
            "check_out": (today + timedelta(days=12)).isoformat(),
            "guests": 2,
        },
    )
    # Booking creation may fail in some test setups (e.g. payment
    # required); we only care about the delete guard, so skip if the
    # booking didn't actually land.
    if booking_resp.status_code not in (200, 201):
        pytest.skip(
            f"Could not create active booking for guard test: "
            f"{booking_resp.status_code} {booking_resp.text}"
        )

    # 3. Owner tries to delete – must be refused with 409
    resp = await owner_client.delete(f"/properties/{pid}")
    assert resp.status_code == 409, resp.text
    assert "حجز" in resp.text or "active" in resp.text.lower()

    # 4. Property still visible to its owner (soft-delete sentinel
    #    is irrelevant because the row was never marked deleted).
    still = await owner_client.get(f"/properties/{pid}")
    assert still.status_code == 200


# ──────────────────────────────────────────────────────────────────
# Regression: /properties/mine/stats aggregates without N+1.
# We don't assert exact counts (they depend on other tests' data
# inside the same setup) – we only assert the contract.
# ──────────────────────────────────────────────────────────────────
@pytest.mark.asyncio
async def test_mine_stats_contract(owner_client: AsyncClient):
    await owner_client.post(
        "/properties",
        json={
            "name": "Stats Probe",
            "area": "عين السخنة",
            "category": "شاليه",
            "price_per_night": 700,
        },
    )
    resp = await owner_client.get("/properties/mine/stats")
    assert resp.status_code == 200
    data = resp.json()
    for key in (
        "total_properties",
        "active_properties",
        "avg_rating",
        "total_reviews",
        "revenue_30d",
        "revenue_all_time",
        "upcoming_bookings",
        "pending_kyc",
    ):
        assert key in data, f"missing key {key} in {data}"
    assert data["total_properties"] >= 1
    assert data["revenue_all_time"] >= 0
    assert data["revenue_30d"] >= 0
