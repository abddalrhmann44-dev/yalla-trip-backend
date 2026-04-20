"""Review Pydantic schemas."""

from __future__ import annotations

from datetime import datetime
from typing import Optional

from pydantic import BaseModel, Field

from app.schemas.user import UserBrief


# ── Request ───────────────────────────────────────────────
class ReviewCreate(BaseModel):
    booking_id: int
    rating: float = Field(..., ge=1, le=5)
    comment: Optional[str] = Field(None, max_length=1000)


class OwnerResponseCreate(BaseModel):
    response: str = Field(..., min_length=1, max_length=1000)


# ── Response ──────────────────────────────────────────────
class ReviewOut(BaseModel):
    id: int
    booking_id: int
    property_id: int
    reviewer_id: int
    reviewer: Optional[UserBrief] = None
    rating: float
    comment: Optional[str] = None
    owner_response: Optional[str] = None
    owner_response_at: Optional[datetime] = None
    is_hidden: bool = False
    created_at: datetime

    model_config = {"from_attributes": True}


# ── Pending review summary ───────────────────────────────
class PendingReviewItem(BaseModel):
    booking_id: int
    booking_code: str
    property_id: int
    property_name: str
    property_image: Optional[str] = None
    check_in: datetime
    check_out: datetime
    completed_at: datetime
