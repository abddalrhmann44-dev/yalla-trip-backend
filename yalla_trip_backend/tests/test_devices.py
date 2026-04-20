"""Device-token endpoint tests."""

import pytest
from httpx import AsyncClient


@pytest.mark.asyncio
async def test_register_and_list_devices(guest_client: AsyncClient):
    resp = await guest_client.get("/devices")
    assert resp.status_code == 200
    assert resp.json() == []

    resp = await guest_client.post("/devices", json={
        "token": "fcm-fake-token-abcdef0123456789",
        "platform": "android",
        "app_version": "1.0.0+1",
    })
    assert resp.status_code == 201, resp.text
    body = resp.json()
    assert body["token"].startswith("fcm-fake-token")
    assert body["platform"] == "android"

    resp = await guest_client.get("/devices")
    assert resp.status_code == 200
    assert len(resp.json()) == 1


@pytest.mark.asyncio
async def test_register_same_token_is_idempotent(guest_client: AsyncClient):
    payload = {
        "token": "fcm-fake-duplicate",
        "platform": "ios",
    }
    r1 = await guest_client.post("/devices", json=payload)
    r2 = await guest_client.post("/devices", json=payload)
    assert r1.status_code == 201
    assert r2.status_code == 201
    assert r1.json()["id"] == r2.json()["id"]

    resp = await guest_client.get("/devices")
    assert len(resp.json()) == 1


@pytest.mark.asyncio
async def test_delete_device(guest_client: AsyncClient):
    resp = await guest_client.post("/devices", json={
        "token": "fcm-fake-delete-me",
        "platform": "android",
    })
    device_id = resp.json()["id"]

    resp = await guest_client.delete(f"/devices/{device_id}")
    assert resp.status_code == 200

    resp = await guest_client.get("/devices")
    assert resp.json() == []


@pytest.mark.asyncio
async def test_delete_all_devices(guest_client: AsyncClient):
    for token in ("fake-1", "fake-2", "fake-3"):
        await guest_client.post(
            "/devices", json={"token": f"fcm-{token}", "platform": "android"}
        )

    resp = await guest_client.delete("/devices")
    assert resp.status_code == 200
    resp = await guest_client.get("/devices")
    assert resp.json() == []


@pytest.mark.asyncio
async def test_cannot_delete_other_users_device(
    guest_client: AsyncClient, owner_client: AsyncClient
):
    resp = await owner_client.post("/devices", json={
        "token": "fcm-owners-device",
        "platform": "android",
    })
    owner_dev = resp.json()["id"]

    resp = await guest_client.delete(f"/devices/{owner_dev}")
    assert resp.status_code == 404
