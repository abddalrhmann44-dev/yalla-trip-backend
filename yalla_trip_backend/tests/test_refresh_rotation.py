"""Refresh-token rotation + session-management tests."""

from __future__ import annotations

from datetime import datetime, timedelta, timezone

import pytest
from httpx import AsyncClient
from sqlalchemy import select

from app.middleware.auth_middleware import create_refresh_token
from app.models.refresh_token import RefreshToken
from tests.conftest import TestSession, _fake_user


async def _seed_refresh() -> tuple[str, str]:
    """Issue + persist a refresh token row and return (token, jti)."""
    token, jti, fam, expires = create_refresh_token(_fake_user.id)
    async with TestSession() as s:
        s.add(RefreshToken(
            user_id=_fake_user.id,
            jti=jti,
            family_id=fam,
            expires_at=expires,
        ))
        await s.commit()
    return token, jti


@pytest.mark.asyncio
async def test_refresh_rotates_and_stamps_used(guest_client: AsyncClient):
    token, jti = await _seed_refresh()

    resp = await guest_client.post(
        "/auth/refresh", json={"refresh_token": token},
    )
    assert resp.status_code == 200, resp.text
    body = resp.json()
    assert "access_token" in body and "refresh_token" in body
    # New refresh token is different from the old one
    assert body["refresh_token"] != token

    # Original row is now stamped ``used_at``
    async with TestSession() as s:
        row = (
            await s.execute(select(RefreshToken).where(RefreshToken.jti == jti))
        ).scalar_one()
        assert row.used_at is not None
        assert row.revoked is False


@pytest.mark.asyncio
async def test_refresh_reuse_kills_family(guest_client: AsyncClient):
    token, jti = await _seed_refresh()

    first = await guest_client.post(
        "/auth/refresh", json={"refresh_token": token},
    )
    assert first.status_code == 200

    # Replay the *original* token → should fail and revoke the whole family.
    replay = await guest_client.post(
        "/auth/refresh", json={"refresh_token": token},
    )
    assert replay.status_code == 401

    # Every row in the family must now be revoked.
    async with TestSession() as s:
        rows = (
            await s.execute(
                select(RefreshToken).where(RefreshToken.user_id == _fake_user.id)
            )
        ).scalars().all()
        assert rows, "no refresh rows found"
        assert all(r.revoked for r in rows)


@pytest.mark.asyncio
async def test_refresh_rejects_expired_token(guest_client: AsyncClient):
    token, jti, fam, _ = create_refresh_token(_fake_user.id)
    async with TestSession() as s:
        s.add(RefreshToken(
            user_id=_fake_user.id,
            jti=jti,
            family_id=fam,
            # Already expired
            expires_at=datetime.now(timezone.utc) - timedelta(minutes=1),
        ))
        await s.commit()

    # Even though the DB row is expired, the JWT itself is still valid,
    # so the server must be the one that refuses it.
    resp = await guest_client.post(
        "/auth/refresh", json={"refresh_token": token},
    )
    assert resp.status_code == 401


@pytest.mark.asyncio
async def test_refresh_rejects_garbage_token(guest_client: AsyncClient):
    resp = await guest_client.post(
        "/auth/refresh", json={"refresh_token": "not-a-real-jwt"},
    )
    assert resp.status_code == 401


@pytest.mark.asyncio
async def test_sessions_list_and_revoke(guest_client: AsyncClient):
    # Seed two independent sessions ("devices").
    t1, jti1 = await _seed_refresh()
    t2, jti2 = await _seed_refresh()

    resp = await guest_client.get("/auth/sessions")
    assert resp.status_code == 200
    sessions = resp.json()
    assert len(sessions) == 2

    # Revoke the first session — the second must remain active.
    first_id = sessions[0]["id"]
    resp = await guest_client.delete(f"/auth/sessions/{first_id}")
    assert resp.status_code == 200

    resp = await guest_client.get("/auth/sessions")
    assert len(resp.json()) == 1


@pytest.mark.asyncio
async def test_logout_revokes_presented_family(guest_client: AsyncClient):
    token, jti = await _seed_refresh()

    resp = await guest_client.post(
        "/auth/logout", json={"refresh_token": token}
    )
    assert resp.status_code == 200
    assert resp.json()["revoked"] >= 1

    # Subsequent rotation attempt fails.
    rotate = await guest_client.post(
        "/auth/refresh", json={"refresh_token": token}
    )
    assert rotate.status_code == 401
