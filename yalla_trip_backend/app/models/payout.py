"""Host payout models.

Three moving parts:
  * :class:`HostBankAccount` – where to send a host's money (IBAN or
    mobile-wallet phone).  A host can have several accounts but only
    one is the ``default`` that new payouts target.
  * :class:`Payout`          – a *batch* transfer for one host
    covering one or more completed bookings.  Admin creates batches,
    downloads a CSV, executes the transfers in the bank portal, then
    marks each batch ``paid`` with a bank reference number.
  * :class:`PayoutItem`      – per-booking line inside a Payout.
    ``UniqueConstraint`` on ``booking_id`` guarantees that a booking
    cannot be paid twice.

Booking-side state is tracked by :class:`~app.models.booking.Booking`
via the new ``payout_status`` column (unpaid → queued → paid).
"""

from __future__ import annotations

import enum
from datetime import date, datetime

from sqlalchemy import (
    Boolean, Date, DateTime, Enum, Float, ForeignKey, String, Text,
    UniqueConstraint, func,
)
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


class BankAccountType(str, enum.Enum):
    iban = "iban"            # full bank transfer
    wallet = "wallet"        # Vodafone/Etisalat/Orange Cash
    instapay = "instapay"    # InstaPay address


class PayoutStatus(str, enum.Enum):
    pending = "pending"           # batch drafted, not yet sent to bank
    processing = "processing"     # admin downloaded CSV, transfers in flight
    paid = "paid"                 # bank confirmed, host got the money
    failed = "failed"             # bank rejected — admin will retry


class BookingPayoutStatus(str, enum.Enum):
    unpaid = "unpaid"       # eligible but not yet batched
    queued = "queued"       # currently inside a pending/processing Payout
    paid = "paid"           # Payout succeeded
    blocked = "blocked"     # refund/dispute — not payable


class DisburseStatus(str, enum.Enum):
    """State of the *automated* disbursement leg of a payout.

    Mirrors :class:`PayoutStatus` but tracks the gateway round-trip
    independently — a payout can be ``paid`` from the bookkeeping side
    while the disburse webhook is still ``processing`` (rare, but
    possible if the admin races the gateway).
    """
    not_started = "not_started"   # legacy / manual flow — no gateway call yet
    initiated = "initiated"       # we sent the request, waiting for ack
    processing = "processing"     # gateway accepted, money in flight
    succeeded = "succeeded"       # webhook confirmed delivery
    failed = "failed"             # gateway rejected — admin can retry / fall back


# ════════════════════════════════════════════════════════════════
#  HostBankAccount
# ════════════════════════════════════════════════════════════════
class HostBankAccount(Base):
    __tablename__ = "host_bank_accounts"

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    host_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False, index=True,
    )

    type: Mapped[BankAccountType] = mapped_column(
        Enum(BankAccountType, name="bank_account_type"), nullable=False
    )
    # Display name shown on the payout CSV – e.g. "محمد أحمد".
    account_name: Mapped[str] = mapped_column(String(200), nullable=False)
    # Bank name for IBAN; for wallets this is the telco (e.g. "Vodafone").
    bank_name: Mapped[str | None] = mapped_column(String(100), nullable=True)

    # Exactly one of these is populated based on ``type``.
    iban: Mapped[str | None] = mapped_column(String(34), nullable=True)
    wallet_phone: Mapped[str | None] = mapped_column(String(20), nullable=True)
    instapay_address: Mapped[str | None] = mapped_column(String(100), nullable=True)

    is_default: Mapped[bool] = mapped_column(
        Boolean, default=False, server_default="false", nullable=False
    )
    verified: Mapped[bool] = mapped_column(
        Boolean, default=False, server_default="false", nullable=False
    )

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(),
        onupdate=func.now(), nullable=False,
    )

    host = relationship("User", lazy="selectin")

    def __repr__(self) -> str:  # pragma: no cover
        return f"<HostBankAccount {self.host_id}:{self.type.value}>"


# ════════════════════════════════════════════════════════════════
#  Payout batch + items
# ════════════════════════════════════════════════════════════════
class Payout(Base):
    __tablename__ = "payouts"

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    host_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False, index=True,
    )
    bank_account_id: Mapped[int | None] = mapped_column(
        ForeignKey("host_bank_accounts.id", ondelete="SET NULL"),
        nullable=True,
    )

    # Sum of all item.amount – denormalised for reporting speed.
    total_amount: Mapped[float] = mapped_column(Float, nullable=False)

    # Window used when selecting eligible bookings.  Pure metadata –
    # the actual set is whatever :class:`PayoutItem` rows exist.
    cycle_start: Mapped[date] = mapped_column(Date, nullable=False)
    cycle_end: Mapped[date] = mapped_column(Date, nullable=False)

    status: Mapped[PayoutStatus] = mapped_column(
        Enum(PayoutStatus, name="payout_status"),
        default=PayoutStatus.pending, server_default="pending", nullable=False,
    )

    # Bank reference / wallet transaction id supplied by the admin
    # once the money actually moves.
    reference_number: Mapped[str | None] = mapped_column(String(100), nullable=True)
    admin_notes: Mapped[str | None] = mapped_column(Text, nullable=True)

    # ── Wave 26 — automated disbursement (Kashier / mock) ────
    # ``disburse_provider`` records *which* gateway moved the money so
    # the audit trail can survive a future provider switch.  ``None``
    # means the legacy manual flow handled this batch.
    disburse_provider: Mapped[str | None] = mapped_column(String(40), nullable=True)
    # Gateway-side identifier — Kashier returns it as ``transactionId``.
    # We surface it to the host alongside ``reference_number`` so they
    # can cross-check against their bank/wallet SMS.
    disburse_ref: Mapped[str | None] = mapped_column(String(120), nullable=True)
    disburse_status: Mapped[DisburseStatus] = mapped_column(
        Enum(DisburseStatus, name="disburse_status"),
        default=DisburseStatus.not_started,
        server_default="not_started",
        nullable=False,
    )
    # Timestamp of the *successful* webhook — used for SLA dashboards
    # and to debounce duplicate webhooks (idempotency).
    disbursed_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    # Raw provider payload (request + last webhook) for forensic
    # debugging.  Stored as JSONB so admins can query it from psql.
    disburse_payload: Mapped[dict | None] = mapped_column(JSONB, nullable=True)
    # Optional S3 URL for a PDF / image receipt — populated either by
    # the admin (manual flow) or by the gateway when it returns one.
    disburse_receipt_url: Mapped[str | None] = mapped_column(
        String(500), nullable=True
    )

    processed_by_id: Mapped[int | None] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL"), nullable=True,
    )
    processed_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(),
        onupdate=func.now(), nullable=False,
    )

    host = relationship(
        "User", foreign_keys=[host_id], lazy="selectin"
    )
    bank_account = relationship("HostBankAccount", lazy="selectin")
    items = relationship(
        "PayoutItem", back_populates="payout",
        cascade="all, delete-orphan", lazy="selectin",
    )

    def __repr__(self) -> str:  # pragma: no cover
        return (
            f"<Payout {self.id} host={self.host_id} "
            f"amount={self.total_amount} status={self.status.value}>"
        )


class PayoutItem(Base):
    __tablename__ = "payout_items"
    __table_args__ = (
        UniqueConstraint("booking_id", name="uq_payout_item_booking"),
    )

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    payout_id: Mapped[int] = mapped_column(
        ForeignKey("payouts.id", ondelete="CASCADE"),
        nullable=False, index=True,
    )
    booking_id: Mapped[int] = mapped_column(
        ForeignKey("bookings.id", ondelete="CASCADE"),
        nullable=False, index=True,
    )
    # Snapshot of booking.owner_payout at the time of batching – the
    # booking can still be disputed, but the payout row is frozen.
    amount: Mapped[float] = mapped_column(Float, nullable=False)

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )

    payout = relationship("Payout", back_populates="items")
    booking = relationship("Booking", lazy="selectin")

    def __repr__(self) -> str:  # pragma: no cover
        return f"<PayoutItem payout={self.payout_id} booking={self.booking_id}>"
