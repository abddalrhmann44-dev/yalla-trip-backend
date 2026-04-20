"""Pydantic schemas for the chat module."""

from __future__ import annotations

from datetime import date, datetime
from typing import Literal, Optional

from pydantic import BaseModel, Field, model_validator

from app.models.chat import ConversationStatus, MessageKind
from app.schemas.user import UserBrief


# ── Messages ──────────────────────────────────────────────

class MessageCreate(BaseModel):
    body: str = Field(..., min_length=1, max_length=4000)


class MessageOut(BaseModel):
    id: int
    conversation_id: int
    sender_id: int
    kind: MessageKind = MessageKind.text
    body: str
    offer_amount: Optional[float] = None
    booking_id: Optional[int] = None
    read_at: Optional[datetime] = None
    created_at: datetime

    model_config = {"from_attributes": True}


# ── Property & conversation embeds ────────────────────────

class PropertyBrief(BaseModel):
    """Just enough property info to render the inbox row."""
    id: int
    name: str
    first_image: Optional[str] = None

    model_config = {"from_attributes": True}


class ConversationOut(BaseModel):
    id: int
    guest: UserBrief
    owner: UserBrief
    property: Optional[PropertyBrief] = None

    # Booking intent (Wave 23)
    check_in: Optional[date] = None
    check_out: Optional[date] = None
    guests: Optional[int] = None

    # Negotiation state
    status: ConversationStatus = ConversationStatus.open
    latest_offer_amount: Optional[float] = None
    latest_offer_by: Optional[Literal["guest", "owner"]] = None
    booking_id: Optional[int] = None

    last_message_at: Optional[datetime] = None
    last_message_preview: Optional[str] = None
    unread_count: int = 0  # for the current viewer

    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}


class ConversationCreate(BaseModel):
    """Used by a guest to start a price negotiation with a property owner.

    ``check_in`` / ``check_out`` / ``guests`` are now required so both
    sides know the scope of the trip they are negotiating.
    """
    property_id: int
    check_in: date
    check_out: date
    guests: int = Field(..., ge=1, le=50)

    @model_validator(mode="after")
    def _validate_range(self) -> "ConversationCreate":
        if self.check_out <= self.check_in:
            raise ValueError("check_out must be after check_in")
        return self


# ── Negotiation actions ───────────────────────────────────

class OfferBody(BaseModel):
    """Price the sender proposes (EGP per night for chalets, per hour
    for boats)."""
    amount: float = Field(..., gt=0, le=10_000_000)


class PaginatedMessages(BaseModel):
    items: list[MessageOut]
    has_more: bool


class ConversationAccepted(BaseModel):
    """Response of ``POST /chats/{cid}/accept``."""
    conversation: ConversationOut
    booking_id: int
    booking_code: str
    total_price: float
