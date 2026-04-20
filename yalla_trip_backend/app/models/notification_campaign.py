"""Admin broadcast notification campaigns.

A campaign lets an admin send a push notification + in-app notification
to a targeted audience (all users, hosts, guests, by area, …).  The
send happens asynchronously via the existing
:func:`app.services.push_service.push_to_user` pipeline, so delivery is
best-effort and unrelated to the request/response cycle.
"""

from __future__ import annotations

import enum
from datetime import datetime

from sqlalchemy import (
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


class CampaignStatus(str, enum.Enum):
    """Lifecycle of a campaign row."""
    draft = "draft"         # saved, not yet sent
    scheduled = "scheduled" # scheduled_at in the future
    sending = "sending"     # currently fanning out
    sent = "sent"           # finished successfully (even with partial failures)
    failed = "failed"       # fan-out aborted (rare – usually misconfig)
    cancelled = "cancelled" # admin cancelled before send


class CampaignAudience(str, enum.Enum):
    """High-level targeting.  Finer targeting uses ``filter_*`` columns."""
    all_users = "all_users"
    hosts = "hosts"          # role == owner
    guests = "guests"        # role == guest
    by_area = "by_area"      # filter_area required
    recent_bookers = "recent_bookers"  # users with bookings in last N days


class NotificationCampaign(Base):
    """A single admin-authored push broadcast."""
    __tablename__ = "notification_campaigns"

    id: Mapped[int] = mapped_column(primary_key=True, index=True)

    created_by: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL"), nullable=True, index=True,
    )

    title_ar: Mapped[str] = mapped_column(String(200), nullable=False)
    title_en: Mapped[str | None] = mapped_column(String(200), nullable=True)
    body_ar: Mapped[str] = mapped_column(Text, nullable=False)
    body_en: Mapped[str | None] = mapped_column(Text, nullable=True)

    # Optional deep-link payload (stringified JSON) stored flat for FCM.
    deeplink: Mapped[str | None] = mapped_column(String(500), nullable=True)

    audience: Mapped[CampaignAudience] = mapped_column(
        Enum(CampaignAudience), nullable=False, index=True,
    )
    filter_area: Mapped[str | None] = mapped_column(String(100), nullable=True)
    filter_recent_days: Mapped[int | None] = mapped_column(Integer, nullable=True)

    status: Mapped[CampaignStatus] = mapped_column(
        Enum(CampaignStatus), nullable=False, default=CampaignStatus.draft,
        index=True,
    )

    scheduled_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True,
    )
    sent_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True,
    )

    # Delivery stats (populated after send)
    target_count: Mapped[int] = mapped_column(Integer, default=0)
    success_count: Mapped[int] = mapped_column(Integer, default=0)

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(),
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now(),
    )

    # Relationships
    author = relationship("User", lazy="selectin")

    def __repr__(self) -> str:
        return (
            f"<NotificationCampaign id={self.id} status={self.status.value} "
            f"audience={self.audience.value}>"
        )
