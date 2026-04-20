"""Tests for boat listings (Wave 22)."""

import pytest
from httpx import AsyncClient


@pytest.fixture
def anyio_backend():
    return "asyncio"


@pytest.mark.asyncio
async def test_owner_can_create_boat_listing(owner_client: AsyncClient):
    """Owner creates a boat: price is per-hour, passengers capacity instead
    of rooms, and trip_duration_hours is stored."""
    resp = await owner_client.post("/properties", json={
        "name": "يخت الغردقة الفاخر",
        "description": "رحلة نصف يوم بحرية مع كابتن خبرة",
        "area": "الغردقة",
        "category": "مركب",
        "price_per_night": 1500,   # ≡ per-hour for boats
        "max_guests": 12,
        "trip_duration_hours": 6,
        "amenities": ["سترات نجاة", "GPS", "مشروبات باردة"],
    })
    assert resp.status_code in (200, 201), resp.text
    data = resp.json()
    assert data["category"] == "مركب"
    assert data["trip_duration_hours"] == 6
    assert data["max_guests"] == 12
    # Boats must have zero rooms/bathrooms regardless of input.
    assert data["bedrooms"] == 0
    assert data["bathrooms"] == 0
    assert data["total_rooms"] == 0
    assert data["price_per_night"] == 1500
    # Boats do not carry per-stay cleaning or utility fees.
    assert data["cleaning_fee"] == 0
    assert data["electricity_fee"] == 0
    assert data["water_fee"] == 0


@pytest.mark.asyncio
async def test_boat_defaults_trip_hours_when_missing(
    owner_client: AsyncClient,
):
    """If the owner omits trip_duration_hours, the backend defaults to 4."""
    resp = await owner_client.post("/properties", json={
        "name": "لانش شاطئ سيدي عبدالرحمن",
        "area": "الساحل الشمالي",
        "category": "مركب",
        "price_per_night": 800,
        "max_guests": 8,
    })
    assert resp.status_code in (200, 201), resp.text
    assert resp.json()["trip_duration_hours"] == 4


@pytest.mark.asyncio
async def test_non_boat_category_strips_trip_hours(owner_client: AsyncClient):
    """trip_duration_hours must be NULL for any non-boat category."""
    resp = await owner_client.post("/properties", json={
        "name": "شاليه للاختبار",
        "area": "الجونة",
        "category": "شاليه",
        "price_per_night": 1000,
        "bedrooms": 2,
        "bathrooms": 1,
        "max_guests": 4,
        "trip_duration_hours": 6,  # should be ignored
    })
    assert resp.status_code in (200, 201), resp.text
    assert resp.json()["trip_duration_hours"] is None


@pytest.mark.asyncio
async def test_boat_appears_in_category_search(
    owner_client: AsyncClient, guest_client: AsyncClient,
):
    """Filtering the public search by `category=مركب` surfaces boats."""
    from sqlalchemy import update
    from app.models.property import Property, PropertyStatus
    from tests.conftest import TestSession

    create = await owner_client.post("/properties", json={
        "name": "قارب صيد سريع",
        "area": "رأس سدر",
        "category": "مركب",
        "price_per_night": 600,
        "max_guests": 4,
        "trip_duration_hours": 3,
    })
    assert create.status_code in (200, 201)
    pid = create.json()["id"]

    # Promote to approved so the public feed surfaces it.
    async with TestSession() as s:
        await s.execute(
            update(Property)
            .where(Property.id == pid)
            .values(status=PropertyStatus.approved)
        )
        await s.commit()

    search = await guest_client.get("/properties?category=مركب")
    assert search.status_code == 200
    items = search.json()
    rows = items.get("items", items) if isinstance(items, dict) else items
    ids = [it["id"] for it in rows]
    assert pid in ids
