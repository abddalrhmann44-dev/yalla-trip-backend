"""Booking endpoint tests."""

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
