"""Review model – one review per completed booking."""

from __future__ import annotations

from datetime import datetime

from sqlalchemy import Boolean, DateTime, Float, ForeignKey, Integer, Text, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


class Review(Base):
    __tablename__ = "reviews"

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    booking_id: Mapped[int] = mapped_column(
        ForeignKey("bookings.id", ondelete="CASCADE"), unique=True, nullable=False
    )
    property_id: Mapped[int] = mapped_column(
        ForeignKey("properties.id", ondelete="CASCADE"), nullable=False, index=True
    )
    reviewer_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )

    rating: Mapped[float] = mapped_column(Float, nullable=False)
    comment: Mapped[str | None] = mapped_column(Text, nullable=True)

    # ── Host reply (Airbnb-style public response) ─────────────
    owner_response: Mapped[str | None] = mapped_column(Text, nullable=True)
    owner_response_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )

    # ── Moderation ────────────────────────────────────────────
    is_hidden: Mapped[bool] = mapped_column(
        Boolean, server_default="false", default=False, nullable=False, index=True
    )
    report_count: Mapped[int] = mapped_column(
        Integer, server_default="0", default=0, nullable=False
    )

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )

    # ── relationships ─────────────────────────────────────────
    booking = relationship("Booking", back_populates="review", lazy="selectin")
    property = relationship("Property", back_populates="reviews", lazy="selectin")
    reviewer = relationship("User", back_populates="reviews", lazy="selectin")

    def __repr__(self) -> str:
        return f"<Review id={self.id} rating={self.rating}>"
