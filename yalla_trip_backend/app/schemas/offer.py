"""Offer Pydantic schemas – time-limited promotional pricing on a property."""

from __future__ import annotations

from datetime import datetime

from pydantic import BaseModel, Field


class OfferCreate(BaseModel):
    offer_price: float = Field(..., gt=0, description="Discounted price per night")
    offer_start: datetime = Field(..., description="Offer start (UTC)")
    offer_end: datetime = Field(..., description="Offer end (UTC)")


class OfferOut(BaseModel):
    property_id: int
    property_name: str
    offer_price: float
    offer_start: datetime
    offer_end: datetime
    original_price: float
    discount_percent: int
    is_active: bool

    model_config = {"from_attributes": False}
