"""Promo-code (coupon) + per-booking redemption models.

An admin creates a **PromoCode** row.  When a guest applies the code
at checkout we validate it, atomically increment ``uses_count``, and
write a **PromoRedemption** row that permanently links the code to
the booking (so we can revoke / refund exactly one redemption without
unwinding the whole code's usage counter).

Two independent caps protect us:
  1. ``max_uses`` – total redemptions *ever* across the platform.
  2. ``max_uses_per_user`` – redemptions per guest (None = unlimited).
"""

from __future__ import annotations

import enum
from datetime import datetime

from sqlalchemy import (
    Boolean, DateTime, Enum, Float, ForeignKey, Integer, String, Text,
    UniqueConstraint, func,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


class PromoType(str, enum.Enum):
    percent = "percent"        # ``value`` is 0-100
    fixed = "fixed"            # ``value`` is an absolute amount in EGP


class PromoCode(Base):
    __tablename__ = "promo_codes"

    id: Mapped[int] = mapped_column(primary_key=True, index=True)

    # Stored upper-cased + trimmed so matching is case-insensitive.
    code: Mapped[str] = mapped_column(
        String(32), unique=True, index=True, nullable=False
    )
    description: Mapped[str | None] = mapped_column(Text, nullable=True)

    type: Mapped[PromoType] = mapped_column(
        Enum(PromoType, name="promo_type"), nullable=False
    )
    # For percent: 0..100.  For fixed: EGP amount (>= 0).
    value: Mapped[float] = mapped_column(Float, nullable=False)
    # Only used when ``type == percent`` – caps the absolute discount.
    max_discount: Mapped[float | None] = mapped_column(Float, nullable=True)

    # Qualification rules.
    min_booking_amount: Mapped[float | None] = mapped_column(Float, nullable=True)

    # Usage limits.
    max_uses: Mapped[int | None] = mapped_column(Integer, nullable=True)
    max_uses_per_user: Mapped[int | None] = mapped_column(Integer, nullable=True)
    uses_count: Mapped[int] = mapped_column(
        Integer, default=0, server_default="0", nullable=False
    )

    # Time window.
    valid_from: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    valid_until: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )

    # Soft-disable flag – admins can deactivate instead of deleting
    # so historical redemptions stay readable.
    is_active: Mapped[bool] = mapped_column(
        Boolean, default=True, server_default="true", nullable=False
    )

    created_by_id: Mapped[int | None] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(),
        onupdate=func.now(), nullable=False,
    )

    redemptions = relationship(
        "PromoRedemption", back_populates="promo", cascade="all, delete-orphan"
    )

    def __repr__(self) -> str:
        return f"<PromoCode {self.code} {self.type.value}:{self.value}>"


class PromoRedemption(Base):
    __tablename__ = "promo_redemptions"
    __table_args__ = (
        # One booking can only ever redeem one code, once.
        UniqueConstraint("booking_id", name="uq_promo_redemption_booking"),
    )

    id: Mapped[int] = mapped_column(primary_key=True, index=True)

    promo_id: Mapped[int] = mapped_column(
        ForeignKey("promo_codes.id", ondelete="CASCADE"),
        nullable=False, index=True,
    )
    user_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False, index=True,
    )
    booking_id: Mapped[int] = mapped_column(
        ForeignKey("bookings.id", ondelete="CASCADE"),
        nullable=False, index=True,
    )

    # Snapshot of the discount at the moment of redemption – the
    # promo row can change later, but a refund must use *this* value.
    discount_amount: Mapped[float] = mapped_column(Float, nullable=False)
    original_amount: Mapped[float] = mapped_column(Float, nullable=False)

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )

    promo = relationship("PromoCode", back_populates="redemptions")

    def __repr__(self) -> str:
        return (
            f"<PromoRedemption promo={self.promo_id} booking={self.booking_id} "
            f"-{self.discount_amount}>"
        )
