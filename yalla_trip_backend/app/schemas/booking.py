"""Booking Pydantic schemas."""

from __future__ import annotations

from datetime import date, datetime
from typing import Optional

from pydantic import BaseModel, Field, model_validator

from app.models.booking import BookingStatus, PaymentStatus
from app.schemas.property import PropertyBrief
from app.schemas.user import UserBrief


# ── Request schemas ───────────────────────────────────────
class BookingCreate(BaseModel):
    property_id: int
    check_in: date
    check_out: date
    guests_count: int = Field(1, ge=1)

    @model_validator(mode="after")
    def validate_dates(self) -> "BookingCreate":
        if self.check_out <= self.check_in:
            raise ValueError("تاريخ المغادرة يجب أن يكون بعد تاريخ الوصول / Check-out must be after check-in")
        return self


# ── Response schemas ──────────────────────────────────────
class BookingOut(BaseModel):
    id: int
    booking_code: str
    property_id: int
    property: Optional[PropertyBrief] = None
    guest_id: int
    guest: Optional[UserBrief] = None
    owner_id: int
    owner: Optional[UserBrief] = None
    check_in: date
    check_out: date
    guests_count: int
    total_price: float
    platform_fee: float
    owner_payout: float
    status: BookingStatus
    payment_status: PaymentStatus
    fawry_ref: Optional[str] = None
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}


class BookingBrief(BaseModel):
    id: int
    booking_code: str
    check_in: date
    check_out: date
    total_price: float
    status: BookingStatus

    model_config = {"from_attributes": True}
