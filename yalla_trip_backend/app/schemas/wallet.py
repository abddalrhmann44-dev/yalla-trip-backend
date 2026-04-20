"""Wallet + referral Pydantic schemas."""

from __future__ import annotations

from datetime import datetime

from pydantic import BaseModel, Field

from app.models.wallet import ReferralStatus, WalletTxnType


class WalletTxnOut(BaseModel):
    id: int
    amount: float
    type: WalletTxnType
    balance_after: float
    description: str | None
    booking_id: int | None
    referral_id: int | None
    created_at: datetime

    class Config:
        from_attributes = True


class WalletSummary(BaseModel):
    balance: float
    lifetime_earned: float
    lifetime_spent: float
    referral_code: str | None
    recent_transactions: list[WalletTxnOut]


class WalletAdjustRequest(BaseModel):
    """Admin-only manual correction."""
    amount: float = Field(description="Signed (+credit / −debit) amount in EGP")
    description: str = Field(min_length=3, max_length=500)


class ReferralOut(BaseModel):
    id: int
    invitee_id: int
    invitee_name: str | None
    status: ReferralStatus
    reward_amount: float | None
    rewarded_at: datetime | None
    created_at: datetime


class ReferralSummary(BaseModel):
    referral_code: str
    referral_link: str
    total_referrals: int
    rewarded_count: int
    pending_count: int
    total_earned: float
    referrals: list[ReferralOut]


class WalletRedeemPreview(BaseModel):
    """Client-side hint before the user actually redeems."""
    available_balance: float
    max_redeemable: float
    cap_reason: str | None = None
