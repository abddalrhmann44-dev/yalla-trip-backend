"""Device-token model – one row per physical device per user.

Storing the tokens in a dedicated table (instead of the single
``User.fcm_token`` column) buys us:
    * Push to all of a user's devices at once (phone + tablet).
    * Ability to prune stale tokens without affecting the rest of the
      user profile.
    * Platform-aware targeting (``ios`` vs ``android``) in case we
      want to send APNs-specific payloads later.
"""

from __future__ import annotations

import enum
from datetime import datetime

from sqlalchemy import DateTime, Enum, ForeignKey, String, UniqueConstraint, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


class DevicePlatform(str, enum.Enum):
    android = "android"
    ios = "ios"
    web = "web"


class DeviceToken(Base):
    __tablename__ = "device_tokens"
    __table_args__ = (
        UniqueConstraint("user_id", "token", name="uq_device_token_user_token"),
    )

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    user_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    token: Mapped[str] = mapped_column(String(512), nullable=False)
    platform: Mapped[DevicePlatform] = mapped_column(
        Enum(DevicePlatform),
        default=DevicePlatform.android,
        server_default="android",
        nullable=False,
    )
    app_version: Mapped[str | None] = mapped_column(String(32), nullable=True)

    last_seen_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )

    # Back-reference on the User side (see app/models/user.py)
    user = relationship("User", back_populates="devices", lazy="selectin")

    def __repr__(self) -> str:
        return (
            f"<DeviceToken id={self.id} user={self.user_id} "
            f"platform={self.platform.value} token={self.token[:12]}...>"
        )
