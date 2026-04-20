"""Reports / dispute-resolution endpoint tests."""

from __future__ import annotations

import pytest
from httpx import AsyncClient


async def _seed_property(owner: AsyncClient) -> int:
    resp = await owner.post("/properties", json={
        "name": "بيت الاختبار",
        "area": "رأس سدر",
        "category": "شاليه",
        "price_per_night": 1000,
        "bedrooms": 2,
        "max_guests": 4,
    })
    assert resp.status_code == 201, resp.text
    return resp.json()["id"]


@pytest.mark.asyncio
async def test_guest_can_file_report_on_property(
    guest_client: AsyncClient, owner_client: AsyncClient
):
    pid = await _seed_property(owner_client)
    resp = await guest_client.post("/reports", json={
        "target_type": "property",
        "target_id": pid,
        "reason": "fake_listing",
        "details": "لا يطابق الوصف",
    })
    assert resp.status_code == 201, resp.text
    body = resp.json()
    assert body["status"] == "pending"
    assert body["target_id"] == pid

    # Guest sees their report in /reports/mine
    mine = await guest_client.get("/reports/mine")
    assert mine.status_code == 200
    assert len(mine.json()) == 1


@pytest.mark.asyncio
async def test_report_rejects_missing_target(guest_client: AsyncClient):
    resp = await guest_client.post("/reports", json={
        "target_type": "property",
        "target_id": 99999,
        "reason": "spam",
    })
    assert resp.status_code == 404


@pytest.mark.asyncio
async def test_cannot_report_yourself(guest_client: AsyncClient):
    # _fake_user.id == 1
    resp = await guest_client.post("/reports", json={
        "target_type": "user",
        "target_id": 1,
        "reason": "abuse",
    })
    assert resp.status_code == 400


@pytest.mark.asyncio
async def test_admin_can_resolve_and_dismiss(
    guest_client: AsyncClient,
    owner_client: AsyncClient,
    admin_client: AsyncClient,
):
    pid = await _seed_property(owner_client)

    # File two reports
    r1 = (await guest_client.post("/reports", json={
        "target_type": "property", "target_id": pid, "reason": "spam",
    })).json()
    r2 = (await guest_client.post("/reports", json={
        "target_type": "property", "target_id": pid, "reason": "abuse",
    })).json()

    # Admin lists the pending queue
    resp = await admin_client.get("/reports/admin?status=pending")
    assert resp.status_code == 200
    assert len(resp.json()) == 2

    # Resolve one, dismiss the other
    resolved = await admin_client.patch(
        f"/reports/admin/{r1['id']}/resolve",
        json={"notes": "listing taken down"},
    )
    assert resolved.status_code == 200
    assert resolved.json()["status"] == "resolved"

    dismissed = await admin_client.patch(
        f"/reports/admin/{r2['id']}/dismiss",
        json={"notes": "duplicate"},
    )
    assert dismissed.status_code == 200
    assert dismissed.json()["status"] == "dismissed"

    # Pending queue is now empty
    pending = await admin_client.get("/reports/admin?status=pending")
    assert pending.status_code == 200
    assert pending.json() == []

    # Stats reflect the state transitions
    stats = (await admin_client.get("/reports/admin/stats")).json()
    assert stats["counts_by_status"]["pending"] == 0
    assert stats["counts_by_status"]["resolved"] == 1
    assert stats["counts_by_status"]["dismissed"] == 1
    assert stats["total"] == 2


@pytest.mark.asyncio
async def test_non_admin_cannot_view_queue(guest_client: AsyncClient):
    resp = await guest_client.get("/reports/admin")
    assert resp.status_code == 403


@pytest.mark.asyncio
async def test_cannot_resolve_already_resolved_report(
    guest_client: AsyncClient,
    owner_client: AsyncClient,
    admin_client: AsyncClient,
):
    pid = await _seed_property(owner_client)
    r = (await guest_client.post("/reports", json={
        "target_type": "property", "target_id": pid, "reason": "spam",
    })).json()
    ok = await admin_client.patch(f"/reports/admin/{r['id']}/resolve")
    assert ok.status_code == 200
    again = await admin_client.patch(f"/reports/admin/{r['id']}/dismiss")
    assert again.status_code == 400


@pytest.mark.asyncio
async def test_admin_pending_properties_queue(
    owner_client: AsyncClient, admin_client: AsyncClient
):
    await _seed_property(owner_client)
    await _seed_property(owner_client)

    resp = await admin_client.get("/admin/properties/pending")
    assert resp.status_code == 200, resp.text
    body = resp.json()
    assert body["total"] >= 2
    # Everything in the queue must be pending
    for item in body["items"]:
        assert item["status"] == "pending"
