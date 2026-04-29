"""Tests for wallet top-up + 3-referral cap (Wave 21)."""

import pytest
from httpx import AsyncClient
from sqlalchemy import select

from app.config import get_settings
from app.models.user import User
from app.models.wallet import Referral, ReferralStatus, Wallet, WalletTxnType
from app.services import wallet_service
from tests.conftest import TestSession, _fake_user


@pytest.fixture
def anyio_backend():
    return "asyncio"


# ══════════════════════════════════════════════════════════════
#  Wallet top-up
# ══════════════════════════════════════════════════════════════

@pytest.mark.asyncio
async def test_topup_credits_wallet(guest_client: AsyncClient):
    before = await guest_client.get("/wallet/me")
    assert before.status_code == 200
    start = before.json()["balance"]

    resp = await guest_client.post("/wallet/me/topup", json={"amount": 250})
    assert resp.status_code == 200, resp.text
    data = resp.json()
    assert data["balance"] == pytest.approx(start + 250, rel=1e-3)

    # Ledger entry of type topup exists
    assert any(
        t["type"] == "topup" for t in data["recent_transactions"]
    )


@pytest.mark.asyncio
async def test_topup_rejects_invalid_amount(guest_client: AsyncClient):
    resp = await guest_client.post("/wallet/me/topup", json={"amount": 0})
    assert resp.status_code == 422

    resp2 = await guest_client.post("/wallet/me/topup", json={"amount": -5})
    assert resp2.status_code == 422

    resp3 = await guest_client.post("/wallet/me/topup", json={"amount": 99999})
    assert resp3.status_code == 422


@pytest.mark.asyncio
async def test_topup_stores_gateway_reference(guest_client: AsyncClient):
    resp = await guest_client.post("/wallet/me/topup", json={
        "amount": 100,
        "gateway_reference": "paymob_tx_7890",
    })
    assert resp.status_code == 200
    top = resp.json()["recent_transactions"][0]
    assert top["type"] == "topup"
    assert "paymob_tx_7890" in (top.get("description") or "")


@pytest.mark.asyncio
async def test_topup_requires_auth():
    """Unauthenticated requests must be rejected."""
    from httpx import ASGITransport, AsyncClient as _Client
    from app.main import app

    transport = ASGITransport(app=app)
    async with _Client(transport=transport, base_url="http://test") as c:
        resp = await c.post("/wallet/me/topup", json={"amount": 100})
        assert resp.status_code in (401, 403)


# ══════════════════════════════════════════════════════════════
#  Referral 3-reward cap
# ══════════════════════════════════════════════════════════════

async def _make_user(uid: int, name: str) -> int:
    """Insert a test user straight into the DB and return the id."""
    from tests.conftest import _build_user
    async with TestSession() as s:
        u = _build_user(
            id=uid,
            firebase_uid=f"ref-cap-{uid}",
            name=name,
            email=f"refcap{uid}@test.local",
        )
        s.add(u)
        await s.commit()
    return uid


async def _simulate_rewarded_referral(
    referrer_id: int, invitee_id: int,
) -> None:
    """Simulate a signup-driven reward so the referrer's cap advances."""
    async with TestSession() as s:
        ref = Referral(
            referrer_id=referrer_id,
            invitee_id=invitee_id,
            referral_code="CAPCODE",
            status=ReferralStatus.pending,
        )
        s.add(ref)
        await s.flush()
        await wallet_service._reward_referral(s, ref)
        await s.commit()


@pytest.mark.asyncio
async def test_referral_cap_stops_credits_after_3():
    """Referrer stops earning wallet credit after 3 successful referrals."""
    settings = get_settings()
    assert settings.REFERRAL_REWARD_MAX_COUNT == 3, \
        "Test assumes default cap of 3"

    referrer_id = _fake_user.id  # reuse the seeded guest

    # Wallet start balance snapshot
    async with TestSession() as s:
        w = (await s.execute(
            select(Wallet).where(Wallet.user_id == referrer_id)
        )).scalar_one_or_none()
        start_balance = w.balance if w else 0.0

    # Create 4 invitees + drive 4 rewarded signups
    for i in range(4):
        invitee_id = 90_000 + i
        await _make_user(invitee_id, f"Invitee {i}")
        await _simulate_rewarded_referral(referrer_id, invitee_id)

    # Balance should have grown by EXACTLY 3 × reward, not 4.
    async with TestSession() as s:
        w = (await s.execute(
            select(Wallet).where(Wallet.user_id == referrer_id)
        )).scalar_one()
        gained = w.balance - start_balance
        assert gained == pytest.approx(3 * settings.REFERRAL_REWARD_AMOUNT), \
            f"Expected exactly 3×reward, got {gained}"

    # All 4 referral rows should be marked rewarded (cap tracked, not skipped)
    async with TestSession() as s:
        rows = (await s.execute(
            select(Referral).where(Referral.referrer_id == referrer_id)
        )).scalars().all()
        rewarded = [r for r in rows if r.status == ReferralStatus.rewarded]
        assert len(rewarded) >= 4
        # The 4th+ has reward_amount == 0
        zeroed = [r for r in rewarded if (r.reward_amount or 0) == 0]
        assert len(zeroed) >= 1
