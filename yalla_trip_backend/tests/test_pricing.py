"""Tests for Wave 15 – Smart pricing suggestions."""

from datetime import date, timedelta

import pytest
from httpx import AsyncClient


@pytest.fixture
def anyio_backend():
    return "asyncio"


async def _create_property(c: AsyncClient, price: int = 1000) -> int:
    resp = await c.post("/properties", json={
        "name": "شاليه التسعير",
        "area": "الساحل الشمالي",
        "category": "شاليه",
        "price_per_night": price,
        "weekend_price": int(price * 1.2),
        "bedrooms": 2,
        "max_guests": 4,
    })
    assert resp.status_code == 201
    return resp.json()["id"]


@pytest.mark.asyncio
async def test_get_suggestions_basic(owner_client: AsyncClient):
    pid = await _create_property(owner_client)
    start = (date.today() + timedelta(days=30)).isoformat()
    end = (date.today() + timedelta(days=37)).isoformat()

    resp = await owner_client.get(
        f"/pricing/{pid}/suggestions?start={start}&end={end}"
    )
    assert resp.status_code == 200
    data = resp.json()
    assert len(data) == 7
    for s in data:
        assert "suggested_price" in s
        assert "multiplier" in s
        assert "delta_percent" in s
        assert isinstance(s["reasons"], list)
        assert s["base_price"] > 0


@pytest.mark.asyncio
async def test_suggestion_multiplier_bounded(owner_client: AsyncClient):
    """Multiplier is clamped to [0.6, 2.0]."""
    pid = await _create_property(owner_client)
    start = (date.today() + timedelta(days=30)).isoformat()
    end = (date.today() + timedelta(days=33)).isoformat()
    resp = await owner_client.get(
        f"/pricing/{pid}/suggestions?start={start}&end={end}"
    )
    assert resp.status_code == 200
    for s in resp.json():
        assert 0.6 <= s["multiplier"] <= 2.0


@pytest.mark.asyncio
async def test_range_too_large_rejected(owner_client: AsyncClient):
    pid = await _create_property(owner_client)
    start = date.today().isoformat()
    end = (date.today() + timedelta(days=100)).isoformat()
    resp = await owner_client.get(
        f"/pricing/{pid}/suggestions?start={start}&end={end}"
    )
    assert resp.status_code == 422


@pytest.mark.asyncio
async def test_guest_cannot_fetch_suggestions(
    owner_client: AsyncClient, guest_client: AsyncClient
):
    pid = await _create_property(owner_client)
    start = date.today().isoformat()
    end = (date.today() + timedelta(days=3)).isoformat()
    resp = await guest_client.get(
        f"/pricing/{pid}/suggestions?start={start}&end={end}"
    )
    assert resp.status_code == 403


@pytest.mark.asyncio
async def test_weekend_base_price_used(owner_client: AsyncClient):
    """Friday/Saturday should use weekend_price as base."""
    pid = await _create_property(owner_client, price=1000)
    # Find next Friday
    today = date.today()
    days_to_fri = (4 - today.weekday()) % 7 or 7
    fri = today + timedelta(days=days_to_fri)
    sun = fri + timedelta(days=3)
    resp = await owner_client.get(
        f"/pricing/{pid}/suggestions?start={fri.isoformat()}&end={sun.isoformat()}"
    )
    assert resp.status_code == 200
    data = resp.json()
    # Fri and Sat should have base_price = 1200 (weekend_price)
    fri_sat = [d for d in data if date.fromisoformat(d["date"]).weekday() in (4, 5)]
    for d in fri_sat:
        assert d["base_price"] == 1200
