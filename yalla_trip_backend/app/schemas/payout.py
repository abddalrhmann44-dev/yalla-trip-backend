"""Host payout Pydantic schemas."""

from __future__ import annotations

from datetime import date, datetime

from pydantic import BaseModel, Field, field_validator, model_validator

from app.models.payout import BankAccountType, PayoutStatus


# ══════════════════════════════════════════════════════════════
#  Bank accounts
# ══════════════════════════════════════════════════════════════
class BankAccountCreate(BaseModel):
    type: BankAccountType
    account_name: str = Field(min_length=2, max_length=200)
    bank_name: str | None = Field(default=None, max_length=100)
    iban: str | None = Field(default=None, min_length=15, max_length=34)
    wallet_phone: str | None = Field(default=None, min_length=10, max_length=20)
    instapay_address: str | None = Field(default=None, max_length=100)
    is_default: bool = False

    @field_validator("iban")
    @classmethod
    def _clean_iban(cls, v: str | None) -> str | None:
        if v is None:
            return None
        return v.replace(" ", "").upper()

    @model_validator(mode="after")
    def _one_of(self) -> "BankAccountCreate":
        if self.type == BankAccountType.iban and not self.iban:
            raise ValueError("IBAN is required for bank transfers")
        if self.type == BankAccountType.wallet and not self.wallet_phone:
            raise ValueError("Wallet phone is required")
        if self.type == BankAccountType.instapay and not self.instapay_address:
            raise ValueError("InstaPay address is required")
        return self


class BankAccountUpdate(BaseModel):
    account_name: str | None = Field(default=None, min_length=2, max_length=200)
    bank_name: str | None = Field(default=None, max_length=100)
    is_default: bool | None = None


class BankAccountOut(BaseModel):
    id: int
    host_id: int
    type: BankAccountType
    account_name: str
    bank_name: str | None
    # IBAN / wallet / instapay are masked down to the last 4 chars
    # in responses – never ship a full account number to the client.
    iban_masked: str | None = None
    wallet_phone: str | None = None
    instapay_address: str | None = None
    is_default: bool
    verified: bool
    created_at: datetime

    class Config:
        from_attributes = True

    @classmethod
    def from_model(cls, row) -> "BankAccountOut":
        iban_masked = None
        if row.iban:
            iban_masked = f"•••• {row.iban[-4:]}"
        return cls(
            id=row.id,
            host_id=row.host_id,
            type=row.type,
            account_name=row.account_name,
            bank_name=row.bank_name,
            iban_masked=iban_masked,
            wallet_phone=row.wallet_phone,
            instapay_address=row.instapay_address,
            is_default=row.is_default,
            verified=row.verified,
            created_at=row.created_at,
        )


# ══════════════════════════════════════════════════════════════
#  Payouts
# ══════════════════════════════════════════════════════════════
class PayoutItemOut(BaseModel):
    id: int
    booking_id: int
    amount: float
    booking_code: str | None = None

    class Config:
        from_attributes = True


class PayoutOut(BaseModel):
    id: int
    host_id: int
    bank_account_id: int | None
    total_amount: float
    cycle_start: date
    cycle_end: date
    status: PayoutStatus
    reference_number: str | None
    admin_notes: str | None
    processed_at: datetime | None
    created_at: datetime
    items: list[PayoutItemOut] = []

    class Config:
        from_attributes = True


class PayoutCreateBatch(BaseModel):
    """Admin triggers a payout run covering a date window."""
    cycle_start: date
    cycle_end: date
    # Optional: only pay a specific host (useful for retries).
    host_id: int | None = None

    @model_validator(mode="after")
    def _validate_window(self) -> "PayoutCreateBatch":
        if self.cycle_end < self.cycle_start:
            raise ValueError("cycle_end must be on or after cycle_start")
        return self


class PayoutMarkPaid(BaseModel):
    reference_number: str = Field(min_length=1, max_length=100)
    admin_notes: str | None = Field(default=None, max_length=1000)


class PayoutMarkFailed(BaseModel):
    admin_notes: str = Field(min_length=1, max_length=1000)


class HostPayoutSummary(BaseModel):
    """Host-side dashboard summary."""
    pending_balance: float           # unpaid + queued bookings total
    queued_balance: float            # already inside a pending/processing Payout
    paid_total: float                # lifetime paid
    last_paid_at: datetime | None
    eligible_booking_count: int
