"""Payment model – one row per checkout attempt.

We keep a dedicated table so:
  * a booking can have multiple payment attempts (retry after failure)
  * each gateway's raw payload is preserved for forensic audits
  * different providers (Fawry, Paymob, cash-on-delivery, etc.) plug
    into the same schema
"""

from __future__ import annotations

import enum
from datetime import datetime

from sqlalchemy import (
    JSON,
    DateTime,
    Enum,
    Float,
    ForeignKey,
    String,
    func,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


class PaymentProvider(str, enum.Enum):
    fawry = "fawry"
    paymob = "paymob"
    cod = "cod"          # cash on delivery / pay at check-in


class PaymentMethod(str, enum.Enum):
    """Fine-grained method selected by the customer."""
    card = "card"                 # Visa / MasterCard (Paymob card iframe)
    wallet = "wallet"             # Vodafone Cash, Etisalat Cash, Orange…
    fawry_voucher = "fawry_voucher"  # pay at any Fawry outlet
    instapay = "instapay"
    cod = "cod"


class PaymentState(str, enum.Enum):
    pending = "pending"                      # created, awaiting customer action
    processing = "processing"                # gateway is working on it
    paid = "paid"                            # money received
    failed = "failed"                        # gateway returned an error
    refunded = "refunded"                    # full refund completed
    partially_refunded = "partially_refunded"  # partial (e.g. 50 %) refund
    expired = "expired"                      # checkout window elapsed
    cancelled = "cancelled"                  # user abandoned


class Payment(Base):
    __tablename__ = "payments"

    id: Mapped[int] = mapped_column(primary_key=True, index=True)

    booking_id: Mapped[int] = mapped_column(
        ForeignKey("bookings.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    user_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )

    provider: Mapped[PaymentProvider] = mapped_column(
        Enum(PaymentProvider), nullable=False, index=True
    )
    method: Mapped[PaymentMethod] = mapped_column(
        Enum(PaymentMethod), nullable=False
    )
    state: Mapped[PaymentState] = mapped_column(
        Enum(PaymentState),
        default=PaymentState.pending,
        server_default="pending",
        nullable=False,
        index=True,
    )

    amount: Mapped[float] = mapped_column(Float, nullable=False)
    currency: Mapped[str] = mapped_column(
        String(3), nullable=False, server_default="EGP"
    )

    # Gateway-specific references.
    merchant_ref: Mapped[str] = mapped_column(
        String(64), nullable=False, index=True
    )
    provider_ref: Mapped[str | None] = mapped_column(
        String(100), nullable=True, index=True
    )
    checkout_url: Mapped[str | None] = mapped_column(String(2048), nullable=True)

    # Raw JSON blobs for debugging — never ship these to the client.
    request_payload: Mapped[dict | None] = mapped_column(JSON, nullable=True)
    response_payload: Mapped[dict | None] = mapped_column(JSON, nullable=True)
    error_message: Mapped[str | None] = mapped_column(String(1024), nullable=True)

    # Auto-expire pending payments after this instant.
    expires_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    paid_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
        nullable=False,
    )

    # ── relationships ─────────────────────────────────────────
    booking = relationship("Booking", lazy="selectin")
    user = relationship("User", lazy="selectin")

    def __repr__(self) -> str:
        return (
            f"<Payment id={self.id} booking={self.booking_id} "
            f"provider={self.provider.value} state={self.state.value}>"
        )
