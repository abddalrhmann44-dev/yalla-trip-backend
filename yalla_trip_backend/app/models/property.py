"""Property model – chalet / hotel / villa / resort / aqua park / day-use."""

from __future__ import annotations

import enum
from datetime import datetime

from sqlalchemy import (
    Boolean,
    DateTime,
    Enum,
    Float,
    ForeignKey,
    Integer,
    String,
    Text,
    func,
)
from sqlalchemy.dialects.postgresql import ARRAY, JSONB
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


class Area(str, enum.Enum):
    ain_sokhna = "عين السخنة"
    north_coast = "الساحل الشمالي"
    gouna = "الجونة"
    hurghada = "الغردقة"
    sharm = "شرم الشيخ"
    ras_sedr = "رأس سدر"


class Category(str, enum.Enum):
    chalet = "شاليه"
    hotel = "فندق"
    villa = "فيلا"
    resort = "منتجع"
    aqua_park = "أكوا بارك"
    # ``day_use`` covers same-day arrivals/departures — chalet pools,
    # beach passes, etc.  Renamed from ``beach_house`` (Arabic value
    # ``بيت شاطئ``) in Wave 25.5; the DB enum is migrated in
    # Alembic revision ``a3f9_rename_beach_house_to_day_use``.
    day_use = "رحلة يوم واحد"
    boat = "مركب"


class PropertyStatus(str, enum.Enum):
    pending = "pending"
    approved = "approved"
    rejected = "rejected"
    needs_edit = "needs_edit"


class CancellationPolicy(str, enum.Enum):
    """Airbnb-style cancellation tiers.

    The Python values here control the refund calculator in
    ``app.services.cancellation``.  UI labels live in the Flutter client.
    """
    flexible = "flexible"   # 100% refund if > 24h before check-in
    moderate = "moderate"   # 100% > 5d, 50% after
    strict = "strict"       # 100% > 7d, 50% > 24h, 0% within 24h


class Property(Base):
    __tablename__ = "properties"

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    owner_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )

    name: Mapped[str] = mapped_column(String(200), nullable=False)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)

    area: Mapped[Area] = mapped_column(Enum(Area), nullable=False, index=True)
    category: Mapped[Category] = mapped_column(Enum(Category), nullable=False, index=True)

    price_per_night: Mapped[float] = mapped_column(Float, nullable=False)
    weekend_price: Mapped[float | None] = mapped_column(Float, nullable=True)
    cleaning_fee: Mapped[float] = mapped_column(Float, default=0.0, server_default="0")
    electricity_fee: Mapped[float] = mapped_column(Float, default=0.0, server_default="0")
    water_fee: Mapped[float] = mapped_column(Float, default=0.0, server_default="0")
    security_deposit: Mapped[float] = mapped_column(Float, default=0.0, server_default="0")

    total_rooms: Mapped[int] = mapped_column(Integer, default=1, server_default="1")
    closing_time: Mapped[str | None] = mapped_column(String(5), nullable=True)  # HH:MM

    # ── Boat category (Wave 22) ─────────────────────────────
    # Hours per trip for boat listings.  Used only when
    # ``category == Category.boat`` — otherwise NULL.  The pricing
    # semantics for a boat are "price_per_night ≡ price per hour".
    trip_duration_hours: Mapped[int | None] = mapped_column(
        Integer, nullable=True,
    )

    bedrooms: Mapped[int] = mapped_column(Integer, default=1)
    bathrooms: Mapped[int] = mapped_column(Integer, default=1)
    max_guests: Mapped[int] = mapped_column(Integer, default=4)

    images: Mapped[list[str] | None] = mapped_column(
        ARRAY(String(512)), nullable=True, default=list
    )
    amenities: Mapped[list[str] | None] = mapped_column(
        ARRAY(String(100)), nullable=True, default=list
    )
    services: Mapped[list[dict] | None] = mapped_column(
        JSONB, nullable=True, default=list
    )

    rating: Mapped[float] = mapped_column(Float, default=0.0, server_default="0")
    review_count: Mapped[int] = mapped_column(Integer, default=0, server_default="0")

    status: Mapped[PropertyStatus] = mapped_column(
        Enum(PropertyStatus), default=PropertyStatus.pending, server_default="pending"
    )
    admin_note: Mapped[str | None] = mapped_column(Text, nullable=True)

    cancellation_policy: Mapped[CancellationPolicy] = mapped_column(
        Enum(CancellationPolicy),
        default=CancellationPolicy.moderate,
        server_default="moderate",
        nullable=False,
    )

    is_available: Mapped[bool] = mapped_column(Boolean, default=True, server_default="true")
    is_featured: Mapped[bool] = mapped_column(Boolean, default=False, server_default="false")
    instant_booking: Mapped[bool] = mapped_column(Boolean, default=False, server_default="false")

    # ── Negotiation (Wave 24) ─────────────────────────────────
    # Owner-controlled flag: if True, guests see a "فاوض" button on
    # the property page that opens a price-negotiation chat (Wave 23
    # conversation thread).  Off by default so legacy listings keep
    # their fixed-price behaviour until the owner explicitly opts in.
    negotiable: Mapped[bool] = mapped_column(
        Boolean, default=False, server_default="false", nullable=False
    )

    # ── Cash on Arrival (Wave 25) ─────────────────────────────
    # When True the guest pays only an online *deposit* up-front
    # (sized to fully cover the platform commission, but never less
    # than one nightly rate) and settles the remainder in cash with
    # the host on arrival.  When False the booking falls back to the
    # legacy 100%-online flow used since Wave 1.
    #
    # The deposit math lives in ``app/services/pricing.py`` and the
    # double-confirmation workflow (host marks "cash received" + guest
    # marks "arrived & paid") is handled by the booking router.
    cash_on_arrival_enabled: Mapped[bool] = mapped_column(
        Boolean, default=False, server_default="false", nullable=False
    )

    # ── Offers ──────────────────────────────────────────────
    offer_price: Mapped[float | None] = mapped_column(Float, nullable=True)
    offer_start: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    offer_end: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

    latitude: Mapped[float | None] = mapped_column(Float, nullable=True)
    longitude: Mapped[float | None] = mapped_column(Float, nullable=True)

    # ── KYC (owner identity documents) ───────────────────────
    id_document_front_url: Mapped[str | None] = mapped_column(
        String(512), nullable=True
    )
    id_document_back_url: Mapped[str | None] = mapped_column(
        String(512), nullable=True
    )

    # ── iCal export token (Wave 13) ─────────────────────────
    # Opaque, owner-rotatable secret embedded in the public feed URL so
    # the feed is effectively an unguessable capability link.
    ical_token: Mapped[str | None] = mapped_column(
        String(64), nullable=True, unique=True, index=True,
    )

    # ── Verified host badge (Wave 18) ───────────────────────
    # Flipped to True when a PropertyVerification row is approved.
    is_verified: Mapped[bool] = mapped_column(
        Boolean, default=False, server_default="false", nullable=False,
    )

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )

    # ── relationships ─────────────────────────────────────────
    owner = relationship("User", back_populates="properties", lazy="selectin")
    bookings = relationship("Booking", back_populates="property", lazy="selectin")
    reviews = relationship("Review", back_populates="property", lazy="selectin")

    def __repr__(self) -> str:
        return f"<Property id={self.id} name={self.name!r}>"
