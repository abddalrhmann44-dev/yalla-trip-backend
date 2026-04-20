"""Booking model with pricing, status, and payment tracking."""

from __future__ import annotations

import enum
from datetime import date, datetime

from sqlalchemy import Date, DateTime, Enum, Float, ForeignKey, Integer, String, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


class BookingStatus(str, enum.Enum):
    pending = "pending"
    confirmed = "confirmed"
    cancelled = "cancelled"
    completed = "completed"


class PaymentStatus(str, enum.Enum):
    pending = "pending"
    paid = "paid"
    refunded = "refunded"
    partially_refunded = "partially_refunded"


class DepositStatus(str, enum.Enum):
    held = "held"
    refunded = "refunded"
    deducted = "deducted"


class Booking(Base):
    __tablename__ = "bookings"

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    booking_code: Mapped[str] = mapped_column(
        String(8), unique=True, index=True, nullable=False
    )

    property_id: Mapped[int] = mapped_column(
        ForeignKey("properties.id", ondelete="CASCADE"), nullable=False, index=True
    )
    guest_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    owner_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )

    check_in: Mapped[date] = mapped_column(Date, nullable=False)
    check_out: Mapped[date] = mapped_column(Date, nullable=False)
    guests_count: Mapped[int] = mapped_column(Integer, default=1)

    electricity_fee: Mapped[float] = mapped_column(Float, default=0.0, server_default="0")
    water_fee: Mapped[float] = mapped_column(Float, default=0.0, server_default="0")
    security_deposit: Mapped[float] = mapped_column(Float, default=0.0, server_default="0")
    deposit_status: Mapped[DepositStatus] = mapped_column(
        Enum(DepositStatus), default=DepositStatus.held, server_default="held"
    )

    total_price: Mapped[float] = mapped_column(Float, nullable=False)
    platform_fee: Mapped[float] = mapped_column(Float, nullable=False)
    owner_payout: Mapped[float] = mapped_column(Float, nullable=False)

    # ── Applied promo code (Wave 8) ───────────────────────────
    # The discount is subtracted from ``total_price`` *before* the
    # fee split, so ``platform_fee`` and ``owner_payout`` already
    # reflect the post-discount amount.  ``promo_discount`` is kept
    # around for receipts and analytics.
    promo_discount: Mapped[float] = mapped_column(
        Float, default=0.0, server_default="0", nullable=False
    )

    # ── Wallet credit applied at checkout (Wave 11) ─────────
    # Like ``promo_discount`` this is already subtracted from
    # ``total_price`` – we retain it for the receipt breakdown.
    wallet_discount: Mapped[float] = mapped_column(
        Float, default=0.0, server_default="0", nullable=False
    )

    # ── Host payout state (Wave 9) ────────────────────────────
    # Lives on the booking rather than on a join table so we can
    # filter "which bookings should I include in the next payout
    # batch?" with a single index.
    payout_status: Mapped[str] = mapped_column(
        String(16), default="unpaid", server_default="unpaid", nullable=False,
    )

    status: Mapped[BookingStatus] = mapped_column(
        Enum(BookingStatus), default=BookingStatus.pending, server_default="pending"
    )
    payment_status: Mapped[PaymentStatus] = mapped_column(
        Enum(PaymentStatus), default=PaymentStatus.pending, server_default="pending"
    )

    fawry_ref: Mapped[str | None] = mapped_column(String(100), nullable=True)

    # ── Cancellation / refund metadata ────────────────────────
    refund_amount: Mapped[float | None] = mapped_column(Float, nullable=True)
    cancelled_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    cancellation_reason: Mapped[str | None] = mapped_column(
        String(500), nullable=True
    )

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )

    # ── relationships ─────────────────────────────────────────
    property = relationship("Property", back_populates="bookings", lazy="selectin")
    guest = relationship(
        "User", back_populates="bookings_as_guest", foreign_keys=[guest_id], lazy="selectin"
    )
    owner = relationship(
        "User", back_populates="bookings_as_owner", foreign_keys=[owner_id], lazy="selectin"
    )
    review = relationship("Review", back_populates="booking", uselist=False, lazy="selectin")

    def __repr__(self) -> str:
        return f"<Booking id={self.id} code={self.booking_code!r} status={self.status.value}>"
