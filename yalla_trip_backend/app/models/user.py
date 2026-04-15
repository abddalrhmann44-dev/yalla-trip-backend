"""User model – guest / owner / admin."""

from __future__ import annotations

import enum
from datetime import datetime

from sqlalchemy import Boolean, DateTime, Enum, String, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


class UserRole(str, enum.Enum):
    guest = "guest"
    owner = "owner"
    admin = "admin"


class User(Base):
    __tablename__ = "users"

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    firebase_uid: Mapped[str] = mapped_column(
        String(128), unique=True, index=True, nullable=False
    )
    name: Mapped[str] = mapped_column(String(120), nullable=False)
    email: Mapped[str | None] = mapped_column(
        String(255), unique=True, index=True, nullable=True
    )
    phone: Mapped[str | None] = mapped_column(
        String(20), unique=True, index=True, nullable=True
    )
    role: Mapped[UserRole] = mapped_column(
        Enum(UserRole), default=UserRole.guest, server_default="guest"
    )
    avatar_url: Mapped[str | None] = mapped_column(String(512), nullable=True)
    fcm_token: Mapped[str | None] = mapped_column(String(512), nullable=True)
    is_verified: Mapped[bool] = mapped_column(Boolean, default=False, server_default="false")
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, server_default="true")

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )

    # ── relationships ─────────────────────────────────────────
    properties = relationship("Property", back_populates="owner", lazy="selectin")
    bookings_as_guest = relationship(
        "Booking", back_populates="guest", foreign_keys="Booking.guest_id", lazy="selectin"
    )
    bookings_as_owner = relationship(
        "Booking", back_populates="owner", foreign_keys="Booking.owner_id", lazy="selectin"
    )
    reviews = relationship("Review", back_populates="reviewer", lazy="selectin")
    notifications = relationship("Notification", back_populates="user", lazy="selectin")

    def __repr__(self) -> str:
        return f"<User id={self.id} name={self.name!r} role={self.role.value}>"
