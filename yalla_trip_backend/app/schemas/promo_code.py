"""Promo-code Pydantic schemas."""

from __future__ import annotations

from datetime import datetime

from pydantic import BaseModel, Field, field_validator

from app.models.promo_code import PromoType


# ── Admin-facing ──────────────────────────────────────────
class PromoCodeCreate(BaseModel):
    code: str = Field(min_length=3, max_length=32)
    description: str | None = Field(default=None, max_length=500)
    type: PromoType
    value: float = Field(gt=0)
    max_discount: float | None = Field(default=None, gt=0)
    min_booking_amount: float | None = Field(default=None, ge=0)
    max_uses: int | None = Field(default=None, gt=0)
    max_uses_per_user: int | None = Field(default=None, gt=0)
    valid_from: datetime | None = None
    valid_until: datetime | None = None
    is_active: bool = True

    @field_validator("code")
    @classmethod
    def _normalise_code(cls, v: str) -> str:
        return v.strip().upper()

    @field_validator("value")
    @classmethod
    def _percent_bounds(cls, v: float, info) -> float:
        if info.data.get("type") == PromoType.percent and v > 100:
            raise ValueError("percent value cannot exceed 100")
        return v


class PromoCodeUpdate(BaseModel):
    """Every field optional – partial update."""
    description: str | None = Field(default=None, max_length=500)
    value: float | None = Field(default=None, gt=0)
    max_discount: float | None = Field(default=None, gt=0)
    min_booking_amount: float | None = Field(default=None, ge=0)
    max_uses: int | None = Field(default=None, gt=0)
    max_uses_per_user: int | None = Field(default=None, gt=0)
    valid_from: datetime | None = None
    valid_until: datetime | None = None
    is_active: bool | None = None


class PromoCodeOut(BaseModel):
    id: int
    code: str
    description: str | None
    type: PromoType
    value: float
    max_discount: float | None
    min_booking_amount: float | None
    max_uses: int | None
    max_uses_per_user: int | None
    uses_count: int
    valid_from: datetime | None
    valid_until: datetime | None
    is_active: bool
    created_at: datetime

    class Config:
        from_attributes = True


class PromoRedemptionOut(BaseModel):
    id: int
    promo_id: int
    user_id: int
    booking_id: int
    discount_amount: float
    original_amount: float
    created_at: datetime

    class Config:
        from_attributes = True


# ── User-facing validation ────────────────────────────────
class PromoValidateRequest(BaseModel):
    code: str = Field(min_length=1, max_length=32)
    booking_amount: float = Field(gt=0)

    @field_validator("code")
    @classmethod
    def _normalise(cls, v: str) -> str:
        return v.strip().upper()


class PromoValidateResponse(BaseModel):
    valid: bool
    code: str
    discount_amount: float = 0.0
    final_amount: float
    reason: str | None = None
    reason_ar: str | None = None
