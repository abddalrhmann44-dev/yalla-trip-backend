"""Property Pydantic schemas."""

from __future__ import annotations

from datetime import datetime
from typing import List, Optional

from pydantic import BaseModel, Field, model_validator

from app.models.property import Area, Category
from app.schemas.user import UserBrief


# ── Category rule sets ────────────────────────────────────
# Utility fees (electricity, water) & security deposit
_UTILITY_CATEGORIES = {Category.chalet}

# Cleaning fee (housekeeping)
_CLEANING_FEE_CATEGORIES = {Category.chalet, Category.villa, Category.beach_house}

# Multiple bookable rooms
_MULTI_ROOM_CATEGORIES = {Category.hotel, Category.resort}

# Unlimited capacity (no booking limit)
_UNLIMITED_CATEGORIES = {Category.aqua_park, Category.beach_house}

# Supports closing time
_CLOSING_TIME_CATEGORIES = {Category.aqua_park, Category.beach_house}


# ── Service schema ────────────────────────────────────────
AVAILABLE_SERVICES = [
    "باركينج",
    "واي فاي",
    "حمام سباحة",
    "رسوم دخول",
    "مكيف هواء",
    "شواية / BBQ",
    "غسالة",
    "مطبخ",
    "تلفزيون",
    "أمن / حراسة",
    "خدمة نظافة",
    "ألعاب أطفال",
    "جيم",
    "سبا",
    "مطعم",
    "جاكوزي",
    "ملعب رياضي",
    "غرفة ألعاب",
    "مصعد",
    "كراسي شاطئ",
    "تاكسي بحري",
    "سوبر ماركت",
    "صيدلية",
    "غرفة غسيل",
    "خدمة غرف",
]


class PropertyService(BaseModel):
    """A single owner-configurable service."""
    name: str = Field(..., description="Service name from AVAILABLE_SERVICES or custom")
    is_free: bool = Field(True, description="True = مجاني, False = مدفوع")
    price: float = Field(0.0, ge=0, description="Price if not free (ج.م)")

    @model_validator(mode="after")
    def free_means_zero(self) -> "PropertyService":
        if self.is_free:
            self.price = 0.0
        return self


# ── Request schemas ───────────────────────────────────────
class PropertyCreate(BaseModel):
    name: str = Field(..., min_length=3, max_length=200)
    description: Optional[str] = None
    area: Area
    category: Category
    price_per_night: float = Field(..., gt=0)
    weekend_price: Optional[float] = Field(None, gt=0)
    cleaning_fee: float = Field(0.0, ge=0)
    electricity_fee: float = Field(0.0, ge=0)
    water_fee: float = Field(0.0, ge=0)
    security_deposit: float = Field(0.0, ge=0)
    bedrooms: int = Field(1, ge=0)
    bathrooms: int = Field(1, ge=0)
    max_guests: int = Field(4, ge=1)
    total_rooms: int = Field(1, ge=0)
    closing_time: Optional[str] = Field(None, pattern=r"^\d{2}:\d{2}$")
    services: Optional[List[PropertyService]] = []
    amenities: Optional[List[str]] = []
    instant_booking: bool = False
    latitude: Optional[float] = None
    longitude: Optional[float] = None

    @model_validator(mode="after")
    def category_rules(self) -> "PropertyCreate":
        """Enforce category-specific rules."""
        cat = self.category
        # Utility fees & deposit: chalets only
        if cat not in _UTILITY_CATEGORIES:
            self.electricity_fee = 0.0
            self.water_fee = 0.0
            self.security_deposit = 0.0
        # Cleaning fee: chalets, villas, beach houses only
        if cat not in _CLEANING_FEE_CATEGORIES:
            self.cleaning_fee = 0.0
        # Capacity rules
        if cat in _UNLIMITED_CATEGORIES:
            self.total_rooms = 0  # 0 = unlimited
        elif cat not in _MULTI_ROOM_CATEGORIES:
            self.total_rooms = 1
        # Closing time: beaches & aqua parks only
        if cat not in _CLOSING_TIME_CATEGORIES:
            self.closing_time = None
        return self


class PropertyUpdate(BaseModel):
    name: Optional[str] = Field(None, min_length=3, max_length=200)
    description: Optional[str] = None
    area: Optional[Area] = None
    category: Optional[Category] = None
    price_per_night: Optional[float] = Field(None, gt=0)
    weekend_price: Optional[float] = Field(None, gt=0)
    cleaning_fee: Optional[float] = Field(None, ge=0)
    electricity_fee: Optional[float] = Field(None, ge=0)
    water_fee: Optional[float] = Field(None, ge=0)
    security_deposit: Optional[float] = Field(None, ge=0)
    bedrooms: Optional[int] = Field(None, ge=0)
    bathrooms: Optional[int] = Field(None, ge=0)
    max_guests: Optional[int] = Field(None, ge=1)
    total_rooms: Optional[int] = Field(None, ge=0)
    closing_time: Optional[str] = Field(None, pattern=r"^\d{2}:\d{2}$")
    services: Optional[List[PropertyService]] = None
    amenities: Optional[List[str]] = None
    is_available: Optional[bool] = None
    instant_booking: Optional[bool] = None
    latitude: Optional[float] = None
    longitude: Optional[float] = None

    @model_validator(mode="after")
    def category_rules(self) -> "PropertyUpdate":
        """Enforce category-specific rules on update."""
        if self.category is not None:
            cat = self.category
            if cat not in _UTILITY_CATEGORIES:
                self.electricity_fee = 0.0
                self.water_fee = 0.0
                self.security_deposit = 0.0
            if cat not in _CLEANING_FEE_CATEGORIES:
                self.cleaning_fee = 0.0
            if cat in _UNLIMITED_CATEGORIES:
                self.total_rooms = 0
            elif cat not in _MULTI_ROOM_CATEGORIES:
                self.total_rooms = 1
            if cat not in _CLOSING_TIME_CATEGORIES:
                self.closing_time = None
        return self


# ── Filter / Query ────────────────────────────────────────
class PropertyFilter(BaseModel):
    area: Optional[Area] = None
    category: Optional[Category] = None
    min_price: Optional[float] = Field(None, ge=0)
    max_price: Optional[float] = Field(None, ge=0)
    min_rating: Optional[float] = Field(None, ge=0, le=5)
    bedrooms: Optional[int] = Field(None, ge=0)
    max_guests: Optional[int] = Field(None, ge=1)
    instant_booking: Optional[bool] = None
    search: Optional[str] = None
    sort_by: Optional[str] = Field("newest", pattern=r"^(price_asc|price_desc|rating|newest)$")
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    radius_km: Optional[float] = Field(None, gt=0)


# ── Response schemas ──────────────────────────────────────
class PropertyOut(BaseModel):
    id: int
    owner_id: int
    owner: Optional[UserBrief] = None
    name: str
    description: Optional[str] = None
    area: Area
    category: Category
    price_per_night: float
    weekend_price: Optional[float] = None
    cleaning_fee: float
    electricity_fee: float
    water_fee: float
    security_deposit: float
    total_rooms: int
    closing_time: Optional[str] = None
    bedrooms: int
    bathrooms: int
    max_guests: int
    images: Optional[List[str]] = []
    amenities: Optional[List[str]] = []
    services: Optional[List[PropertyService]] = []
    rating: float
    review_count: int
    is_available: bool
    is_featured: bool
    instant_booking: bool
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}


class PropertyBrief(BaseModel):
    """Compact property info for booking responses."""
    id: int
    name: str
    area: Area
    category: Category
    price_per_night: float
    images: Optional[List[str]] = []
    rating: float

    model_config = {"from_attributes": True}
