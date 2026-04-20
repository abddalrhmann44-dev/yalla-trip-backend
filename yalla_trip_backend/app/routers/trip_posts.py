"""Best-Trip public feed router.

Endpoints:
- ``GET  /trip-posts``                — global feed (paged, hides
  moderated posts, newest first).
- ``POST /trip-posts``                — publish a post tied to a
  completed booking you own.
- ``GET  /trip-posts/mine``           — the current user's own posts.
- ``GET  /trip-posts/eligible-bookings`` — bookings the user can post
  about but hasn't yet.
- ``DELETE /trip-posts/{post_id}``    — delete your own post.
- ``POST /admin/trip-posts/{id}/hide`` & ``/unhide`` — moderation.
"""

from __future__ import annotations

import math
from datetime import datetime
from typing import Optional

import structlog
from fastapi import APIRouter, Depends, HTTPException, Query, status
from pydantic import BaseModel, Field
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.middleware.auth_middleware import get_current_active_user, require_role
from app.models.booking import Booking, BookingStatus
from app.models.property import Property
from app.models.trip_post import TripPost, TripVerdict
from app.models.user import User, UserRole

logger = structlog.get_logger(__name__)
router = APIRouter(prefix="/trip-posts", tags=["TripPosts"])

_admin_only = require_role(UserRole.admin)


# ── Schemas ──────────────────────────────────────────────

class TripPostCreate(BaseModel):
    booking_id: int
    verdict: TripVerdict
    caption: Optional[str] = Field(None, max_length=1000)
    image_urls: list[str] = Field(default_factory=list, max_length=10)


class _AuthorBrief(BaseModel):
    id: int
    name: str
    avatar_url: Optional[str] = None
    is_verified: bool = False

    model_config = {"from_attributes": True}


class _PropertyBrief(BaseModel):
    id: int
    name: str
    area: str
    is_verified: bool = False

    model_config = {"from_attributes": True}


class TripPostOut(BaseModel):
    id: int
    verdict: TripVerdict
    caption: Optional[str]
    image_urls: list[str]
    created_at: datetime
    property_id: int
    booking_id: int
    author: _AuthorBrief
    property: _PropertyBrief

    model_config = {"from_attributes": True}


class EligibleBookingOut(BaseModel):
    booking_id: int
    property_id: int
    property_name: str
    check_out: datetime

    model_config = {"from_attributes": True}


class PaginatedTripPosts(BaseModel):
    items: list[TripPostOut]
    page: int
    limit: int
    total: int
    pages: int


# ══════════════════════════════════════════════════════════════
#  Public feed
# ══════════════════════════════════════════════════════════════

def _serialise(post: TripPost) -> TripPostOut:
    return TripPostOut(
        id=post.id,
        verdict=post.verdict,
        caption=post.caption,
        image_urls=post.image_urls or [],
        created_at=post.created_at,
        property_id=post.property_id,
        booking_id=post.booking_id,
        author=_AuthorBrief(
            id=post.author.id,
            name=post.author.name,
            avatar_url=post.author.avatar_url,
            is_verified=post.author.is_verified,
        ),
        property=_PropertyBrief(
            id=post.property.id,
            name=post.property.name,
            area=post.property.area.value if hasattr(post.property.area, "value") else str(post.property.area),
            is_verified=post.property.is_verified,
        ),
    )


@router.get("", response_model=PaginatedTripPosts)
async def list_feed(
    page: int = Query(1, ge=1),
    limit: int = Query(20, ge=1, le=50),
    verdict: TripVerdict | None = None,
    property_id: int | None = None,
    db: AsyncSession = Depends(get_db),
):
    """Public global Best-Trip feed, newest first."""
    base = select(TripPost).where(TripPost.is_hidden.is_(False))
    if verdict is not None:
        base = base.where(TripPost.verdict == verdict)
    if property_id is not None:
        base = base.where(TripPost.property_id == property_id)

    total = (await db.execute(
        select(func.count()).select_from(base.subquery())
    )).scalar() or 0

    stmt = (
        base.order_by(TripPost.created_at.desc())
        .offset((page - 1) * limit)
        .limit(limit)
    )
    rows = (await db.execute(stmt)).scalars().all()
    return PaginatedTripPosts(
        items=[_serialise(p) for p in rows],
        page=page,
        limit=limit,
        total=total,
        pages=max(1, math.ceil(total / limit)),
    )


@router.get("/mine", response_model=list[TripPostOut])
async def list_my_posts(
    user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db),
):
    rows = (await db.execute(
        select(TripPost)
        .where(TripPost.author_id == user.id)
        .order_by(TripPost.created_at.desc())
    )).scalars().all()
    return [_serialise(p) for p in rows]


@router.get(
    "/eligible-bookings",
    response_model=list[EligibleBookingOut],
)
async def list_eligible_bookings(
    user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db),
):
    """Completed bookings the user hasn't posted about yet."""
    # Bookings that are completed AND the user is the guest
    posted_sq = select(TripPost.booking_id).where(
        TripPost.author_id == user.id
    )
    stmt = (
        select(Booking, Property.name)
        .join(Property, Property.id == Booking.property_id)
        .where(
            Booking.guest_id == user.id,
            Booking.status == BookingStatus.completed,
            Booking.id.not_in(posted_sq),
        )
        .order_by(Booking.check_out.desc())
        .limit(50)
    )
    rows = (await db.execute(stmt)).all()
    return [
        EligibleBookingOut(
            booking_id=b.id,
            property_id=b.property_id,
            property_name=name,
            check_out=datetime.combine(b.check_out, datetime.min.time()),
        )
        for b, name in rows
    ]


# ══════════════════════════════════════════════════════════════
#  Author actions
# ══════════════════════════════════════════════════════════════

@router.post("", response_model=TripPostOut, status_code=status.HTTP_201_CREATED)
async def create_post(
    body: TripPostCreate,
    user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db),
):
    """Publish a Best-Trip post about a completed booking."""
    booking = (await db.execute(
        select(Booking).where(Booking.id == body.booking_id)
    )).scalar_one_or_none()

    if booking is None:
        raise HTTPException(status_code=404, detail="الحجز غير موجود / Booking not found")
    if booking.guest_id != user.id:
        raise HTTPException(status_code=403, detail="ليس حجزك / Not your booking")
    if booking.status != BookingStatus.completed:
        raise HTTPException(
            status_code=409,
            detail="لم تكتمل الرحلة بعد / Trip not completed yet",
        )

    existing = (await db.execute(
        select(TripPost).where(TripPost.booking_id == body.booking_id)
    )).scalar_one_or_none()
    if existing is not None:
        raise HTTPException(
            status_code=409,
            detail="نشرتَ عن هذه الرحلة بالفعل / Already posted about this trip",
        )

    post = TripPost(
        author_id=user.id,
        booking_id=body.booking_id,
        property_id=booking.property_id,
        verdict=body.verdict,
        caption=body.caption,
        image_urls=body.image_urls,
    )
    db.add(post)
    await db.flush()
    # Reload relationships for serialisation
    await db.refresh(post)
    logger.info("trip_post_created", post_id=post.id, author=user.id)
    return _serialise(post)


@router.delete("/{post_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_my_post(
    post_id: int,
    user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db),
):
    post = (await db.execute(
        select(TripPost).where(TripPost.id == post_id)
    )).scalar_one_or_none()
    if post is None:
        raise HTTPException(status_code=404, detail="Post not found")
    if post.author_id != user.id and user.role != UserRole.admin:
        raise HTTPException(status_code=403, detail="Not yours")
    await db.delete(post)
    await db.flush()


# ══════════════════════════════════════════════════════════════
#  Moderation (admin)
# ══════════════════════════════════════════════════════════════

@router.post("/admin/{post_id}/hide", response_model=TripPostOut)
async def admin_hide(
    post_id: int,
    _: User = Depends(_admin_only),
    db: AsyncSession = Depends(get_db),
):
    post = (await db.execute(
        select(TripPost).where(TripPost.id == post_id)
    )).scalar_one_or_none()
    if post is None:
        raise HTTPException(status_code=404, detail="Post not found")
    post.is_hidden = True
    await db.flush()
    await db.refresh(post)
    return _serialise(post)


@router.post("/admin/{post_id}/unhide", response_model=TripPostOut)
async def admin_unhide(
    post_id: int,
    _: User = Depends(_admin_only),
    db: AsyncSession = Depends(get_db),
):
    post = (await db.execute(
        select(TripPost).where(TripPost.id == post_id)
    )).scalar_one_or_none()
    if post is None:
        raise HTTPException(status_code=404, detail="Post not found")
    post.is_hidden = False
    await db.flush()
    await db.refresh(post)
    return _serialise(post)
