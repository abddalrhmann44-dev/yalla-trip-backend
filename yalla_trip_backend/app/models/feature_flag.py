"""Feature flags / A-B testing.

Two complementary primitives:

- :class:`FeatureFlag` — a boolean rollout knob the admin can toggle
  on/off, optionally restricted by a percentage (``rollout_percent``)
  or a list of allowlisted user ids.

- :class:`FeatureFlagAssignment` — sticky per-user assignment for a
  given variant, so the same user always sees the same A-B bucket
  even after multiple sessions.

Why a custom table over a third-party SaaS?  We need offline-first
behaviour (server unavailable → flag returns its ``default_value``),
and we need the flag list to be queryable from the admin dashboard
without an extra round trip.  Both come naturally with a small Postgres
table; switching to LaunchDarkly / Unleash later is a one-day port.
"""

from __future__ import annotations

import enum
from datetime import datetime

from sqlalchemy import (
    Boolean,
    DateTime,
    Enum,
    ForeignKey,
    Integer,
    String,
    Text,
    UniqueConstraint,
    func,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


class FlagKind(str, enum.Enum):
    """How the flag behaves at evaluation time."""
    boolean = "boolean"      # simple on/off toggle
    rollout = "rollout"      # rolled out to ``rollout_percent`` of users
    ab_test = "ab_test"      # split traffic across ``variant_a`` / ``variant_b``


class FeatureFlag(Base):
    """A single named knob the admin can toggle for the entire app."""
    __tablename__ = "feature_flags"

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    # Lower-snake-case key referenced by the client (e.g.
    # ``new_search_page_enabled``).  Unique because client code
    # looks it up by name.
    key: Mapped[str] = mapped_column(
        String(100), unique=True, nullable=False, index=True,
    )
    description: Mapped[str | None] = mapped_column(Text, nullable=True)

    kind: Mapped[FlagKind] = mapped_column(
        Enum(FlagKind),
        default=FlagKind.boolean,
        server_default="boolean",
        nullable=False,
    )

    # Whether the flag is currently active at all.  Disabled flags
    # always return their ``default_value``.
    enabled: Mapped[bool] = mapped_column(
        Boolean, default=False, server_default="false", nullable=False,
    )
    default_value: Mapped[bool] = mapped_column(
        Boolean, default=False, server_default="false", nullable=False,
    )

    # 0-100, used when ``kind == rollout`` or ``ab_test``.
    rollout_percent: Mapped[int] = mapped_column(
        Integer, default=0, server_default="0", nullable=False,
    )

    # A-B variant labels (only meaningful when ``kind == ab_test``).
    variant_a: Mapped[str | None] = mapped_column(String(60), nullable=True)
    variant_b: Mapped[str | None] = mapped_column(String(60), nullable=True)

    # Free-form note describing the most recent change — surfaced in
    # the admin UI and audit log.
    last_change_note: Mapped[str | None] = mapped_column(Text, nullable=True)

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False,
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
        nullable=False,
    )
    updated_by: Mapped[int | None] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL"),
        nullable=True, index=True,
    )

    assignments = relationship(
        "FeatureFlagAssignment",
        back_populates="flag",
        cascade="all, delete-orphan",
        lazy="raise",
    )

    def __repr__(self) -> str:
        return (
            f"<FeatureFlag {self.key} kind={self.kind.value} "
            f"enabled={self.enabled} rollout={self.rollout_percent}%>"
        )


class FeatureFlagAssignment(Base):
    """Sticky bucket assignment for a single (user, flag) pair.

    Once assigned, the user always sees the same variant — even if the
    rollout percentage changes — until an admin explicitly resets the
    flag (e.g. by deleting all assignments for a key).
    """
    __tablename__ = "feature_flag_assignments"
    __table_args__ = (
        UniqueConstraint(
            "flag_id", "user_id",
            name="uq_feature_flag_assignment_flag_user",
        ),
    )

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    flag_id: Mapped[int] = mapped_column(
        ForeignKey("feature_flags.id", ondelete="CASCADE"),
        nullable=False, index=True,
    )
    user_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False, index=True,
    )
    # Either "true"/"false" for boolean flags, or the variant label
    # for ab_test flags.  Stored as string for forward-compatibility.
    variant: Mapped[str] = mapped_column(String(60), nullable=False)

    assigned_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False,
    )

    flag = relationship("FeatureFlag", back_populates="assignments")

    def __repr__(self) -> str:
        return (
            f"<FeatureFlagAssignment flag={self.flag_id} "
            f"user={self.user_id} variant={self.variant}>"
        )
