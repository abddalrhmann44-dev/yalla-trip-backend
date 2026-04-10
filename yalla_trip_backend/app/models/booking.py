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

    total_price: Mapped[float] = mapped_column(Float, nullable=False)
    platform_fee: Mapped[float] = mapped_column(Float, nullable=False)
    owner_payout: Mapped[float] = mapped_column(Float, nullable=False)

    status: Mapped[BookingStatus] = mapped_column(
        Enum(BookingStatus), default=BookingStatus.pending, server_default="pending"
    )
    payment_status: Mapped[PaymentStatus] = mapped_column(
        Enum(PaymentStatus), default=PaymentStatus.pending, server_default="pending"
    )

    fawry_ref: Mapped[str | None] = mapped_column(String(100), nullable=True)

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
