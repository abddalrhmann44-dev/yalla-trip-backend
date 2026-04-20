"""Smart Pricing router – dynamic pricing suggestions for hosts.

Only the property owner (or admin) can request suggestions.
"""

from __future__ import annotations

from datetime import date, timedelta

import structlog
from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.middleware.auth_middleware import get_current_active_user
from app.models.property import Property
from app.models.user import User, UserRole
from app.services.pricing_intelligence import compute_suggestions

logger = structlog.get_logger(__name__)
router = APIRouter(prefix="/pricing", tags=["Pricing"])


class SuggestionOut(BaseModel):
    date: date
    base_price: float
    suggested_price: float
    multiplier: float
    delta_percent: float
    reasons: list[str]
    area_median: float | None = None


@router.get("/{property_id}/suggestions", response_model=list[SuggestionOut])
async def get_suggestions(
    property_id: int,
    start: date = Query(..., description="First day (inclusive)"),
    end: date = Query(..., description="Last day (exclusive)"),
    user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db),
):
    """Return per-day price suggestions for ``[start, end)``.

    - `start` / `end` form a half-open interval.  Max span = 90 days.
    - Only the property owner (or an admin) can fetch suggestions.
    """
    if end <= start:
        raise HTTPException(status_code=422, detail="end must be after start")
    if (end - start).days > 90:
        raise HTTPException(status_code=422, detail="Range too large (max 90 days)")

    prop = (await db.execute(
        select(Property).where(Property.id == property_id)
    )).scalar_one_or_none()
    if prop is None:
        raise HTTPException(status_code=404, detail="العقار غير موجود / Property not found")
    if prop.owner_id != user.id and user.role != UserRole.admin:
        raise HTTPException(status_code=403, detail="ليس لديك صلاحية / Forbidden")

    suggestions = await compute_suggestions(db, prop, start, end)
    return [
        SuggestionOut(
            date=s.date,
            base_price=s.base_price,
            suggested_price=s.suggested_price,
            multiplier=s.multiplier,
            delta_percent=s.delta_percent,
            reasons=s.reasons,
            area_median=s.area_median,
        )
        for s in suggestions
    ]
