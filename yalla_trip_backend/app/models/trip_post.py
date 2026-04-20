"""Best-Trip public feed posts.

Any user who has **completed** a booking (payment cleared, check-out
done) can publish a short post about their stay: one or more photos, a
binary verdict ("loved it" / "didn't like it"), and a free-text
caption.  Posts are globally visible on the app's Best-Trip tab so
other travellers can discover great stays.

This model intentionally stays lightweight — no likes/comments (yet);
we ship the read-only feed first and iterate.
"""

from __future__ import annotations

import enum
from datetime import datetime

from sqlalchemy import (
    Boolean, DateTime, Enum, ForeignKey, Integer, String, Text, func,
)
from sqlalchemy.dialects.postgresql import ARRAY
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


class TripVerdict(str, enum.Enum):
    loved = "loved"          # "كانت حلوة"
    disliked = "disliked"    # "مش حلوة"


class TripPost(Base):
    """A user-authored Best-Trip post tied to a completed booking."""
    __tablename__ = "trip_posts"

    id: Mapped[int] = mapped_column(primary_key=True, index=True)

    author_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False, index=True,
    )
    booking_id: Mapped[int] = mapped_column(
        ForeignKey("bookings.id", ondelete="CASCADE"),
        nullable=False, index=True, unique=True,
    )
    property_id: Mapped[int] = mapped_column(
        ForeignKey("properties.id", ondelete="CASCADE"),
        nullable=False, index=True,
    )

    verdict: Mapped[TripVerdict] = mapped_column(
        Enum(TripVerdict),
        nullable=False,
        index=True,
    )
    caption: Mapped[str | None] = mapped_column(Text, nullable=True)

    image_urls: Mapped[list[str]] = mapped_column(
        ARRAY(String), nullable=False, server_default="{}",
    )

    # Admin moderation: hide without deleting.
    is_hidden: Mapped[bool] = mapped_column(
        Boolean, default=False, server_default="false", nullable=False,
    )

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(),
    )

    # Relationships
    author = relationship("User", lazy="selectin")
    booking = relationship("Booking", lazy="selectin")
    property = relationship("Property", lazy="selectin")

    def __repr__(self) -> str:
        return (
            f"<TripPost id={self.id} author={self.author_id} "
            f"verdict={self.verdict.value}>"
        )
