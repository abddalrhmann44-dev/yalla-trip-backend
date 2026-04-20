"""Tests for Wave 17 – admin notification campaigns."""

from datetime import datetime, timedelta, timezone

import pytest
from httpx import AsyncClient


@pytest.fixture
def anyio_backend():
    return "asyncio"


# ── CRUD ───────────────────────────────────────────────────────

@pytest.mark.asyncio
async def test_create_campaign_draft(admin_client: AsyncClient):
    resp = await admin_client.post("/campaigns", json={
        "title_ar": "عرض الصيف",
        "title_en": "Summer Deal",
        "body_ar": "خصم 20% على كل الحجوزات هذا الأسبوع",
        "body_en": "20% off all bookings this week",
        "audience": "all_users",
    })
    assert resp.status_code == 201
    data = resp.json()
    assert data["status"] == "draft"
    assert data["title_ar"] == "عرض الصيف"
    assert data["audience"] == "all_users"


@pytest.mark.asyncio
async def test_create_campaign_scheduled(admin_client: AsyncClient):
    future = (datetime.now(timezone.utc) + timedelta(days=3)).isoformat()
    resp = await admin_client.post("/campaigns", json={
        "title_ar": "مجدولة",
        "body_ar": "ترسل لاحقاً",
        "audience": "hosts",
        "scheduled_at": future,
    })
    assert resp.status_code == 201
    assert resp.json()["status"] == "scheduled"


@pytest.mark.asyncio
async def test_list_campaigns(admin_client: AsyncClient):
    await admin_client.post("/campaigns", json={
        "title_ar": "أولى", "body_ar": "نص", "audience": "all_users",
    })
    await admin_client.post("/campaigns", json={
        "title_ar": "ثانية", "body_ar": "نص", "audience": "guests",
    })
    resp = await admin_client.get("/campaigns")
    assert resp.status_code == 200
    assert len(resp.json()) >= 2


@pytest.mark.asyncio
async def test_update_campaign(admin_client: AsyncClient):
    create = await admin_client.post("/campaigns", json={
        "title_ar": "قديم", "body_ar": "نص", "audience": "all_users",
    })
    cid = create.json()["id"]
    resp = await admin_client.put(f"/campaigns/{cid}", json={
        "title_ar": "جديد",
    })
    assert resp.status_code == 200
    assert resp.json()["title_ar"] == "جديد"


@pytest.mark.asyncio
async def test_delete_campaign(admin_client: AsyncClient):
    create = await admin_client.post("/campaigns", json={
        "title_ar": "احذفني", "body_ar": "نص", "audience": "all_users",
    })
    cid = create.json()["id"]
    resp = await admin_client.delete(f"/campaigns/{cid}")
    assert resp.status_code == 204

    get_resp = await admin_client.get(f"/campaigns/{cid}")
    assert get_resp.status_code == 404


@pytest.mark.asyncio
async def test_cancel_campaign(admin_client: AsyncClient):
    create = await admin_client.post("/campaigns", json={
        "title_ar": "ألغيني", "body_ar": "نص", "audience": "all_users",
    })
    cid = create.json()["id"]
    resp = await admin_client.post(f"/campaigns/{cid}/cancel")
    assert resp.status_code == 200
    assert resp.json()["status"] == "cancelled"


# ── Audience & send ───────────────────────────────────────────

@pytest.mark.asyncio
async def test_preview_audience(admin_client: AsyncClient):
    create = await admin_client.post("/campaigns", json={
        "title_ar": "معاينة", "body_ar": "نص", "audience": "all_users",
    })
    cid = create.json()["id"]
    resp = await admin_client.get(f"/campaigns/{cid}/preview")
    assert resp.status_code == 200
    assert "count" in resp.json()
    assert resp.json()["count"] >= 1  # at least the admin themselves


@pytest.mark.asyncio
async def test_by_area_requires_filter(admin_client: AsyncClient):
    create = await admin_client.post("/campaigns", json={
        "title_ar": "منطقة", "body_ar": "نص", "audience": "by_area",
    })
    cid = create.json()["id"]
    resp = await admin_client.get(f"/campaigns/{cid}/preview")
    assert resp.status_code == 422


@pytest.mark.asyncio
async def test_send_campaign_marks_sent(admin_client: AsyncClient):
    create = await admin_client.post("/campaigns", json={
        "title_ar": "إرسال",
        "body_ar": "اختبار الإرسال",
        "audience": "all_users",
    })
    cid = create.json()["id"]
    resp = await admin_client.post(f"/campaigns/{cid}/send")
    assert resp.status_code == 200
    data = resp.json()
    assert data["status"] == "sent"
    assert data["target_count"] >= 1
    assert data["sent_at"] is not None


@pytest.mark.asyncio
async def test_cannot_send_twice(admin_client: AsyncClient):
    create = await admin_client.post("/campaigns", json={
        "title_ar": "مرتين", "body_ar": "نص", "audience": "all_users",
    })
    cid = create.json()["id"]
    first = await admin_client.post(f"/campaigns/{cid}/send")
    assert first.status_code == 200
    second = await admin_client.post(f"/campaigns/{cid}/send")
    assert second.status_code == 409


@pytest.mark.asyncio
async def test_cannot_edit_sent_campaign(admin_client: AsyncClient):
    create = await admin_client.post("/campaigns", json={
        "title_ar": "مرسل", "body_ar": "نص", "audience": "all_users",
    })
    cid = create.json()["id"]
    await admin_client.post(f"/campaigns/{cid}/send")
    resp = await admin_client.put(f"/campaigns/{cid}", json={"title_ar": "تعديل"})
    assert resp.status_code == 409


# ── Authorization ─────────────────────────────────────────────

@pytest.mark.asyncio
async def test_non_admin_forbidden(owner_client: AsyncClient):
    resp = await owner_client.get("/campaigns")
    assert resp.status_code == 403

    resp = await owner_client.post("/campaigns", json={
        "title_ar": "ممنوع", "body_ar": "نص", "audience": "all_users",
    })
    assert resp.status_code == 403
