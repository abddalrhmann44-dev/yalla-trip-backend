"""Partner / integration API keys.

Keys are minted by an admin and handed to a 3rd-party (e.g. a
property-management system, a partner channel, an internal service
mesh) so they can call our public endpoints without going through the
user-auth flow.

Security model:

- The plaintext key is shown to the admin **once** at creation time
  and never stored.  We persist a SHA-256 hash plus a short
  human-readable prefix (``key_prefix``) for identification.
- Each row has a ``scopes`` column — a list of permission strings
  that limits what the key can do (e.g. ``["properties.read",
  "bookings.read"]``).  No scopes = no access.
- ``revoked_at`` lets the admin disable a key without deleting the
  audit row.  Rotation is a "create new + revoke old" two-step.
- ``last_used_at`` and ``usage_count`` give the dashboard a quick
  liveness signal so unused keys can be cleaned up.
"""

from __future__ import annotations

from datetime import datetime

from sqlalchemy import (
    DateTime,
    ForeignKey,
    Integer,
    String,
    Text,
    func,
)
from sqlalchemy.dialects.postgresql import ARRAY
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


class ApiKey(Base):
    """Hashed partner / integration API key."""
    __tablename__ = "api_keys"

    id: Mapped[int] = mapped_column(primary_key=True, index=True)

    # Human-friendly label shown in the admin dashboard.
    name: Mapped[str] = mapped_column(String(120), nullable=False)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)

    # First 8 characters of the plaintext key.  Lets us identify
    # which row a request belongs to without exposing the secret.
    key_prefix: Mapped[str] = mapped_column(
        String(16), unique=True, nullable=False, index=True,
    )
    # SHA-256 of the full plaintext.  Constant-time comparison only.
    key_hash: Mapped[str] = mapped_column(
        String(128), nullable=False, index=True,
    )

    # Permission strings the key is allowed to use.  See the
    # ``scopes`` enum-like list in
    # ``app/services/api_key_service.py`` for the canonical set.
    scopes: Mapped[list[str]] = mapped_column(
        ARRAY(String), nullable=False, server_default="{}",
    )

    created_by: Mapped[int | None] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL"),
        nullable=True, index=True,
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False,
    )
    expires_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True,
    )
    revoked_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True, index=True,
    )

    # Liveness metrics — updated by the auth middleware on each
    # successful request.  Best-effort; missing updates are not
    # considered a security issue.
    last_used_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True,
    )
    usage_count: Mapped[int] = mapped_column(
        Integer, default=0, server_default="0", nullable=False,
    )

    creator = relationship(
        "User", foreign_keys=[created_by], lazy="selectin",
    )

    def __repr__(self) -> str:
        return (
            f"<ApiKey id={self.id} name={self.name!r} "
            f"prefix={self.key_prefix} revoked={self.revoked_at is not None}>"
        )
