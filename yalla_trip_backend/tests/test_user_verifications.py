"""Tests for Wave 19 – guest/user identity verification."""

import pytest
from httpx import AsyncClient


@pytest.fixture
def anyio_backend():
    return "asyncio"


_DOCS = {
    "id_doc_type": "national_id",
    "id_front_url": "https://s3.example/id-front.jpg",
    "id_back_url": "https://s3.example/id-back.jpg",
    "selfie_url": "https://s3.example/selfie.jpg",
}


# ── Submission ────────────────────────────────────────────────

@pytest.mark.asyncio
async def test_submit_verification(guest_client: AsyncClient):
    resp = await guest_client.post("/me/verification", json=_DOCS)
    assert resp.status_code == 201
    data = resp.json()
    assert data["status"] == "pending"
    assert data["id_doc_type"] == "national_id"
    assert data["selfie_url"].endswith("selfie.jpg")


@pytest.mark.asyncio
async def test_cannot_submit_while_pending(guest_client: AsyncClient):
    r1 = await guest_client.post("/me/verification", json=_DOCS)
    assert r1.status_code == 201
    r2 = await guest_client.post("/me/verification", json=_DOCS)
    assert r2.status_code == 409


@pytest.mark.asyncio
async def test_list_my_verifications(guest_client: AsyncClient):
    await guest_client.post("/me/verification", json=_DOCS)
    resp = await guest_client.get("/me/verification")
    assert resp.status_code == 200
    assert len(resp.json()) == 1


@pytest.mark.asyncio
async def test_passport_variant(guest_client: AsyncClient):
    payload = dict(_DOCS)
    payload["id_doc_type"] = "passport"
    payload.pop("id_back_url")  # passport has no back
    resp = await guest_client.post("/me/verification", json=payload)
    assert resp.status_code == 201
    assert resp.json()["id_doc_type"] == "passport"


# ── Admin review ──────────────────────────────────────────────

@pytest.mark.asyncio
async def test_admin_list_pending(
    guest_client: AsyncClient, admin_client: AsyncClient
):
    await guest_client.post("/me/verification", json=_DOCS)
    resp = await admin_client.get("/admin/user-verifications/pending")
    assert resp.status_code == 200
    assert len(resp.json()) >= 1


@pytest.mark.asyncio
async def test_admin_approve_sets_user_verified(
    guest_client: AsyncClient, admin_client: AsyncClient
):
    submit = await guest_client.post("/me/verification", json=_DOCS)
    vid = submit.json()["id"]

    approve = await admin_client.post(
        f"/admin/user-verifications/{vid}/approve",
        json={"admin_note": "OK"},
    )
    assert approve.status_code == 200
    data = approve.json()
    assert data["status"] == "approved"
    assert data["admin_note"] == "OK"
    assert data["reviewed_at"] is not None

    # Guest is verified after approval
    me_after = await guest_client.get("/users/me")
    assert me_after.status_code == 200
    assert me_after.json().get("is_verified") is True


@pytest.mark.asyncio
async def test_admin_reject_persists_status(
    guest_client: AsyncClient, admin_client: AsyncClient
):
    submit = await guest_client.post("/me/verification", json=_DOCS)
    vid = submit.json()["id"]

    resp = await admin_client.post(
        f"/admin/user-verifications/{vid}/reject",
        json={"admin_note": "صورة غير واضحة"},
    )
    assert resp.status_code == 200
    data = resp.json()
    assert data["status"] == "rejected"
    assert "واضحة" in data["admin_note"]
    assert data["reviewed_at"] is not None


@pytest.mark.asyncio
async def test_cannot_review_twice(
    guest_client: AsyncClient, admin_client: AsyncClient
):
    submit = await guest_client.post("/me/verification", json=_DOCS)
    vid = submit.json()["id"]
    await admin_client.post(f"/admin/user-verifications/{vid}/approve")
    second = await admin_client.post(
        f"/admin/user-verifications/{vid}/reject",
        json={"admin_note": "late"},
    )
    assert second.status_code == 409


@pytest.mark.asyncio
async def test_needs_edit_flow(
    guest_client: AsyncClient, admin_client: AsyncClient
):
    submit = await guest_client.post("/me/verification", json=_DOCS)
    vid = submit.json()["id"]
    resp = await admin_client.post(
        f"/admin/user-verifications/{vid}/needs-edit",
        json={"admin_note": "نحتاج سيلفي أوضح"},
    )
    assert resp.status_code == 200
    assert resp.json()["status"] == "needs_edit"

    # User can submit again (old one no longer pending)
    r2 = await guest_client.post("/me/verification", json=_DOCS)
    assert r2.status_code == 201


@pytest.mark.asyncio
async def test_non_admin_cannot_review(
    guest_client: AsyncClient, owner_client: AsyncClient
):
    submit = await guest_client.post("/me/verification", json=_DOCS)
    vid = submit.json()["id"]
    resp = await owner_client.post(f"/admin/user-verifications/{vid}/approve")
    assert resp.status_code == 403


@pytest.mark.asyncio
async def test_non_admin_cannot_list_pending(owner_client: AsyncClient):
    resp = await owner_client.get("/admin/user-verifications/pending")
    assert resp.status_code == 403
