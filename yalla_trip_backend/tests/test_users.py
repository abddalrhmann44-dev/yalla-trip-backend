"""User endpoint tests."""

import pytest
from httpx import AsyncClient


@pytest.mark.asyncio
async def test_get_profile(guest_client: AsyncClient):
    resp = await guest_client.get("/users/me")
    assert resp.status_code == 200
    data = resp.json()
    assert data["name"] == "Test User"
    assert data["role"] == "guest"


@pytest.mark.asyncio
async def test_update_profile(guest_client: AsyncClient):
    resp = await guest_client.put("/users/me", json={"name": "Updated Name"})
    assert resp.status_code == 200
    assert resp.json()["name"] == "Updated Name"


@pytest.mark.asyncio
async def test_delete_account(guest_client: AsyncClient):
    resp = await guest_client.delete("/users/me")
    assert resp.status_code == 200
    data = resp.json()
    assert "deactivated" in data["message"].lower() or "تعطيل" in data["message_ar"]
