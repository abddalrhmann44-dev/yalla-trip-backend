"""Admin endpoint tests."""

import pytest
from httpx import AsyncClient


@pytest.mark.asyncio
async def test_admin_stats(admin_client: AsyncClient):
    resp = await admin_client.get("/admin/stats")
    assert resp.status_code == 200
    data = resp.json()
    assert "total_users" in data
    assert "total_revenue" in data
    assert data["currency"] == "EGP"


@pytest.mark.asyncio
async def test_admin_users_list(admin_client: AsyncClient):
    resp = await admin_client.get("/admin/users")
    assert resp.status_code == 200
    data = resp.json()
    assert "items" in data
    assert "total" in data


@pytest.mark.asyncio
async def test_non_admin_forbidden(guest_client: AsyncClient):
    """Regular guests cannot access admin endpoints."""
    resp = await guest_client.get("/admin/stats")
    assert resp.status_code == 403
