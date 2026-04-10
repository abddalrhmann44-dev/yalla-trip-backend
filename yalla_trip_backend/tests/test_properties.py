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
