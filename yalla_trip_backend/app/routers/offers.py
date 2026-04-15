"""Offers router – time-limited promotional pricing on owner properties."""

from __future__ import annotations

from datetime import datetime, timezone

import structlog
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.middleware.auth_middleware import get_current_active_user
from app.models.property import Property
from app.models.user import User
from app.schemas.common import MessageResponse
from app.schemas.offer import OfferCreate, OfferOut
from app.schemas.property import PropertyOut

logger = structlog.get_logger(__name__)
router = APIRouter(prefix="/offers", tags=["Offers"])


def _offer_out(prop: Property) -> OfferOut:
    """Build OfferOut from a property with active offer fields."""
    now = datetime.now(timezone.utc)
    is_active = (
        prop.offer_price is not None
        and prop.offer_start is not None
        and prop.offer_end is not None
        and prop.offer_start <= now <= prop.offer_end
    )
    discount = 0
    if prop.offer_price and prop.price_per_night > 0:
        discount = round(((prop.price_per_night - prop.offer_price) / prop.price_per_night) * 100)
    return OfferOut(
        property_id=prop.id,
        property_name=prop.name,
        offer_price=prop.offer_price or 0,
        offer_start=prop.offer_start or now,
        offer_end=prop.offer_end or now,
        original_price=prop.price_per_night,
        discount_percent=discount,
        is_active=is_active,
    )


@router.get("/my", response_model=list[OfferOut])
async def list_my_offers(
    user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db),
):
    """List all properties owned by the current user that have offer data."""
    stmt = (
        select(Property)
        .where(
            Property.owner_id == user.id,
            Property.offer_price.isnot(None),
        )
        .order_by(Property.offer_end.desc())
    )
    rows = (await db.execute(stmt)).scalars().all()
    return [_offer_out(p) for p in rows]


@router.post("/{property_id}", response_model=OfferOut)
async def create_offer(
    property_id: int,
    body: OfferCreate,
    user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(Property).where(Property.id == property_id, Property.owner_id == user.id)
    )
    prop = result.scalar_one_or_none()
    if prop is None:
        raise HTTPException(status_code=404, detail="Property not found or not yours")

    if body.offer_price >= prop.price_per_night:
        raise HTTPException(
            status_code=400,
            detail="Offer price must be lower than the regular price",
        )
    if body.offer_end <= body.offer_start:
        raise HTTPException(status_code=400, detail="End must be after start")

    prop.offer_price = body.offer_price
    prop.offer_start = body.offer_start
    prop.offer_end = body.offer_end
    await db.flush()
    await db.refresh(prop)
    logger.info("offer_created", property_id=property_id, price=body.offer_price)
    return _offer_out(prop)


@router.delete("/{property_id}", response_model=MessageResponse)
async def cancel_offer(
    property_id: int,
    user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(Property).where(Property.id == property_id, Property.owner_id == user.id)
    )
    prop = result.scalar_one_or_none()
    if prop is None:
        raise HTTPException(status_code=404, detail="Property not found or not yours")

    prop.offer_price = None
    prop.offer_start = None
    prop.offer_end = None
    await db.flush()
    logger.info("offer_cancelled", property_id=property_id)
    return MessageResponse(
        message="Offer removed",
        message_ar="تم إلغاء العرض",
    )
