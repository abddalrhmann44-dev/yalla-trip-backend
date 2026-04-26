"""Booking endpoint tests."""

import asyncio

import pytest
from httpx import AsyncClient


@pytest.mark.asyncio
async def test_create_booking_property_not_found(guest_client: AsyncClient):
    resp = await guest_client.post("/bookings", json={
        "property_id": 99999,
        "check_in": "2025-08-01",
        "check_out": "2025-08-05",
        "guests_count": 2,
    })
    assert resp.status_code == 404


@pytest.mark.asyncio
async def test_create_booking_invalid_dates(guest_client: AsyncClient):
    """check_out before check_in should fail validation."""
    resp = await guest_client.post("/bookings", json={
        "property_id": 1,
        "check_in": "2025-08-05",
        "check_out": "2025-08-01",
        "guests_count": 1,
    })
    assert resp.status_code == 422


@pytest.mark.asyncio
async def test_my_bookings_empty(guest_client: AsyncClient):
    resp = await guest_client.get("/bookings/my")
    assert resp.status_code == 200
    assert resp.json()["items"] == []


# ══════════════════════════════════════════════════════════════
#  Concurrency – overbooking guard
# ══════════════════════════════════════════════════════════════
@pytest.mark.asyncio
async def test_concurrent_bookings_cannot_overbook_single_room(
    guest_client: AsyncClient, owner_client: AsyncClient
):
    """Two simultaneous bookings on a 1-room chalet → exactly one wins.

    Regression test for the overbooking race condition: before the
    ``with_for_update`` row-lock landed, both requests would read
    ``booked = 0`` and both INSERT, leaving the property double-booked.
    With the lock, the second request sees the first row and rejects
    with 409.
    """
    resp = await owner_client.post("/properties", json={
        "name": "شاليه اختبار التزامن",
        "area": "الساحل الشمالي",
        "category": "شاليه",
        "price_per_night": 500,
        "bedrooms": 1,
        "max_guests": 4,
        "total_rooms": 1,
    })
    assert resp.status_code == 201, resp.text
    pid = resp.json()["id"]

    payload = {
        "property_id": pid,
        "check_in": "2027-06-01",
        "check_out": "2027-06-05",
        "guests_count": 2,
    }

    # Fire both POSTs concurrently and gather the responses.
    r1, r2 = await asyncio.gather(
        guest_client.post("/bookings", json=payload),
        guest_client.post("/bookings", json=payload),
    )
    statuses = sorted([r1.status_code, r2.status_code])
    assert statuses == [201, 409], (
        f"Expected exactly one booking to win, got {statuses}: "
        f"r1={r1.text} r2={r2.text}"
    )
