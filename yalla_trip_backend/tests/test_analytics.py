"""Host analytics endpoint tests."""

from datetime import datetime, timedelta, timezone

import pytest
from httpx import AsyncClient


@pytest.mark.asyncio
async def test_owner_analytics_empty_account(owner_client: AsyncClient):
    """A fresh owner with no properties/bookings should still get a
    well-formed response with zeroed totals."""
    resp = await owner_client.get("/analytics/owner?period=month")
    assert resp.status_code == 200, resp.text
    body = resp.json()

    totals = body["totals"]
    assert totals["properties_count"] == 0
    assert totals["bookings_count"] == 0
    assert totals["revenue_total"] == 0
    assert totals["reviews_count"] == 0

    assert body["monthly"] == []
    assert body["top_properties"] == []
    assert body["occupancy"] == []


@pytest.mark.asyncio
async def test_owner_analytics_reflects_bookings(
    owner_client: AsyncClient, guest_client: AsyncClient
):
    """Create a property + a booking and make sure the numbers move."""
    resp = await owner_client.post("/properties", json={
        "name": "فيلا التحليلات",
        "area": "الساحل الشمالي",
        "category": "فيلا",
        "price_per_night": 1200,
        "bedrooms": 3,
        "max_guests": 6,
    })
    assert resp.status_code == 201
    pid = resp.json()["id"]

    ci = (datetime.now(timezone.utc) + timedelta(days=7)).date()
    co = ci + timedelta(days=3)
    resp = await guest_client.post("/bookings", json={
        "property_id": pid,
        "check_in": ci.isoformat(),
        "check_out": co.isoformat(),
        "guests_count": 2,
    })
    assert resp.status_code == 201

    resp = await owner_client.get("/analytics/owner?period=month")
    assert resp.status_code == 200
    body = resp.json()
    totals = body["totals"]

    assert totals["properties_count"] == 1
    assert totals["bookings_count"] == 1
    assert totals["bookings_upcoming"] == 1
    assert len(body["monthly"]) == 1
    assert body["monthly"][0]["bookings"] == 1
    assert len(body["top_properties"]) == 1
    assert body["top_properties"][0]["property_id"] == pid
    # 30 days of occupancy points, one property available each day
    assert len(body["occupancy"]) == 30
    assert all(p["total_available"] == 1 for p in body["occupancy"])


@pytest.mark.asyncio
async def test_owner_analytics_requires_owner(guest_client: AsyncClient):
    """Guests should get 403 – this endpoint is owner-only."""
    resp = await guest_client.get("/analytics/owner")
    assert resp.status_code == 403
