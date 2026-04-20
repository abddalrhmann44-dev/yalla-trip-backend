"""Favorites router – user wishlist of properties."""

from __future__ import annotations

import structlog
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.middleware.auth_middleware import get_current_active_user
from app.models.favorite import Favorite
from app.models.property import Property
from app.models.user import User
from app.schemas.common import MessageResponse
from app.schemas.property import PropertyOut

logger = structlog.get_logger(__name__)
router = APIRouter(prefix="/favorites", tags=["Favorites"])


@router.get("", response_model=list[PropertyOut])
async def list_favorites(
    user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db),
):
    """Return the current user's favorite properties (full property objects)."""
    stmt = (
        select(Property)
        .join(Favorite, Favorite.property_id == Property.id)
        .where(Favorite.user_id == user.id)
        .order_by(Favorite.created_at.desc())
    )
    rows = (await db.execute(stmt)).scalars().all()
    return [PropertyOut.model_validate(r) for r in rows]


@router.get("/ids", response_model=list[int])
async def list_favorite_ids(
    user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db),
):
    """Return only property IDs — cheap call used by the UI to toggle heart icons."""
    stmt = select(Favorite.property_id).where(Favorite.user_id == user.id)
    rows = (await db.execute(stmt)).scalars().all()
    return list(rows)


@router.post("/{property_id}", response_model=MessageResponse, status_code=status.HTTP_201_CREATED)
async def add_favorite(
    property_id: int,
    user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db),
):
    """Add a property to the current user's favorites (idempotent)."""
    # validate property exists
    exists = (
        await db.execute(select(Property.id).where(Property.id == property_id))
    ).scalar_one_or_none()
    if exists is None:
        raise HTTPException(
            status_code=404, detail="العقار غير موجود / Property not found"
        )

    # idempotent: skip if already favorited
    already = (
        await db.execute(
            select(Favorite.id).where(
                Favorite.user_id == user.id,
                Favorite.property_id == property_id,
            )
        )
    ).scalar_one_or_none()
    if already is not None:
        return MessageResponse(message="Already favorited", message_ar="مضاف بالفعل")

    db.add(Favorite(user_id=user.id, property_id=property_id))
    await db.flush()
    logger.info("favorite_added", user_id=user.id, property_id=property_id)
    return MessageResponse(message="Added to favorites", message_ar="تمت الإضافة للمفضلة")


@router.delete("/{property_id}", response_model=MessageResponse)
async def remove_favorite(
    property_id: int,
    user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db),
):
    """Remove a property from the current user's favorites."""
    result = await db.execute(
        select(Favorite).where(
            Favorite.user_id == user.id,
            Favorite.property_id == property_id,
        )
    )
    row = result.scalar_one_or_none()
    if row is None:
        raise HTTPException(status_code=404, detail="Not in favorites")
    await db.delete(row)
    await db.flush()
    logger.info("favorite_removed", user_id=user.id, property_id=property_id)
    return MessageResponse(message="Removed from favorites", message_ar="تمت الإزالة من المفضلة")
