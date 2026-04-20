"""Audit-log integration tests.

These exercise the full stack: an admin performs a real mutation via
the HTTP API and we assert that a matching row appears in
``/admin/audit``.  We also cover the filter and scrubbing behaviours.
"""

from __future__ import annotations

import pytest
from httpx import AsyncClient
from sqlalchemy import select

from app.services.audit_service import _scrub, log_action
from app.models.audit_log import AuditLogEntry


# ── Unit: secret scrubbing ────────────────────────────────
def test_scrub_nested_dict_removes_secrets():
    data = {
        "email": "a@b.com",
        "password": "p@ss",
        "nested": {"token": "abc", "other": "keep"},
        "list": [{"api_key": "secret"}, "plain"],
    }
    out = _scrub(data)
    assert out["email"] == "a@b.com"
    assert out["password"] == "***"
    assert out["nested"] == {"token": "***", "other": "keep"}
    assert out["list"][0]["api_key"] == "***"
    assert out["list"][1] == "plain"


# ── API: basic list / auth ────────────────────────────────
@pytest.mark.asyncio
async def test_audit_list_empty(admin_client: AsyncClient):
    resp = await admin_client.get("/admin/audit")
    assert resp.status_code == 200
    assert resp.json() == []


@pytest.mark.asyncio
async def test_audit_forbidden_for_guest(guest_client: AsyncClient):
    resp = await guest_client.get("/admin/audit")
    assert resp.status_code == 403


# ── API: promo create writes an audit entry ──────────────
@pytest.mark.asyncio
async def test_promo_create_emits_audit_entry(admin_client: AsyncClient):
    payload = {
        "code": "AUDIT10",
        "type": "percent",
        "value": 10,
        "max_uses": 5,
    }
    r = await admin_client.post("/promo-codes/admin", json=payload)
    assert r.status_code == 201, r.text
    promo_id = r.json()["id"]

    logs = (await admin_client.get("/admin/audit")).json()
    assert any(
        e["action"] == "promo.create"
        and e["target_type"] == "promo_code"
        and e["target_id"] == promo_id
        and e["after"]["code"] == "AUDIT10"
        for e in logs
    ), logs


@pytest.mark.asyncio
async def test_promo_delete_emits_audit_entry_with_snapshot(
    admin_client: AsyncClient,
):
    created = await admin_client.post(
        "/promo-codes/admin",
        json={"code": "BYE", "type": "fixed", "value": 50},
    )
    promo_id = created.json()["id"]

    r = await admin_client.delete(f"/promo-codes/admin/{promo_id}")
    assert r.status_code == 204

    logs = (await admin_client.get("/admin/audit")).json()
    delete_entries = [e for e in logs if e["action"] == "promo.delete"]
    assert len(delete_entries) == 1
    entry = delete_entries[0]
    assert entry["target_id"] == promo_id
    # Deletion records a "before" snapshot so the value survives.
    assert entry["before"]["code"] == "BYE"
    assert entry["after"] is None


# ── API: filtering ─────────────────────────────────────────
@pytest.mark.asyncio
async def test_audit_filter_by_action_prefix(admin_client: AsyncClient):
    await admin_client.post(
        "/promo-codes/admin",
        json={"code": "FIL1", "type": "percent", "value": 5},
    )
    await admin_client.post(
        "/promo-codes/admin",
        json={"code": "FIL2", "type": "percent", "value": 7},
    )

    r = await admin_client.get(
        "/admin/audit", params={"action_prefix": "promo."},
    )
    assert r.status_code == 200
    entries = r.json()
    assert len(entries) >= 2
    assert all(e["action"].startswith("promo.") for e in entries)


@pytest.mark.asyncio
async def test_audit_filter_by_target(admin_client: AsyncClient):
    created = await admin_client.post(
        "/promo-codes/admin",
        json={"code": "TARGET", "type": "percent", "value": 5},
    )
    promo_id = created.json()["id"]

    r = await admin_client.get(
        "/admin/audit",
        params={"target_type": "promo_code", "target_id": promo_id},
    )
    assert r.status_code == 200
    entries = r.json()
    assert len(entries) == 1
    assert entries[0]["action"] == "promo.create"


# ── API: stats ────────────────────────────────────────────
@pytest.mark.asyncio
async def test_audit_stats_overview(admin_client: AsyncClient):
    for code in ("STA1", "STA2", "STA3"):
        await admin_client.post(
            "/promo-codes/admin",
            json={"code": code, "type": "percent", "value": 5},
        )

    r = await admin_client.get("/admin/audit/stats/overview")
    assert r.status_code == 200
    data = r.json()
    assert data["total_entries"] >= 3
    actions = {a["action"]: a["count"] for a in data["top_actions"]}
    assert actions.get("promo.create", 0) >= 3


# ── Service-level: captures request provenance ───────────
@pytest.mark.asyncio
async def test_log_action_captures_request_headers():
    """Verify that ``log_action`` copies IP / user-agent / request-id."""
    from tests.conftest import TestSession, _fake_admin

    class _FakeClient:
        host = "10.0.0.5"

    class _FakeRequest:
        client = _FakeClient()
        headers = {
            "user-agent": "pytest/1.0",
            "x-request-id": "req-abc",
            "x-forwarded-for": "203.0.113.1, 10.0.0.5",
        }

        class state:  # noqa: N801  (mimics Request.state)
            pass

    async with TestSession() as db:
        actor = await db.get(_fake_admin.__class__, _fake_admin.id)
        await log_action(
            db, request=_FakeRequest(), actor=actor,
            action="test.capture",
            target_type="noop", target_id=0,
            after={"password": "hunter2", "ok": True},
        )
        await db.commit()

    async with TestSession() as db:
        rows = (
            await db.execute(
                select(AuditLogEntry).where(AuditLogEntry.action == "test.capture")
            )
        ).scalars().all()
        assert len(rows) == 1
        row = rows[0]
        # ``x-forwarded-for`` wins over ``client.host``.
        assert row.ip_address == "203.0.113.1"
        assert row.user_agent == "pytest/1.0"
        assert row.request_id == "req-abc"
        # Secret must be scrubbed.
        assert row.after == {"password": "***", "ok": True}


@pytest.mark.asyncio
async def test_log_action_tolerates_system_actor():
    """A ``None`` actor (webhook / cron) still produces a row."""
    from tests.conftest import TestSession

    async with TestSession() as db:
        await log_action(
            db, request=None, actor=None,
            action="system.tick",
            target_type=None, target_id=None,
            after={"ran": True},
        )
        await db.commit()

    async with TestSession() as db:
        row = (
            await db.execute(
                select(AuditLogEntry).where(AuditLogEntry.action == "system.tick")
            )
        ).scalar_one()
        assert row.actor_id is None
        assert row.actor_email == "system"
