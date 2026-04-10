"""Push-notification log stored per user."""

from __future__ import annotations

import enum
from datetime import datetime

from sqlalchemy import Boolean, DateTime, Enum, ForeignKey, String, Text, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


class NotificationType(str, enum.Enum):
    booking_created = "booking_created"
    booking_confirmed = "booking_confirmed"
    booking_cancelled = "booking_cancelled"
    booking_completed = "booking_completed"
    payment_received = "payment_received"
    review_received = "review_received"
    system = "system"


class Notification(Base):
    __tablename__ = "notifications"

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    user_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )

    title: Mapped[str] = mapped_column(String(200), nullable=False)
    body: Mapped[str] = mapped_column(Text, nullable=False)
    type: Mapped[NotificationType] = mapped_column(
        Enum(NotificationType), default=NotificationType.system
    )
    is_read: Mapped[bool] = mapped_column(Boolean, default=False, server_default="false")

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )

    # ── relationships ─────────────────────────────────────────
    user = relationship("User", back_populates="notifications", lazy="selectin")

    def __repr__(self) -> str:
        return f"<Notification id={self.id} type={self.type.value}>"
