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


# ── Response ──────────────────────────────────────────────
class ReviewOut(BaseModel):
    id: int
    booking_id: int
    property_id: int
    reviewer_id: int
    reviewer: Optional[UserBrief] = None
    rating: float
    comment: Optional[str] = None
    created_at: datetime

    model_config = {"from_attributes": True}
