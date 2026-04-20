"""Calendar sync models (Wave 13).

Two tables back the iCal feature:

* ``CalendarImport`` — a remote iCal URL the host has added for a
  given property (Airbnb, Booking.com, VRBO, etc.).  We periodically
  fetch the URL, parse its ``VEVENT`` blocks, and mirror them into
  ``CalendarBlock`` rows so the rest of the codebase only ever has to
  look at one table to determine availability.

* ``CalendarBlock`` — a date range (half-open: ``[start, end)``) during
  which the property is NOT available.  Source can be a manual block
  entered by the owner ("I'm repainting for the weekend") or a row
  mirrored from an imported feed.  We never delete rows out from under
  an owner – when an import is refreshed, blocks it owned are upserted
  by ``external_uid`` and pruned if no longer present.
"""

from __future__ import annotations

import enum
from datetime import date, datetime

from sqlalchemy import (
    Boolean,
    Date,
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


class BlockSource(str, enum.Enum):
    manual = "manual"        # host-entered on our app
    imported = "imported"    # mirrored from a CalendarImport
    booking = "booking"      # materialised from an in-platform booking


class CalendarImport(Base):
    __tablename__ = "calendar_imports"

    id: Mapped[int] = mapped_column(primary_key=True)
    property_id: Mapped[int] = mapped_column(
        ForeignKey("properties.id", ondelete="CASCADE"),
        nullable=False, index=True,
    )
    # The short human label shown in the host UI (e.g. "Airbnb").
    name: Mapped[str] = mapped_column(String(100), nullable=False)
    url: Mapped[str] = mapped_column(String(2048), nullable=False)

    is_active: Mapped[bool] = mapped_column(
        Boolean, default=True, server_default="true", nullable=False,
    )

    last_synced_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True,
    )
    last_error: Mapped[str | None] = mapped_column(
        Text, nullable=True,
    )
    last_event_count: Mapped[int] = mapped_column(
        Integer, default=0, server_default="0", nullable=False,
    )

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(),
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(),
        onupdate=func.now(),
    )

    property = relationship("Property", lazy="selectin")

    def __repr__(self) -> str:
        return f"<CalendarImport id={self.id} property_id={self.property_id}>"


class CalendarBlock(Base):
    __tablename__ = "calendar_blocks"
    __table_args__ = (
        # One import can only contribute one block per external UID.
        UniqueConstraint(
            "import_id", "external_uid",
            name="uq_calblock_import_uid",
        ),
    )

    id: Mapped[int] = mapped_column(primary_key=True)
    property_id: Mapped[int] = mapped_column(
        ForeignKey("properties.id", ondelete="CASCADE"),
        nullable=False, index=True,
    )
    import_id: Mapped[int | None] = mapped_column(
        ForeignKey("calendar_imports.id", ondelete="CASCADE"),
        nullable=True, index=True,
    )

    start_date: Mapped[date] = mapped_column(Date, nullable=False, index=True)
    # Exclusive end (check-out day).
    end_date: Mapped[date] = mapped_column(Date, nullable=False, index=True)

    source: Mapped[BlockSource] = mapped_column(
        Enum(BlockSource), nullable=False,
        default=BlockSource.manual, server_default="manual",
    )

    # Free-text note surfaced to the host in the UI (e.g. "Airbnb #ABC").
    summary: Mapped[str | None] = mapped_column(String(500), nullable=True)
    # Opaque identifier from the source feed; lets us upsert idempotently.
    external_uid: Mapped[str | None] = mapped_column(
        String(500), nullable=True, index=True,
    )

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(),
    )

    def __repr__(self) -> str:
        return (
            f"<CalendarBlock id={self.id} property_id={self.property_id} "
            f"{self.start_date}→{self.end_date} source={self.source.value}>"
        )
