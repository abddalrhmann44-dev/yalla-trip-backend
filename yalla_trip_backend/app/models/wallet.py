"""Store-credit wallet + referrals.

Design
------
* One ``Wallet`` row per user (created lazily on first credit).
* The running ``balance`` is denormalised for cheap reads, but the
  ledger in ``WalletTransaction`` is the source of truth – a balance
  sanity check sums the ledger and rejects any discrepancy.
* Every transaction is **signed**: positive for credits, negative for
  debits.  Refunds, referral payouts, admin corrections, and booking
  redemptions all share this single ledger.
* Referrals use a unique per-user ``referral_code`` copied into new
  signups so we can attribute rewards without exposing user IDs.
* All monetary amounts are stored in EGP (``Float``) to match the
  rest of the codebase.  A future multi-currency wave can swap in
  ``Numeric(14,2)`` + currency column.
"""

from __future__ import annotations

import enum
from datetime import datetime

from sqlalchemy import (
    DateTime, Enum as SAEnum, Float, ForeignKey, Integer, String,
    UniqueConstraint, func,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


class WalletTxnType(str, enum.Enum):
    """Source that produced a wallet ledger entry."""

    referral_bonus = "referral_bonus"     # new user signed up with my code
    signup_bonus = "signup_bonus"          # newcomer reward
    booking_refund = "booking_refund"     # cancellation refund as credit
    booking_redeem = "booking_redeem"      # spent at checkout (negative)
    admin_adjust = "admin_adjust"          # manual correction
    topup = "topup"                        # user-initiated card top-up


class ReferralStatus(str, enum.Enum):
    pending = "pending"       # invitee registered, not yet eligible
    rewarded = "rewarded"     # invitee completed a qualifying booking
    expired = "expired"       # invitee never qualified within the window


class Wallet(Base):
    __tablename__ = "wallets"

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    user_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"),
        unique=True, nullable=False, index=True,
    )
    balance: Mapped[float] = mapped_column(
        Float, nullable=False, default=0.0, server_default="0",
    )
    lifetime_earned: Mapped[float] = mapped_column(
        Float, nullable=False, default=0.0, server_default="0",
    )
    lifetime_spent: Mapped[float] = mapped_column(
        Float, nullable=False, default=0.0, server_default="0",
    )

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(),
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(),
        onupdate=func.now(),
    )

    user = relationship("User", lazy="selectin")
    transactions = relationship(
        "WalletTransaction",
        back_populates="wallet",
        cascade="all, delete-orphan",
        order_by="WalletTransaction.created_at.desc()",
    )


class WalletTransaction(Base):
    __tablename__ = "wallet_transactions"

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    wallet_id: Mapped[int] = mapped_column(
        ForeignKey("wallets.id", ondelete="CASCADE"),
        nullable=False, index=True,
    )
    # Signed amount.  Credit = positive, debit = negative.
    amount: Mapped[float] = mapped_column(Float, nullable=False)

    type: Mapped[WalletTxnType] = mapped_column(
        SAEnum(WalletTxnType, name="wallettxntype"),
        nullable=False, index=True,
    )

    # Denormalised post-txn balance so the client can render a running
    # total without summing the whole ledger client-side.
    balance_after: Mapped[float] = mapped_column(Float, nullable=False)

    description: Mapped[str | None] = mapped_column(String(500), nullable=True)

    # Optional polymorphic pointer for traceability.
    booking_id: Mapped[int | None] = mapped_column(
        ForeignKey("bookings.id", ondelete="SET NULL"), nullable=True, index=True,
    )
    referral_id: Mapped[int | None] = mapped_column(
        ForeignKey("referrals.id", ondelete="SET NULL"), nullable=True, index=True,
    )
    # Admin who performed a manual adjustment.
    admin_id: Mapped[int | None] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL"), nullable=True,
    )

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(),
        nullable=False, index=True,
    )

    wallet = relationship("Wallet", back_populates="transactions")


class Referral(Base):
    """One row per ``(referrer, invitee)`` pair."""

    __tablename__ = "referrals"
    __table_args__ = (
        UniqueConstraint("invitee_id", name="uq_referrals_invitee"),
    )

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    referrer_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False, index=True,
    )
    invitee_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
    )
    referral_code: Mapped[str] = mapped_column(
        String(32), nullable=False, index=True,
    )

    status: Mapped[ReferralStatus] = mapped_column(
        SAEnum(ReferralStatus, name="referralstatus"),
        default=ReferralStatus.pending, server_default=ReferralStatus.pending.value,
        nullable=False, index=True,
    )

    # Reward paid once the invitee completes a qualifying booking.
    reward_amount: Mapped[float | None] = mapped_column(Float, nullable=True)
    qualifying_booking_id: Mapped[int | None] = mapped_column(
        ForeignKey("bookings.id", ondelete="SET NULL"), nullable=True,
    )
    rewarded_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True,
    )

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(),
        nullable=False, index=True,
    )

    referrer = relationship(
        "User", foreign_keys=[referrer_id], lazy="selectin",
    )
    invitee = relationship(
        "User", foreign_keys=[invitee_id], lazy="selectin",
    )
