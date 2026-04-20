"""Availability rule model – per-date pricing overrides, min-stay, closed days.

Hosts use these rules to customise pricing and restrictions beyond the
base ``price_per_night`` / ``weekend_price`` on the Property itself.
Rules are date-range based and stack on top of each other with a simple
"latest created wins" conflict-resolution strategy.
"""

from __future__ import annotations

import enum
from datetime import date, datetime

from sqlalchemy import (
    Boolean,
    Date,
    DateTime,
    Enum,
    Float,
    ForeignKey,
    Integer,
    String,
    Text,
    UniqueConstraint,
    func,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


class RuleType(str, enum.Enum):
    """Discriminator for different availability rule kinds."""
    pricing = "pricing"          # Override nightly price
    min_stay = "min_stay"        # Minimum nights required
    closed = "closed"            # Days are completely unavailable
    note = "note"                # Host-only note (no business logic)


class AvailabilityRule(Base):
    """A date-range rule set by the host on one of their properties.

    Examples:
    - "Dec 20–Jan 5 costs 2000 EGP/night" → type=pricing, price_override=2000
    - "Eid week requires minimum 3 nights" → type=min_stay, min_nights=3
    - "Maintenance Feb 1–5" → type=closed
    """
    __tablename__ = "availability_rules"
    __table_args__ = (
        UniqueConstraint(
            "property_id", "start_date", "end_date", "rule_type",
            name="uq_avail_rule_range_type",
        ),
    )

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    property_id: Mapped[int] = mapped_column(
        ForeignKey("properties.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    rule_type: Mapped[RuleType] = mapped_column(
        Enum(RuleType), nullable=False, index=True,
    )

    start_date: Mapped[date] = mapped_column(Date, nullable=False)
    end_date: Mapped[date] = mapped_column(Date, nullable=False)

    # pricing override (only used when rule_type == "pricing")
    price_override: Mapped[float | None] = mapped_column(Float, nullable=True)

    # minimum stay (only used when rule_type == "min_stay")
    min_nights: Mapped[int | None] = mapped_column(Integer, nullable=True)

    # optional label / internal note
    label: Mapped[str | None] = mapped_column(String(200), nullable=True)
    note: Mapped[str | None] = mapped_column(Text, nullable=True)

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )

    # ── Relationships ──────────────────────────────────────────
    property = relationship("Property", lazy="selectin")

    def __repr__(self) -> str:
        return (
            f"<AvailabilityRule id={self.id} prop={self.property_id} "
            f"type={self.rule_type.value} {self.start_date}–{self.end_date}>"
        )
