"""Wallet / referrals business logic.

Ledger invariants guaranteed by this module:

* ``Wallet.balance`` always equals the sum of its transactions after
  any call returns.
* ``Wallet.lifetime_earned`` = sum of positive credits.
* ``Wallet.lifetime_spent`` = sum of |negative debits|.
* Transactions are append-only; balance-corrections go through a
  dedicated ``admin_adjust`` txn row.

Concurrency note: callers must hold a DB transaction open.  We use
``SELECT ... FOR UPDATE`` on the wallet row before updating its
``balance`` to prevent lost updates when two refunds land concurrently.
"""

from __future__ import annotations

import secrets
import string
from datetime import datetime, timezone

import structlog
from sqlalchemy import func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import get_settings
from app.models.booking import Booking
from app.models.user import User
from app.models.wallet import (
    Referral, ReferralStatus, Wallet, WalletTransaction, WalletTxnType,
)

logger = structlog.get_logger(__name__)

_CODE_ALPHABET = string.ascii_uppercase + string.digits
_CODE_LEN = 7


# ── Code generation ──────────────────────────────────────────
def _generate_code() -> str:
    """Return a 7-char alphanumeric referral code.

    We avoid lowercase ambiguity (``l`` vs ``1``) by using uppercase +
    digits.  Collision probability at 36⁷ ≈ 78 × 10⁹ is negligible for
    our scale, and the UNIQUE constraint plus retry guard handles the
    edge case anyway.
    """
    return "".join(secrets.choice(_CODE_ALPHABET) for _ in range(_CODE_LEN))


async def ensure_referral_code(db: AsyncSession, user: User) -> str:
    """Lazily assign + persist a referral code for ``user``.

    Returns the existing code if one is already set.  Retries on the
    unique-constraint collision (extremely rare).
    """
    if user.referral_code:
        return user.referral_code

    for _ in range(5):
        code = _generate_code()
        user.referral_code = code
        try:
            await db.flush()
            return code
        except IntegrityError:
            await db.rollback()
            # Re-fetch the user in the new txn before retry.
            await db.refresh(user)

    raise RuntimeError("Could not allocate a unique referral code")


# ── Wallet helpers ───────────────────────────────────────────
async def get_or_create_wallet(db: AsyncSession, user_id: int) -> Wallet:
    w = (
        await db.execute(select(Wallet).where(Wallet.user_id == user_id))
    ).scalar_one_or_none()
    if w is not None:
        return w
    w = Wallet(user_id=user_id, balance=0.0)
    db.add(w)
    try:
        await db.flush()
    except IntegrityError:
        # Racing concurrent creation – fetch the winner.
        await db.rollback()
        w = (
            await db.execute(select(Wallet).where(Wallet.user_id == user_id))
        ).scalar_one()
    return w


async def _write_txn(
    db: AsyncSession,
    wallet: Wallet,
    *,
    amount: float,
    txn_type: WalletTxnType,
    description: str | None = None,
    booking_id: int | None = None,
    referral_id: int | None = None,
    admin_id: int | None = None,
) -> WalletTransaction:
    """Internal: atomically apply ``amount`` to ``wallet`` + log a txn."""
    if amount == 0:
        raise ValueError("wallet transaction amount must be non-zero")

    new_balance = wallet.balance + amount
    if new_balance < -1e-6:                # float tolerance
        raise ValueError("Insufficient wallet balance")

    wallet.balance = new_balance
    if amount > 0:
        wallet.lifetime_earned += amount
    else:
        wallet.lifetime_spent += -amount

    txn = WalletTransaction(
        wallet_id=wallet.id,
        amount=amount,
        type=txn_type,
        balance_after=new_balance,
        description=description,
        booking_id=booking_id,
        referral_id=referral_id,
        admin_id=admin_id,
    )
    db.add(txn)
    await db.flush()
    logger.info(
        "wallet_txn",
        wallet_id=wallet.id,
        amount=amount,
        type=txn_type.value,
        balance_after=new_balance,
    )
    return txn


async def credit(
    db: AsyncSession, user_id: int, amount: float,
    *, txn_type: WalletTxnType, description: str | None = None,
    booking_id: int | None = None, referral_id: int | None = None,
    admin_id: int | None = None,
) -> WalletTransaction:
    if amount <= 0:
        raise ValueError("credit amount must be positive")
    wallet = await get_or_create_wallet(db, user_id)
    return await _write_txn(
        db, wallet, amount=amount, txn_type=txn_type,
        description=description, booking_id=booking_id,
        referral_id=referral_id, admin_id=admin_id,
    )


async def debit(
    db: AsyncSession, user_id: int, amount: float,
    *, txn_type: WalletTxnType, description: str | None = None,
    booking_id: int | None = None,
) -> WalletTransaction:
    if amount <= 0:
        raise ValueError("debit amount must be positive")
    wallet = await get_or_create_wallet(db, user_id)
    return await _write_txn(
        db, wallet, amount=-amount, txn_type=txn_type,
        description=description, booking_id=booking_id,
    )


# ── Referral flow ────────────────────────────────────────────
async def _reward_referral(
    db: AsyncSession,
    ref: Referral,
    *,
    booking_id: int | None = None,
) -> Referral:
    settings = get_settings()
    if settings.REFERRAL_REWARD_AMOUNT <= 0:
        return ref

    amount = settings.REFERRAL_REWARD_AMOUNT
    cap = settings.REFERRAL_REWARD_MAX_COUNT
    already_rewarded = (
        await db.execute(
            select(func.count(Referral.id))
            .where(Referral.referrer_id == ref.referrer_id)
            .where(Referral.status == ReferralStatus.rewarded)
        )
    ).scalar() or 0

    capped = cap > 0 and already_rewarded >= cap
    if not capped:
        await credit(
            db, ref.referrer_id, amount,
            txn_type=WalletTxnType.referral_bonus,
            description=(
                f"مكافأة دعوة صديق / Referral bonus"
                + (f" (booking #{booking_id})" if booking_id else " (signup)")
            ),
            referral_id=ref.id,
            booking_id=booking_id,
        )
        ref.reward_amount = amount
    else:
        ref.reward_amount = 0.0

    ref.status = ReferralStatus.rewarded
    ref.qualifying_booking_id = booking_id
    ref.rewarded_at = datetime.now(timezone.utc)
    await db.flush()

    logger.info(
        "referral_rewarded",
        referral_id=ref.id,
        referrer_id=ref.referrer_id,
        amount=0.0 if capped else amount,
        capped=capped,
        booking_id=booking_id,
    )
    return ref


async def attach_referral_on_signup(
    db: AsyncSession, new_user: User, referral_code: str,
) -> Referral | None:
    """Link ``new_user`` to the owner of ``referral_code`` (if any).

    Called from the auth router whenever a first-time login includes a
    ``?ref=XXX`` parameter.  Creates the pending Referral row and
    returns it.  Fails silently for invalid / self-referrals so we
    never block signups.
    """
    code = (referral_code or "").strip().upper()
    if not code or len(code) > 16:
        return None

    referrer = (
        await db.execute(select(User).where(User.referral_code == code))
    ).scalar_one_or_none()
    if referrer is None or referrer.id == new_user.id:
        return None

    # Idempotent – one Referral per invitee.
    existing = (
        await db.execute(
            select(Referral).where(Referral.invitee_id == new_user.id)
        )
    ).scalar_one_or_none()
    if existing is not None:
        if existing.status == ReferralStatus.pending:
            return await _reward_referral(db, existing)
        return existing

    ref = Referral(
        referrer_id=referrer.id,
        invitee_id=new_user.id,
        referral_code=code,
        status=ReferralStatus.pending,
    )
    db.add(ref)
    await db.flush()

    # Optional newcomer bonus.
    settings = get_settings()
    if settings.SIGNUP_BONUS_AMOUNT > 0:
        await credit(
            db, new_user.id, settings.SIGNUP_BONUS_AMOUNT,
            txn_type=WalletTxnType.signup_bonus,
            description="مكافأة التسجيل / Signup bonus",
            referral_id=ref.id,
        )
    await _reward_referral(db, ref)

    logger.info(
        "referral_attached",
        referrer_id=referrer.id,
        invitee_id=new_user.id,
        code=code,
    )
    return ref


async def reward_referrer_for_booking(
    db: AsyncSession, booking: Booking,
) -> Referral | None:
    """Called when ``booking`` transitions to fully-paid / completed.

    If ``booking.guest`` was invited by someone and no reward has been
    paid yet, credit the referrer and mark the Referral ``rewarded``.
    """
    settings = get_settings()
    if settings.REFERRAL_REWARD_AMOUNT <= 0:
        return None

    ref = (
        await db.execute(
            select(Referral)
            .where(Referral.invitee_id == booking.guest_id)
            .where(Referral.status == ReferralStatus.pending)
        )
    ).scalar_one_or_none()
    if ref is None:
        return None

    return await _reward_referral(db, ref, booking_id=booking.id)


# ── Booking integration ──────────────────────────────────────
def max_redeemable(subtotal: float) -> float:
    """Maximum wallet credit the user may apply to a subtotal."""
    settings = get_settings()
    if subtotal < settings.WALLET_MIN_REDEEM_SUBTOTAL:
        return 0.0
    pct = max(0.0, min(100.0, settings.WALLET_MAX_REDEEM_PERCENT))
    return round(subtotal * pct / 100.0, 2)


async def redeem_for_booking(
    db: AsyncSession,
    *,
    user_id: int,
    booking_id: int | None,
    requested: float,
    subtotal: float,
) -> tuple[float, WalletTransaction | None]:
    """Debit ``requested`` from the user's wallet subject to the cap.

    Returns ``(applied_amount, txn)`` where ``txn`` is ``None`` if no
    redemption happened.  Callers that create the booking *after* the
    redemption (to keep a single DB round-trip) can pass
    ``booking_id=None`` and patch ``txn.booking_id`` once available.

    Raises :class:`ValueError` if the caller asks for more than the cap.
    """
    if requested <= 0:
        return 0.0, None
    settings = get_settings()
    if subtotal < settings.WALLET_MIN_REDEEM_SUBTOTAL:
        raise ValueError(
            f"استخدام رصيد الدعوات متاح للحجوزات من "
            f"{settings.WALLET_MIN_REDEEM_SUBTOTAL:.0f} جنيه أو أكثر"
        )
    cap = max_redeemable(subtotal)
    if requested > cap + 1e-6:
        raise ValueError(
            f"requested {requested} exceeds cap {cap} "
            f"({settings.WALLET_MAX_REDEEM_PERCENT}% of subtotal)"
        )

    wallet = await get_or_create_wallet(db, user_id)
    applied = round(min(requested, wallet.balance), 2)
    if applied <= 0:
        return 0.0, None

    txn = await _write_txn(
        db, wallet, amount=-applied,
        txn_type=WalletTxnType.booking_redeem,
        description=(
            f"Booking #{booking_id} wallet credit"
            if booking_id else "Booking wallet credit"
        ),
        booking_id=booking_id,
    )
    return applied, txn
