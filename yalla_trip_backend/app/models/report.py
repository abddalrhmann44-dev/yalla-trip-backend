"""Generic user-report / dispute model.

Users can report *any* entity (property, user, review, booking) and
admins resolve each report from a single queue.  We keep the report
row around after resolution for audit purposes – disputes frequently
require re-reading the original complaint weeks later.
"""

from __future__ import annotations

import enum
from datetime import datetime

from sqlalchemy import (
    DateTime, Enum, ForeignKey, Integer, Text, func,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


class ReportTarget(str, enum.Enum):
    property = "property"
    user = "user"
    review = "review"
    booking = "booking"


class ReportReason(str, enum.Enum):
    spam = "spam"
    inappropriate = "inappropriate"
    fraud = "fraud"
    fake_listing = "fake_listing"
    abuse = "abuse"
    not_as_described = "not_as_described"
    payment_issue = "payment_issue"
    other = "other"


class ReportStatus(str, enum.Enum):
    pending = "pending"
    resolved = "resolved"
    dismissed = "dismissed"


class Report(Base):
    __tablename__ = "reports"

    id: Mapped[int] = mapped_column(primary_key=True, index=True)

    reporter_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False, index=True,
    )

    target_type: Mapped[ReportTarget] = mapped_column(
        Enum(ReportTarget, name="report_target"), nullable=False, index=True
    )
    target_id: Mapped[int] = mapped_column(Integer, nullable=False, index=True)

    reason: Mapped[ReportReason] = mapped_column(
        Enum(ReportReason, name="report_reason"), nullable=False
    )
    details: Mapped[str | None] = mapped_column(Text, nullable=True)

    status: Mapped[ReportStatus] = mapped_column(
        Enum(ReportStatus, name="report_status"),
        default=ReportStatus.pending,
        server_default=ReportStatus.pending.value,
        nullable=False,
        index=True,
    )

    # Admin-facing fields, populated on resolution.
    resolution_notes: Mapped[str | None] = mapped_column(Text, nullable=True)
    resolved_by_id: Mapped[int | None] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL"),
        nullable=True,
    )
    resolved_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )

    # Separate relationships so we can eager-load without ambiguity.
    reporter = relationship("User", foreign_keys=[reporter_id], lazy="selectin")
    resolver = relationship("User", foreign_keys=[resolved_by_id], lazy="selectin")

    def __repr__(self) -> str:
        return (
            f"<Report id={self.id} {self.target_type.value}:"
            f"{self.target_id} status={self.status.value}>"
        )
