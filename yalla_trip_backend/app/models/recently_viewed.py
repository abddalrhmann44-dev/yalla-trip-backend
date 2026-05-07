"""RecentlyViewed model — per-user log of properties opened in detail view.

Mirrors the ``Favorite`` shape (user × property unique pair) but with a
mutable ``viewed_at`` timestamp.  When a user re-opens a property we
*update* that row's timestamp instead of inserting a duplicate, so the
table stays bounded at one row per (user, property) pair regardless of
how many times the user revisits a listing.
"""

from __future__ import annotations

from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, UniqueConstraint, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


class RecentlyViewed(Base):
    __tablename__ = "recently_viewed"
    __table_args__ = (
        UniqueConstraint(
            "user_id", "property_id", name="uq_recently_viewed_user_property"
        ),
    )

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    user_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    property_id: Mapped[int] = mapped_column(
        ForeignKey("properties.id", ondelete="CASCADE"), nullable=False, index=True
    )

    # ``viewed_at`` is *mutable* — every fresh view bumps this so the
    # GET endpoint can sort by recency without joining anything else.
    viewed_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
        index=True,
    )

    # ── relationships ─────────────────────────────────────────
    user = relationship("User", lazy="selectin")
    property = relationship("Property", lazy="selectin")

    def __repr__(self) -> str:
        return (
            f"<RecentlyViewed user={self.user_id} "
            f"property={self.property_id} at={self.viewed_at}>"
        )
