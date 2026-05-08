"""Property Pydantic schemas."""

from __future__ import annotations

import re
from datetime import date, datetime
from typing import Any, List, Optional

from pydantic import BaseModel, Field, field_validator, model_validator

from app.models.property import Area, AudienceType, Category, PropertyStatus
from app.schemas.user import UserBrief


# ── Description content guard (Wave 28) ───────────────────
# Owners abuse the description field to drop their phone number or
# WhatsApp / Telegram links so guests can bypass the platform.  Reject
# any payload that matches one of these patterns.  We strip Arabic /
# Western digit variants and zero-width spaces first so the regex can't
# be defeated with ``\u200b`` insertions.
_AR_DIGITS = str.maketrans("٠١٢٣٤٥٦٧٨٩", "0123456789")
_PHONE_RE = re.compile(r"(?:\+?\d[\s\-]?){7,}")
_URL_RE = re.compile(
    r"(?:https?://|www\.|\b\w+\.(?:com|net|org|me|io|app)\b|t\.me/|wa\.me/)",
    re.IGNORECASE,
)


def _validate_description(value: str | None) -> str | None:
    if value is None:
        return None
    # Normalise Arabic digits + remove zero-width / RTL marks before
    # pattern matching so users can't sneak ``+​٢٠١`` past us.
    normalised = (
        value.translate(_AR_DIGITS)
        .replace("\u200b", "")
        .replace("\u200c", "")
        .replace("\u200d", "")
        .replace("\u200e", "")
        .replace("\u200f", "")
    )
    if _URL_RE.search(normalised):
        raise ValueError(
            "ممنوع إضافة روابط في الوصف / Links not allowed in description"
        )
    if _PHONE_RE.search(normalised):
        raise ValueError(
            "ممنوع إضافة أرقام تليفون في الوصف / Phone numbers not allowed in description"
        )
    return value


# ── Category rule sets ────────────────────────────────────
# Utility fees (electricity, water) & security deposit
_UTILITY_CATEGORIES = {Category.chalet}

# Cleaning fee (housekeeping)
_CLEANING_FEE_CATEGORIES = {Category.chalet, Category.villa, Category.day_use}

# Village / compound fees + optional paid parking — chalet & villa only.
# Hotels and resorts must include all of these in the room rate (Wave 28
# spec).
_VILLAGE_PARKING_CATEGORIES = {Category.chalet, Category.villa}

# Multiple bookable rooms
_MULTI_ROOM_CATEGORIES = {Category.hotel, Category.resort}

# Unlimited capacity (no booking limit)
_UNLIMITED_CATEGORIES = {Category.aqua_park, Category.day_use}

# Supports closing time
_CLOSING_TIME_CATEGORIES = {Category.aqua_park, Category.day_use}

# Boats — price is per hour, no rooms, configurable trip duration
_BOAT_CATEGORIES = {Category.boat}

# Day-use bills per-guest, not per-night.
_DAY_USE_CATEGORIES = {Category.day_use}


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
    # Day-use lists may legitimately submit price_per_night = 0 because
    # they bill per-person; relax the constraint to ``ge=0`` and let the
    # category_rules validator enforce the per-category invariant.
    price_per_night: float = Field(..., ge=0)
    weekend_price: Optional[float] = Field(None, ge=0)
    cleaning_fee: float = Field(0.0, ge=0)
    electricity_fee: float = Field(0.0, ge=0)
    water_fee: float = Field(0.0, ge=0)
    village_fees: float = Field(0.0, ge=0)
    parking_is_free: bool = True
    parking_fee: float = Field(0.0, ge=0)
    security_deposit: float = Field(0.0, ge=0)
    bedrooms: int = Field(1, ge=0)
    bathrooms: int = Field(1, ge=0)
    max_guests: int = Field(4, ge=1)
    audience_type: AudienceType = AudienceType.both
    price_per_person: Optional[float] = Field(None, ge=0)
    total_rooms: int = Field(1, ge=0)
    closing_time: Optional[str] = Field(None, pattern=r"^\d{2}:\d{2}$")
    trip_duration_hours: Optional[int] = Field(None, ge=1, le=24)
    services: Optional[List[PropertyService]] = []
    amenities: Optional[List[str]] = []
    amenity_photos: Optional[List[dict]] = None
    nearby_photos: Optional[List[str]] = None
    location_link: Optional[str] = Field(None, max_length=500)
    village_name: Optional[str] = Field(None, max_length=200)
    instant_booking: bool = False
    # Wave 24 — owner opts in to chat-based price negotiation.
    negotiable: bool = False
    # Wave 25 — owner opts in to deposit-online + cash-on-arrival flow.
    # Default True (May 2026) so every booking collects 1-night deposit
    # online and the rest as cash on arrival; hosts can still opt-out.
    cash_on_arrival_enabled: bool = True
    latitude: Optional[float] = None
    longitude: Optional[float] = None

    @field_validator("description")
    @classmethod
    def _description_no_phone_or_links(cls, v: str | None) -> str | None:
        return _validate_description(v)

    @field_validator("location_link")
    @classmethod
    def _location_link_must_be_url(cls, v: str | None) -> str | None:
        if v is None or not v.strip():
            return None
        v = v.strip()
        # Accept http(s), maps.app.goo.gl, goo.gl/maps, google.com/maps.
        if not re.match(r"^https?://", v, re.IGNORECASE):
            raise ValueError(
                "رابط الموقع لازم يبدأ بـ https:// / Location link must be a valid URL"
            )
        return v

    @model_validator(mode="after")
    def category_rules(self) -> "PropertyCreate":
        """Enforce category-specific rules."""
        cat = self.category
        # Utility fees & deposit: chalets only
        if cat not in _UTILITY_CATEGORIES:
            self.electricity_fee = 0.0
            self.water_fee = 0.0
            self.security_deposit = 0.0
        # Cleaning fee: chalets, villas, day-use only
        if cat not in _CLEANING_FEE_CATEGORIES:
            self.cleaning_fee = 0.0
        # Village fees + paid parking: chalets / villas only.  Hotels &
        # resorts must include both in their room rate — anything sent
        # for those categories is silently zero'd out.
        if cat not in _VILLAGE_PARKING_CATEGORIES:
            self.village_fees = 0.0
            self.parking_is_free = True
            self.parking_fee = 0.0
        # Day-use billing: price_per_person required, price_per_night
        # is treated as the per-person rate's mirror so legacy filters
        # (price ranges on the home page) still match these listings.
        if cat in _DAY_USE_CATEGORIES:
            if self.price_per_person is None or self.price_per_person <= 0:
                raise ValueError(
                    "رحلة اليوم الواحد لازم يكون لها سعر للفرد / Day-use needs price_per_person"
                )
            # Mirror the per-person price into price_per_night so the
            # ``min_price`` / ``max_price`` filters and the home-screen
            # cards both keep working without special-casing day-use.
            self.price_per_night = self.price_per_person
            self.weekend_price = None
        else:
            # Non-day-use listings ignore any price_per_person sent by
            # the client to avoid leaking misleading pricing into the
            # detail page.
            self.price_per_person = None
            if self.price_per_night <= 0:
                raise ValueError(
                    "السعر لازم يكون أكبر من صفر / price_per_night must be > 0"
                )
        # Capacity rules
        if cat in _UNLIMITED_CATEGORIES:
            self.total_rooms = 0  # 0 = unlimited
        elif cat not in _MULTI_ROOM_CATEGORIES:
            self.total_rooms = 1
        # Closing time: beaches & aqua parks only
        if cat not in _CLOSING_TIME_CATEGORIES:
            self.closing_time = None
        # Boat specifics — no rooms/bathrooms; duration defaults to 4h.
        # Wave 28: weekend_price is now permitted for boats too (host
        # can charge a higher per-hour rate on Friday/Saturday).
        if cat in _BOAT_CATEGORIES:
            self.bedrooms = 0
            self.bathrooms = 0
            self.total_rooms = 0
            if self.trip_duration_hours is None:
                self.trip_duration_hours = 4
        else:
            self.trip_duration_hours = None
        return self


class PropertyUpdate(BaseModel):
    name: Optional[str] = Field(None, min_length=3, max_length=200)
    description: Optional[str] = None
    area: Optional[Area] = None
    category: Optional[Category] = None
    price_per_night: Optional[float] = Field(None, ge=0)
    weekend_price: Optional[float] = Field(None, ge=0)
    cleaning_fee: Optional[float] = Field(None, ge=0)
    electricity_fee: Optional[float] = Field(None, ge=0)
    water_fee: Optional[float] = Field(None, ge=0)
    village_fees: Optional[float] = Field(None, ge=0)
    parking_is_free: Optional[bool] = None
    parking_fee: Optional[float] = Field(None, ge=0)
    security_deposit: Optional[float] = Field(None, ge=0)
    bedrooms: Optional[int] = Field(None, ge=0)
    bathrooms: Optional[int] = Field(None, ge=0)
    max_guests: Optional[int] = Field(None, ge=1)
    audience_type: Optional[AudienceType] = None
    price_per_person: Optional[float] = Field(None, ge=0)
    total_rooms: Optional[int] = Field(None, ge=0)
    closing_time: Optional[str] = Field(None, pattern=r"^\d{2}:\d{2}$")
    trip_duration_hours: Optional[int] = Field(None, ge=1, le=24)
    services: Optional[List[PropertyService]] = None
    amenities: Optional[List[str]] = None
    amenity_photos: Optional[List[dict]] = None
    nearby_photos: Optional[List[str]] = None
    location_link: Optional[str] = Field(None, max_length=500)
    village_name: Optional[str] = Field(None, max_length=200)
    is_available: Optional[bool] = None
    instant_booking: Optional[bool] = None
    negotiable: Optional[bool] = None
    cash_on_arrival_enabled: Optional[bool] = None
    latitude: Optional[float] = None
    longitude: Optional[float] = None

    @field_validator("description")
    @classmethod
    def _description_no_phone_or_links(cls, v: str | None) -> str | None:
        return _validate_description(v)

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
            if cat not in _VILLAGE_PARKING_CATEGORIES:
                self.village_fees = 0.0
                self.parking_is_free = True
                self.parking_fee = 0.0
            if cat in _UNLIMITED_CATEGORIES:
                self.total_rooms = 0
            elif cat not in _MULTI_ROOM_CATEGORIES:
                self.total_rooms = 1
            if cat not in _CLOSING_TIME_CATEGORIES:
                self.closing_time = None
            if cat not in _DAY_USE_CATEGORIES:
                self.price_per_person = None
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
    sort_by: Optional[str] = Field(
        "best_match",
        pattern=(
            r"^(price_asc|price_desc|rating|newest|"
            r"popularity|distance|best_match)$"
        ),
    )
    amenities: Optional[List[str]] = None
    check_in: Optional[date] = None
    check_out: Optional[date] = None
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
    village_fees: float = 0.0
    parking_is_free: bool = True
    parking_fee: float = 0.0
    security_deposit: float
    total_rooms: int
    closing_time: Optional[str] = None
    trip_duration_hours: Optional[int] = None
    bedrooms: int
    bathrooms: int
    max_guests: int
    audience_type: AudienceType = AudienceType.both
    price_per_person: Optional[float] = None
    location_link: Optional[str] = None
    village_name: Optional[str] = None
    amenity_photos: Optional[List[dict]] = []
    nearby_photos: Optional[List[str]] = []
    id_document_front_url: Optional[str] = None
    id_document_back_url: Optional[str] = None
    images: Optional[List[str]] = []
    amenities: Optional[List[str]] = []
    services: Optional[List[PropertyService]] = []
    rating: float
    review_count: int
    status: PropertyStatus = PropertyStatus.pending
    admin_note: Optional[str] = None
    is_available: bool
    is_featured: bool
    is_verified: bool = False
    instant_booking: bool
    negotiable: bool = False
    cash_on_arrival_enabled: bool = True
    offer_price: Optional[float] = None
    offer_start: Optional[datetime] = None
    offer_end: Optional[datetime] = None
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
