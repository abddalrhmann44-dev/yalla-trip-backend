"""Recently-Viewed router — per-user log of properties opened in detail.

Two endpoints:
  • ``POST /recently-viewed/{property_id}`` — fire-and-forget upsert
    called from the property-details page on every open.  Cheap and
    idempotent: revisits bump ``viewed_at`` instead of inserting.
  • ``GET  /recently-viewed`` — returns the last N (default 10) full
    property objects sorted by ``viewed_at`` desc, ready to render in
    the home carousel.

To keep the table bounded we trim anything past the per-user cap on
every insert (oldest row evicted when the user crosses the cap).  This
keeps the most-frequent travellers from ballooning the table while
still giving them a useful history window.
"""

from __future__ import annotations

import structlog
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import delete, select
from sqlalchemy.dialects.postgresql import insert as pg_insert
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.sql import func

from app.database import get_db
from app.middleware.auth_middleware import get_current_active_user
from app.models.property import Property
from app.models.recently_viewed import RecentlyViewed
from app.models.user import User
from app.schemas.common import MessageResponse
from app.schemas.property import PropertyOut

logger = structlog.get_logger(__name__)
router = APIRouter(prefix="/recently-viewed", tags=["Recently Viewed"])

# Per-user cap — anything older than this many rows gets evicted on
# the next insert.  20 strikes a reasonable balance between giving the
# user a generous history and keeping the table from ballooning.
_MAX_PER_USER = 20


@router.get("", response_model=list[PropertyOut])
async def list_recently_viewed(
    limit: int = Query(10, ge=1, le=50),
    user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db),
):
    """Return the user's most-recently-viewed properties (newest first)."""
    stmt = (
        select(Property)
        .join(RecentlyViewed, RecentlyViewed.property_id == Property.id)
        .where(RecentlyViewed.user_id == user.id)
        .order_by(RecentlyViewed.viewed_at.desc())
        .limit(limit)
    )
    rows = (await db.execute(stmt)).scalars().all()
    return [PropertyOut.model_validate(r) for r in rows]


@router.post(
    "/{property_id}",
    response_model=MessageResponse,
    status_code=status.HTTP_200_OK,
)
async def mark_recently_viewed(
    property_id: int,
    user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db),
):
    """Record (or refresh) a 'this user viewed this property' entry.

    Implemented as a Postgres ``INSERT ... ON CONFLICT DO UPDATE`` so a
    re-view is a single round-trip and never races with itself.  The
    user can never see their own listings in this carousel — owners
    opening their own property to preview it shouldn't pollute their
    history — so we silently no-op for self-views.
    """
    # Validate property exists *and* fetch owner_id so we can short-
    # circuit owner self-views in a single query.
    row = (
        await db.execute(
            select(Property.id, Property.owner_id).where(Property.id == property_id)
        )
    ).first()
    if row is None:
        raise HTTPException(
            status_code=404, detail="العقار غير موجود / Property not found"
        )

    if row.owner_id == user.id:
        # Owner previewing their own listing — keep history clean.
        return MessageResponse(message="Skipped (own listing)", message_ar="تم التجاهل")

    # Upsert: bump ``viewed_at`` if the row already exists.
    stmt = (
        pg_insert(RecentlyViewed)
        .values(user_id=user.id, property_id=property_id)
        .on_conflict_do_update(
            constraint="uq_recently_viewed_user_property",
            set_={"viewed_at": func.now()},
        )
    )
    await db.execute(stmt)

    # Bound the per-user history.  Cheap subquery: keep the newest
    # ``_MAX_PER_USER`` rows, delete everything else for this user.
    keep_ids = (
        select(RecentlyViewed.id)
        .where(RecentlyViewed.user_id == user.id)
        .order_by(RecentlyViewed.viewed_at.desc())
        .limit(_MAX_PER_USER)
        .scalar_subquery()
    )
    await db.execute(
        delete(RecentlyViewed).where(
            RecentlyViewed.user_id == user.id,
            RecentlyViewed.id.notin_(keep_ids),
        )
    )

    await db.flush()
    logger.debug(
        "recently_viewed_recorded",
        user_id=user.id,
        property_id=property_id,
    )
    return MessageResponse(message="Recorded", message_ar="تم تسجيل المشاهدة")


@router.delete("", response_model=MessageResponse)
async def clear_recently_viewed(
    user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db),
):
    """Wipe the user's entire view history (privacy/clear-history button)."""
    await db.execute(
        delete(RecentlyViewed).where(RecentlyViewed.user_id == user.id)
    )
    await db.flush()
    logger.info("recently_viewed_cleared", user_id=user.id)
    return MessageResponse(message="History cleared", message_ar="تم مسح السجل")
