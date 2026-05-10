"""Marketing promo banners shown on the homepage.

Each banner is a single image + optional title/subtitle pair the
admin can schedule to surface on the public app between two dates.
The Flutter homepage renders the *active* banners (sorted by
``priority``) as a horizontal carousel above the search bar.

Workflow:

- Admin creates a banner with image URL, copy, optional CTA target.
- Admin can preview, then activate; activation is a separate step so
  copywriting mistakes never reach users.
- The public ``GET /promo-banners/active`` endpoint returns the
  banners whose ``is_active=True`` *and* "now" falls inside
  ``start_at``/``end_at`` (if either is set).
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
    func,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


class BannerCtaKind(str, enum.Enum):
    """What happens when a guest taps the banner."""
    none = "none"                # static, no tap
    deeplink = "deeplink"        # opens an in-app route (talaa://...)
    url = "url"                  # opens an external URL in browser
    property = "property"        # opens a specific property page
    area = "area"                # opens area results page


class PromoBanner(Base):
    """A single homepage marketing banner."""
    __tablename__ = "promo_banners"

    id: Mapped[int] = mapped_column(primary_key=True, index=True)

    # Display copy.  Both Arabic and English are stored so the
    # banner localises at render time, not at creation.
    title_ar: Mapped[str | None] = mapped_column(String(200), nullable=True)
    title_en: Mapped[str | None] = mapped_column(String(200), nullable=True)
    subtitle_ar: Mapped[str | None] = mapped_column(String(300), nullable=True)
    subtitle_en: Mapped[str | None] = mapped_column(String(300), nullable=True)

    # The hero image URL — required.  Should be 16:9 or wider for
    # consistent rendering on phone screens.
    image_url: Mapped[str] = mapped_column(String(512), nullable=False)
    # Optional accent colour overlayed on the image (hex, e.g.
    # ``#FF6B35``).  Kept as plain string for forward compat.
    accent_color: Mapped[str | None] = mapped_column(
        String(20), nullable=True,
    )

    cta_kind: Mapped[BannerCtaKind] = mapped_column(
        Enum(BannerCtaKind),
        default=BannerCtaKind.none,
        server_default="none",
        nullable=False,
    )
    # Tap target — meaning depends on ``cta_kind``:
    #   - deeplink → ``talaa://...``
    #   - url      → ``https://...``
    #   - property → numeric property id (string-encoded)
    #   - area     → area name
    cta_target: Mapped[str | None] = mapped_column(
        String(512), nullable=True,
    )

    # Higher = shown first.  Default 0 keeps insertion order.
    priority: Mapped[int] = mapped_column(
        Integer, default=0, server_default="0", nullable=False, index=True,
    )

    is_active: Mapped[bool] = mapped_column(
        Boolean, default=False, server_default="false",
        nullable=False, index=True,
    )

    # Optional scheduling window.  Either side can be NULL (open-
    # ended) and the public endpoint applies the bounds at query time.
    start_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True,
    )
    end_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True,
    )

    # Engagement metrics — incremented by the public app when a user
    # sees / taps the banner.  Best-effort, safely missable.
    impressions: Mapped[int] = mapped_column(
        Integer, default=0, server_default="0", nullable=False,
    )
    clicks: Mapped[int] = mapped_column(
        Integer, default=0, server_default="0", nullable=False,
    )

    created_by: Mapped[int | None] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL"),
        nullable=True, index=True,
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False,
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
        nullable=False,
    )

    creator = relationship(
        "User", foreign_keys=[created_by], lazy="selectin",
    )

    def __repr__(self) -> str:
        return (
            f"<PromoBanner id={self.id} "
            f"title={(self.title_ar or self.title_en)!r} "
            f"active={self.is_active} priority={self.priority}>"
        )
