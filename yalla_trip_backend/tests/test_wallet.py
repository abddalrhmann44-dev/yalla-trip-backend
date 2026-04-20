"""Wallet + referral tests.

Covers the core invariants:

* ``GET /wallet/me`` lazily creates a wallet + referral code.
* Admin adjustments credit / debit and are guarded by the balance
  floor.
* Referral attach on signup creates a pending row; a subsequent
  qualifying booking flips it to ``rewarded`` and credits the
  referrer.
* Wallet redemption at checkout is capped by
  ``WALLET_MAX_REDEEM_PERCENT``.
"""

from __future__ import annotations

import uuid
from datetime import date, timedelta

import pytest
from httpx import AsyncClient
from sqlalchemy import select

from app.models.property import (
    Area, Category, Property, PropertyStatus, CancellationPolicy,
)
from app.models.user import User, UserRole
from app.models.wallet import (
    Referral, ReferralStatus, Wallet, WalletTransaction, WalletTxnType,
)
from app.services import wallet_service


# ── helpers ───────────────────────────────────────────────
async def _mk_property(owner_id: int = 2) -> Property:
    from tests.conftest import TestSession
    async with TestSession() as db:
        p = Property(
            owner_id=owner_id,
            name="Wallet Test Villa",
            description="xyz",
            area=Area.north_coast,
            category=Category.villa,
            latitude=31.0, longitude=30.0,
            price_per_night=1000.0,
            max_guests=4, bedrooms=2, bathrooms=2,
            cancellation_policy=CancellationPolicy.moderate,
            status=PropertyStatus.approved,
            is_available=True,
        )
        db.add(p)
        await db.commit()
        await db.refresh(p)
        return p


# ══════════════════════════════════════════════════════════════
#  Wallet basics
# ══════════════════════════════════════════════════════════════
@pytest.mark.asyncio
async def test_get_wallet_lazy_creates(guest_client: AsyncClient):
    r = await guest_client.get("/wallet/me")
    assert r.status_code == 200, r.text
    data = r.json()
    assert data["balance"] == 0
    assert data["referral_code"] is not None
    assert len(data["referral_code"]) == 7
    assert data["recent_transactions"] == []


@pytest.mark.asyncio
async def test_referral_code_stable_across_calls(guest_client: AsyncClient):
    r1 = await guest_client.get("/wallet/me")
    r2 = await guest_client.get("/wallet/me")
    assert r1.json()["referral_code"] == r2.json()["referral_code"]


@pytest.mark.asyncio
async def test_redeem_preview_caps_at_percentage(
    admin_client: AsyncClient, guest_client: AsyncClient,
):
    """Balance 500, subtotal 600 → cap is 50% × 600 = 300."""
    # Admin grants 500 EGP to guest (id=1)
    r = await admin_client.post(
        "/wallet/admin/1/adjust",
        json={"amount": 500.0, "description": "promo credit"},
    )
    assert r.status_code == 200, r.text

    r = await guest_client.post(
        "/wallet/me/redeem/preview", params={"subtotal": 600.0}
    )
    data = r.json()
    assert data["available_balance"] == 500.0
    assert data["max_redeemable"] == 300.0      # capped by percentage


# ══════════════════════════════════════════════════════════════
#  Admin adjustments
# ══════════════════════════════════════════════════════════════
@pytest.mark.asyncio
async def test_admin_credit_writes_audit_entry(admin_client: AsyncClient):
    r = await admin_client.post(
        "/wallet/admin/1/adjust",
        json={"amount": 250.0, "description": "goodwill credit"},
    )
    assert r.status_code == 200
    assert r.json()["balance"] == 250.0

    audits = (await admin_client.get(
        "/admin/audit", params={"action": "wallet.adjust"},
    )).json()
    assert len(audits) == 1
    assert audits[0]["after"]["amount"] == 250.0


@pytest.mark.asyncio
async def test_admin_debit_rejects_when_insufficient(
    admin_client: AsyncClient,
):
    r = await admin_client.post(
        "/wallet/admin/1/adjust",
        json={"amount": -100.0, "description": "can't go below zero"},
    )
    assert r.status_code == 400


@pytest.mark.asyncio
async def test_admin_stats_aggregates_all_wallets(
    admin_client: AsyncClient,
):
    await admin_client.post(
        "/wallet/admin/1/adjust",
        json={"amount": 100.0, "description": "credit"},
    )
    await admin_client.post(
        "/wallet/admin/2/adjust",
        json={"amount": 50.0, "description": "credit"},
    )

    r = await admin_client.get("/wallet/admin/stats")
    assert r.status_code == 200
    s = r.json()
    assert s["total_wallets"] >= 2
    assert s["outstanding_credit"] >= 150.0
    assert s["lifetime_earned"] >= 150.0


# ══════════════════════════════════════════════════════════════
#  Service-layer: referral flow
# ══════════════════════════════════════════════════════════════
@pytest.mark.asyncio
async def test_attach_referral_and_reward():
    """Full flow via the service layer (no HTTP)."""
    from tests.conftest import TestSession, _fake_admin, _fake_owner

    async with TestSession() as db:
        referrer = await db.get(User, _fake_admin.id)
        code = await wallet_service.ensure_referral_code(db, referrer)
        assert len(code) == 7

        # Fake a brand-new invitee row.  Use high IDs to avoid
        # conflicts with the three seeded users (ids 1-3) whose
        # explicit insertion doesn't bump the sequence.
        invitee = User(
            id=101,
            firebase_uid=f"uid_{uuid.uuid4().hex[:12]}",
            name="Invitee",
            email=f"inv_{uuid.uuid4().hex[:6]}@t.com",
            role=UserRole.guest,
        )
        db.add(invitee)
        await db.flush()

        ref = await wallet_service.attach_referral_on_signup(
            db, invitee, code,
        )
        assert ref is not None
        assert ref.status == ReferralStatus.pending
        await db.commit()
        invitee_id = invitee.id
        referrer_id = referrer.id

    # Simulate a qualifying booking for the invitee.
    prop = await _mk_property(owner_id=_fake_owner.id)
    async with TestSession() as db:
        from app.models.booking import Booking, BookingStatus, PaymentStatus
        booking = Booking(
            booking_code="W11REF00",
            property_id=prop.id,
            guest_id=invitee_id,
            owner_id=_fake_owner.id,
            check_in=date.today(),
            check_out=date.today() + timedelta(days=2),
            total_price=2000.0,
            platform_fee=160.0,
            owner_payout=1840.0,
            status=BookingStatus.confirmed,
            payment_status=PaymentStatus.paid,
        )
        db.add(booking)
        await db.flush()
        rewarded = await wallet_service.reward_referrer_for_booking(
            db, booking,
        )
        assert rewarded is not None
        assert rewarded.status == ReferralStatus.rewarded
        assert rewarded.reward_amount == 100.0       # default settings
        await db.commit()

    # Referrer's wallet now carries the bonus.
    async with TestSession() as db:
        wallet = (
            await db.execute(
                select(Wallet).where(Wallet.user_id == referrer_id)
            )
        ).scalar_one()
        assert wallet.balance >= 100.0
        txn = (
            await db.execute(
                select(WalletTransaction)
                .where(WalletTransaction.wallet_id == wallet.id)
                .where(WalletTransaction.type == WalletTxnType.referral_bonus)
            )
        ).scalar_one()
        assert txn.amount == 100.0


@pytest.mark.asyncio
async def test_reward_is_idempotent():
    """Calling ``reward_referrer_for_booking`` twice only pays once."""
    from tests.conftest import TestSession, _fake_owner
    from app.models.booking import Booking, BookingStatus, PaymentStatus

    async with TestSession() as db:
        referrer = User(
            id=201,
            firebase_uid=f"uid_{uuid.uuid4().hex[:12]}",
            name="Ref", email=f"r_{uuid.uuid4().hex[:6]}@t.com",
            role=UserRole.guest,
        )
        invitee = User(
            id=202,
            firebase_uid=f"uid_{uuid.uuid4().hex[:12]}",
            name="Inv", email=f"i_{uuid.uuid4().hex[:6]}@t.com",
            role=UserRole.guest,
        )
        db.add_all([referrer, invitee])
        await db.flush()

        code = await wallet_service.ensure_referral_code(db, referrer)
        ref = await wallet_service.attach_referral_on_signup(
            db, invitee, code,
        )
        assert ref is not None
        await db.commit()
        invitee_id = invitee.id
        referrer_id = referrer.id

    prop = await _mk_property(owner_id=_fake_owner.id)
    async with TestSession() as db:
        booking = Booking(
            booking_code="W11DUP00",
            property_id=prop.id,
            guest_id=invitee_id,
            owner_id=_fake_owner.id,
            check_in=date.today(),
            check_out=date.today() + timedelta(days=1),
            total_price=500.0, platform_fee=40.0, owner_payout=460.0,
            status=BookingStatus.confirmed,
            payment_status=PaymentStatus.paid,
        )
        db.add(booking)
        await db.flush()
        first = await wallet_service.reward_referrer_for_booking(db, booking)
        # Second call should find no pending referrals → no reward.
        second = await wallet_service.reward_referrer_for_booking(db, booking)
        assert first is not None
        assert second is None
        await db.commit()

    async with TestSession() as db:
        wallet = (
            await db.execute(
                select(Wallet).where(Wallet.user_id == referrer_id)
            )
        ).scalar_one()
        # Exactly one referral bonus row.
        txns = (
            await db.execute(
                select(WalletTransaction)
                .where(WalletTransaction.wallet_id == wallet.id)
                .where(WalletTransaction.type == WalletTxnType.referral_bonus)
            )
        ).scalars().all()
        assert len(txns) == 1


# ══════════════════════════════════════════════════════════════
#  Booking integration
# ══════════════════════════════════════════════════════════════
@pytest.mark.asyncio
async def test_booking_applies_wallet_discount(
    admin_client: AsyncClient, guest_client: AsyncClient,
):
    """Create booking with wallet_amount – total drops, ledger debits."""
    prop = await _mk_property()
    await admin_client.post(
        "/wallet/admin/1/adjust",
        json={"amount": 1000.0, "description": "test credit"},
    )

    r = await guest_client.post(
        "/bookings",
        json={
            "property_id": prop.id,
            "check_in": date.today().isoformat(),
            "check_out": (date.today() + timedelta(days=2)).isoformat(),
            "guests_count": 2,
            "wallet_amount": 500.0,       # 50% of 2000 base = max allowed
        },
    )
    assert r.status_code == 201, r.text
    data = r.json()
    assert data["wallet_discount"] == 500.0
    assert data["total_price"] == 1500.0    # 2000 base - 500 wallet

    # Wallet debited, ledger entry linked to booking.
    summary = (await guest_client.get("/wallet/me")).json()
    assert summary["balance"] == 500.0
    assert any(
        t["type"] == "booking_redeem" and t["amount"] == -500.0
        for t in summary["recent_transactions"]
    )


@pytest.mark.asyncio
async def test_booking_rejects_over_cap(guest_client: AsyncClient):
    """Asking for more than the 50% cap must fail with 400."""
    prop = await _mk_property()
    r = await guest_client.post(
        "/bookings",
        json={
            "property_id": prop.id,
            "check_in": date.today().isoformat(),
            "check_out": (date.today() + timedelta(days=2)).isoformat(),
            "guests_count": 2,
            "wallet_amount": 1900.0,      # way over the 50% cap
        },
    )
    assert r.status_code == 400
    assert "cap" in r.json()["detail"].lower()
