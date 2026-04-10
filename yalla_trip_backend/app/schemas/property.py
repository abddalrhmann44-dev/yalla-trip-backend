"""Property Pydantic schemas."""

from __future__ import annotations

from datetime import datetime
from typing import List, Optional

from pydantic import BaseModel, Field

from app.models.property import Area, Category
from app.schemas.user import UserBrief


# ── Request schemas ───────────────────────────────────────
class PropertyCreate(BaseModel):
    name: str = Field(..., min_length=3, max_length=200)
    description: Optional[str] = None
    area: Area
    category: Category
    price_per_night: float = Field(..., gt=0)
    weekend_price: Optional[float] = Field(None, gt=0)
    cleaning_fee: float = Field(0.0, ge=0)
    bedrooms: int = Field(1, ge=0)
    bathrooms: int = Field(1, ge=0)
    max_guests: int = Field(4, ge=1)
    amenities: Optional[List[str]] = []
    instant_booking: bool = False
    latitude: Optional[float] = None
    longitude: Optional[float] = None


class PropertyUpdate(BaseModel):
    name: Optional[str] = Field(None, min_length=3, max_length=200)
    description: Optional[str] = None
    area: Optional[Area] = None
    category: Optional[Category] = None
    price_per_night: Optional[float] = Field(None, gt=0)
    weekend_price: Optional[float] = Field(None, gt=0)
    cleaning_fee: Optional[float] = Field(None, ge=0)
    bedrooms: Optional[int] = Field(None, ge=0)
    bathrooms: Optional[int] = Field(None, ge=0)
    max_guests: Optional[int] = Field(None, ge=1)
    amenities: Optional[List[str]] = None
    is_available: Optional[bool] = None
    instant_booking: Optional[bool] = None
    latitude: Optional[float] = None
    longitude: Optional[float] = None


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
    bedrooms: int
    bathrooms: int
    max_guests: int
    images: Optional[List[str]] = []
    amenities: Optional[List[str]] = []
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
