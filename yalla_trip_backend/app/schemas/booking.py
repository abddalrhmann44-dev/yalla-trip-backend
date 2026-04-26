"""Booking Pydantic schemas."""

from __future__ import annotations

from datetime import date, datetime
from typing import Optional

from pydantic import BaseModel, Field, model_validator

from app.models.booking import (
    BookingStatus,
    CashCollectionStatus,
    DepositStatus,
    PaymentStatus,
)
from app.schemas.property import PropertyBrief
from app.schemas.user import UserBrief


# ── Request schemas ───────────────────────────────────────
class BookingCreate(BaseModel):
    property_id: int
    check_in: date
    check_out: date
    guests_count: int = Field(1, ge=1)
    # Wave 8: optional promo code applied at creation time.
    promo_code: Optional[str] = Field(default=None, max_length=32)
    # Wave 11: optional wallet credit requested at checkout.  Capped
    # server-side to min(wallet.balance, subtotal × MAX_REDEEM_PERCENT).
    wallet_amount: float = Field(default=0.0, ge=0)

    @model_validator(mode="after")
    def validate_dates(self) -> "BookingCreate":
        if self.check_out <= self.check_in:
            raise ValueError("تاريخ المغادرة يجب أن يكون بعد تاريخ الوصول / Check-out must be after check-in")
        return self


class BookingCancelRequest(BaseModel):
    reason: Optional[str] = Field(None, max_length=500)


class RefundQuoteOut(BaseModel):
    refundable_percent: int
    refund_amount: float
    platform_fee_refunded: bool
    reason_en: str
    reason_ar: str
    # Echo back the policy so the client can render the right badge.
    cancellation_policy: str


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
    electricity_fee: float
    water_fee: float
    security_deposit: float
    deposit_status: DepositStatus
    total_price: float
    platform_fee: float
    owner_payout: float
    # Wave 25 — hybrid deposit + cash-on-arrival.  When the host
    # didn't enable cash-on-arrival, ``deposit_amount == total_price``
    # and ``remaining_cash_amount == 0`` so the legacy clients keep
    # rendering correctly without any branching.
    deposit_amount: float = 0.0
    remaining_cash_amount: float = 0.0
    cash_collection_status: CashCollectionStatus = CashCollectionStatus.not_applicable
    owner_cash_confirmed_at: Optional[datetime] = None
    guest_arrival_confirmed_at: Optional[datetime] = None
    no_show_reported_at: Optional[datetime] = None
    promo_discount: float = 0.0
    wallet_discount: float = 0.0
    status: BookingStatus
    payment_status: PaymentStatus
    fawry_ref: Optional[str] = None
    refund_amount: Optional[float] = None
    cancelled_at: Optional[datetime] = None
    cancellation_reason: Optional[str] = None
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
