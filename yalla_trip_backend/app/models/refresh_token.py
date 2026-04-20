"""Refresh-token model for rotation + session management.

Each row represents one refresh token issued by ``/auth/verify-token``
or ``/auth/refresh``.  Tokens are rotated on every use:

* A new refresh token (with its own ``jti``) replaces the previous one.
* The old row's ``used_at`` column is stamped so a replay is trivially
  detected.
* Tokens are grouped into *families* via ``family_id`` – when reuse is
  detected (a token already stamped ``used_at`` is presented again)
  we revoke the whole family at once so a stolen token can't be used
  alongside the legitimate one.
"""

from __future__ import annotations

from datetime import datetime

from sqlalchemy import (
    Boolean, DateTime, ForeignKey, Index, String, func,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


class RefreshToken(Base):
    __tablename__ = "refresh_tokens"
    __table_args__ = (
        Index("ix_refresh_tokens_family", "family_id"),
        Index("ix_refresh_tokens_user_active", "user_id", "revoked"),
    )

    id: Mapped[int] = mapped_column(primary_key=True, index=True)

    user_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )

    # JWT ID – the random 128-bit identifier embedded in the refresh
    # token's ``jti`` claim.  The token itself is NOT stored in the DB.
    jti: Mapped[str] = mapped_column(
        String(64), unique=True, index=True, nullable=False
    )

    # All tokens descended from the same original login share a
    # family; compromising any link revokes the whole chain.
    family_id: Mapped[str] = mapped_column(String(64), nullable=False)

    # Stamped when the token is exchanged for a new pair.  Once set,
    # any further presentation of this token is treated as reuse.
    used_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )

    # Hard kill-switch – flipped when admin / user revokes the session,
    # or automatically when reuse is detected on the family.
    revoked: Mapped[bool] = mapped_column(
        Boolean, default=False, server_default="false", nullable=False
    )
    revoked_reason: Mapped[str | None] = mapped_column(
        String(120), nullable=True
    )

    # Optional context for the "sessions" management UI.
    user_agent: Mapped[str | None] = mapped_column(String(256), nullable=True)
    ip_address: Mapped[str | None] = mapped_column(String(64), nullable=True)

    expires_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )

    user = relationship("User", lazy="selectin")

    def __repr__(self) -> str:
        return (
            f"<RefreshToken id={self.id} user={self.user_id} "
            f"jti={self.jti[:8]}... family={self.family_id[:8]}... "
            f"used={self.used_at is not None} revoked={self.revoked}>"
        )
