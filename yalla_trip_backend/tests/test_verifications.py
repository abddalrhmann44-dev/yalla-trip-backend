"""Tests for Wave 18 – Property verification / KYC."""

import pytest
from httpx import AsyncClient


@pytest.fixture
def anyio_backend():
    return "asyncio"


async def _create_property(c: AsyncClient) -> int:
    resp = await c.post("/properties", json={
        "name": "شاليه للتوثيق",
        "area": "الجونة",
        "category": "شاليه",
        "price_per_night": 800,
        "bedrooms": 2,
        "max_guests": 4,
    })
    assert resp.status_code == 201
    return resp.json()["id"]


# ── Host submission ───────────────────────────────────────────

@pytest.mark.asyncio
async def test_submit_verification(owner_client: AsyncClient):
    pid = await _create_property(owner_client)
    resp = await owner_client.post(f"/verifications/{pid}/submit", json={
        "document_urls": ["https://s3.example/doc1.pdf"],
        "primary_document_type": "ownership_contract",
        "host_note": "مرفق عقد الملكية",
    })
    assert resp.status_code == 201
    data = resp.json()
    assert data["status"] == "pending"
    assert data["property_id"] == pid
    assert "doc1.pdf" in data["document_urls"][0]


@pytest.mark.asyncio
async def test_cannot_submit_twice_while_pending(owner_client: AsyncClient):
    pid = await _create_property(owner_client)
    r1 = await owner_client.post(f"/verifications/{pid}/submit", json={
        "document_urls": ["https://s3.example/a.pdf"],
    })
    assert r1.status_code == 201
    r2 = await owner_client.post(f"/verifications/{pid}/submit", json={
        "document_urls": ["https://s3.example/b.pdf"],
    })
    assert r2.status_code == 409


@pytest.mark.asyncio
async def test_guest_cannot_submit(
    owner_client: AsyncClient, guest_client: AsyncClient
):
    pid = await _create_property(owner_client)
    resp = await guest_client.post(f"/verifications/{pid}/submit", json={
        "document_urls": ["https://s3.example/a.pdf"],
    })
    assert resp.status_code == 403


@pytest.mark.asyncio
async def test_host_list_own_verifications(owner_client: AsyncClient):
    pid = await _create_property(owner_client)
    await owner_client.post(f"/verifications/{pid}/submit", json={
        "document_urls": ["https://s3.example/a.pdf"],
    })
    resp = await owner_client.get(f"/verifications/my/{pid}")
    assert resp.status_code == 200
    assert len(resp.json()) == 1


# ── Admin review ──────────────────────────────────────────────

@pytest.mark.asyncio
async def test_admin_list_pending(
    owner_client: AsyncClient, admin_client: AsyncClient
):
    pid = await _create_property(owner_client)
    await owner_client.post(f"/verifications/{pid}/submit", json={
        "document_urls": ["https://s3.example/a.pdf"],
    })
    resp = await admin_client.get("/verifications/pending")
    assert resp.status_code == 200
    assert any(v["property_id"] == pid for v in resp.json())


@pytest.mark.asyncio
async def test_admin_approve_sets_is_verified(
    owner_client: AsyncClient, admin_client: AsyncClient
):
    pid = await _create_property(owner_client)
    r = await owner_client.post(f"/verifications/{pid}/submit", json={
        "document_urls": ["https://s3.example/a.pdf"],
    })
    vid = r.json()["id"]

    approve = await admin_client.post(
        f"/verifications/{vid}/approve",
        json={"admin_note": "موثّق"},
    )
    assert approve.status_code == 200
    assert approve.json()["status"] == "approved"

    # Fetch the property: is_verified should be True
    prop = await owner_client.get(f"/properties/{pid}")
    assert prop.status_code == 200
    assert prop.json()["is_verified"] is True


@pytest.mark.asyncio
async def test_admin_reject_does_not_verify(
    owner_client: AsyncClient, admin_client: AsyncClient
):
    pid = await _create_property(owner_client)
    r = await owner_client.post(f"/verifications/{pid}/submit", json={
        "document_urls": ["https://s3.example/a.pdf"],
    })
    vid = r.json()["id"]

    reject = await admin_client.post(
        f"/verifications/{vid}/reject",
        json={"admin_note": "مستندات غير واضحة"},
    )
    assert reject.status_code == 200
    assert reject.json()["status"] == "rejected"

    prop = await owner_client.get(f"/properties/{pid}")
    assert prop.json()["is_verified"] is False


@pytest.mark.asyncio
async def test_cannot_review_twice(
    owner_client: AsyncClient, admin_client: AsyncClient
):
    pid = await _create_property(owner_client)
    r = await owner_client.post(f"/verifications/{pid}/submit", json={
        "document_urls": ["https://s3.example/a.pdf"],
    })
    vid = r.json()["id"]
    await admin_client.post(f"/verifications/{vid}/approve")
    second = await admin_client.post(f"/verifications/{vid}/reject",
                                     json={"admin_note": "late"})
    assert second.status_code == 409


@pytest.mark.asyncio
async def test_needs_edit_flow(
    owner_client: AsyncClient, admin_client: AsyncClient
):
    pid = await _create_property(owner_client)
    r = await owner_client.post(f"/verifications/{pid}/submit", json={
        "document_urls": ["https://s3.example/a.pdf"],
    })
    vid = r.json()["id"]
    resp = await admin_client.post(f"/verifications/{vid}/needs-edit",
                                    json={"admin_note": "نحتاج فاتورة الكهرباء"})
    assert resp.status_code == 200
    assert resp.json()["status"] == "needs_edit"

    # Host can submit a new verification now (old one is not pending anymore)
    r2 = await owner_client.post(f"/verifications/{pid}/submit", json={
        "document_urls": ["https://s3.example/b.pdf"],
    })
    assert r2.status_code == 201


@pytest.mark.asyncio
async def test_non_admin_cannot_review(
    owner_client: AsyncClient, guest_client: AsyncClient
):
    pid = await _create_property(owner_client)
    r = await owner_client.post(f"/verifications/{pid}/submit", json={
        "document_urls": ["https://s3.example/a.pdf"],
    })
    vid = r.json()["id"]
    resp = await guest_client.post(f"/verifications/{vid}/approve")
    assert resp.status_code == 403
