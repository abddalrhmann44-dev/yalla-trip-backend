"""Payment Pydantic schemas."""

from __future__ import annotations

from datetime import datetime
from typing import Any, Optional

from pydantic import BaseModel, Field

from app.models.payment import PaymentMethod, PaymentProvider, PaymentState


class PaymentInitiateRequest(BaseModel):
    booking_id: int
    provider: PaymentProvider
    method: PaymentMethod
    # Provider/method-specific hints from the client.  Currently used
    # for the wallet flow to disambiguate Vodafone Cash vs Orange Cash
    # vs e& money — Paymob's iframe handles the routing internally so
    # the value is informational, but Kashier and other providers may
    # require it to pick the right integration ID.  Any unexpected
    # keys are forwarded to the gateway as-is and never persisted to
    # the DB outside the audit blob.
    extra: dict[str, Any] = Field(default_factory=dict)


class PaymentInitiateResponse(BaseModel):
    payment_id: int
    provider: PaymentProvider
    method: PaymentMethod
    state: PaymentState
    amount: float
    currency: str = "EGP"
    merchant_ref: str
    provider_ref: Optional[str] = None
    checkout_url: Optional[str] = None
    extra: dict[str, Any] = Field(default_factory=dict)


class PaymentOut(BaseModel):
    id: int
    booking_id: int
    provider: PaymentProvider
    method: PaymentMethod
    state: PaymentState
    amount: float
    currency: str
    merchant_ref: str
    provider_ref: Optional[str] = None
    checkout_url: Optional[str] = None
    error_message: Optional[str] = None
    paid_at: Optional[datetime] = None
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}
