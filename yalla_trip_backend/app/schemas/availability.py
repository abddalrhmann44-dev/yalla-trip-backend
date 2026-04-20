"""Pydantic schemas for host availability rules."""

from __future__ import annotations

from datetime import date
from typing import Optional

from pydantic import BaseModel, Field, model_validator

from app.models.availability_rule import RuleType


class AvailabilityRuleCreate(BaseModel):
    rule_type: RuleType
    start_date: date
    end_date: date
    price_override: Optional[float] = Field(None, ge=0)
    min_nights: Optional[int] = Field(None, ge=1)
    label: Optional[str] = Field(None, max_length=200)
    note: Optional[str] = None

    @model_validator(mode="after")
    def _validate_dates_and_fields(self):
        if self.end_date <= self.start_date:
            raise ValueError("end_date must be after start_date")
        if self.rule_type == RuleType.pricing and self.price_override is None:
            raise ValueError("price_override required for pricing rules")
        if self.rule_type == RuleType.min_stay and self.min_nights is None:
            raise ValueError("min_nights required for min_stay rules")
        return self


class AvailabilityRuleUpdate(BaseModel):
    start_date: Optional[date] = None
    end_date: Optional[date] = None
    price_override: Optional[float] = Field(None, ge=0)
    min_nights: Optional[int] = Field(None, ge=1)
    label: Optional[str] = Field(None, max_length=200)
    note: Optional[str] = None


class AvailabilityRuleOut(BaseModel):
    id: int
    property_id: int
    rule_type: RuleType
    start_date: date
    end_date: date
    price_override: Optional[float] = None
    min_nights: Optional[int] = None
    label: Optional[str] = None
    note: Optional[str] = None

    model_config = {"from_attributes": True}


class BulkRulesCreate(BaseModel):
    """Create multiple rules at once (calendar editor batch save)."""
    rules: list[AvailabilityRuleCreate] = Field(..., min_length=1, max_length=100)


class BulkDeleteRequest(BaseModel):
    """Delete multiple rules by ID."""
    ids: list[int] = Field(..., min_length=1, max_length=100)


class DayDetail(BaseModel):
    """Single-day view returned by the calendar grid endpoint."""
    date: date
    base_price: float
    effective_price: float
    is_closed: bool = False
    min_nights: int = 1
    is_booked: bool = False
    is_blocked: bool = False  # iCal block
    labels: list[str] = []
