"""Property model – chalet / hotel / villa / resort / aqua park / beach house."""

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
    beach_house = "بيت شاطئ"


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

    is_available: Mapped[bool] = mapped_column(Boolean, default=True, server_default="true")
    is_featured: Mapped[bool] = mapped_column(Boolean, default=False, server_default="false")
    instant_booking: Mapped[bool] = mapped_column(Boolean, default=False, server_default="false")

    latitude: Mapped[float | None] = mapped_column(Float, nullable=True)
    longitude: Mapped[float | None] = mapped_column(Float, nullable=True)

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
