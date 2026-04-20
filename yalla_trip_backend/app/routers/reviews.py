"""Reviews router – create review + list by property + host reply."""

from __future__ import annotations

import math
from datetime import datetime, timezone

import structlog
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.database import get_db
from app.middleware.auth_middleware import get_current_active_user
from app.models.booking import Booking, BookingStatus
from app.models.notification import NotificationType
from app.models.property import Property
from app.models.review import Review
from app.models.user import User
from app.schemas.common import MessageResponse, PaginatedResponse
from app.schemas.review import (
    OwnerResponseCreate,
    PendingReviewItem,
    ReviewCreate,
    ReviewOut,
)
from app.services.notification_service import create_notification

logger = structlog.get_logger(__name__)
router = APIRouter(prefix="/reviews", tags=["Reviews"])


@router.post("", response_model=ReviewOut, status_code=status.HTTP_201_CREATED)
async def create_review(
    body: ReviewCreate,
    user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db),
):
    # verify booking exists, belongs to user, and is completed
    result = await db.execute(select(Booking).where(Booking.id == body.booking_id))
    booking = result.scalar_one_or_none()
    if booking is None:
        raise HTTPException(status_code=404, detail="الحجز غير موجود / Booking not found")
    if booking.guest_id != user.id:
        raise HTTPException(status_code=403, detail="ليس حجزك / Not your booking")
    if booking.status != BookingStatus.completed:
        raise HTTPException(
            status_code=400,
            detail="لا يمكن التقييم قبل اكتمال الحجز / Booking must be completed first",
        )

    # check duplicate
    existing = await db.execute(
        select(Review).where(Review.booking_id == body.booking_id)
    )
    if existing.scalar_one_or_none() is not None:
        raise HTTPException(
            status_code=409,
            detail="تم التقييم مسبقاً / Already reviewed",
        )

    review = Review(
        booking_id=booking.id,
        property_id=booking.property_id,
        reviewer_id=user.id,
        rating=body.rating,
        comment=body.comment,
    )
    db.add(review)
    await db.flush()

    # update property rating
    prop_result = await db.execute(
        select(Property).where(Property.id == booking.property_id)
    )
    prop = prop_result.scalar_one()

    avg_result = await db.execute(
        select(func.avg(Review.rating)).where(Review.property_id == prop.id)
    )
    avg_rating = avg_result.scalar() or 0.0
    count_result = await db.execute(
        select(func.count(Review.id)).where(Review.property_id == prop.id)
    )
    count = count_result.scalar() or 0

    prop.rating = round(float(avg_rating), 2)
    prop.review_count = count
    await db.flush()

    # notify owner
    await create_notification(
        db, booking.owner_id,
        title="تقييم جديد",
        body=f"حصل عقارك على تقييم {body.rating}/5",
        notif_type=NotificationType.review_received,
    )

    await db.refresh(review)
    logger.info("review_created", review_id=review.id, property_id=prop.id)
    return ReviewOut.model_validate(review)


@router.get("/my/count")
async def my_review_count(
    user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db),
):
    count = (
        await db.execute(
            select(func.count(Review.id)).where(Review.reviewer_id == user.id)
        )
    ).scalar() or 0
    return {"count": count}


@router.get("/property/{property_id}", response_model=PaginatedResponse[ReviewOut])
async def property_reviews(
    property_id: int,
    page: int = Query(1, ge=1),
    limit: int = Query(20, ge=1, le=100),
    db: AsyncSession = Depends(get_db),
):
    # Hide moderated reviews from the public feed.
    stmt = (
        select(Review)
        .where(Review.property_id == property_id)
        .where(Review.is_hidden.is_(False))
        .order_by(Review.created_at.desc())
    )

    total = (
        await db.execute(select(func.count()).select_from(stmt.subquery()))
    ).scalar() or 0
    pages = math.ceil(total / limit) if total else 0

    rows = (
        await db.execute(stmt.offset((page - 1) * limit).limit(limit))
    ).scalars().all()

    return PaginatedResponse(
        items=[ReviewOut.model_validate(r) for r in rows],
        total=total, page=page, limit=limit, pages=pages,
    )


# ── Pending reviews ─────────────────────────────────────────
@router.get("/my/pending", response_model=list[PendingReviewItem])
async def my_pending_reviews(
    user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db),
):
    """Completed bookings the user has *not* yet reviewed.

    Used by the Flutter client to surface a "rate your stay" prompt.
    """
    # LEFT JOIN Review — keep rows with no matching review.
    stmt = (
        select(Booking)
        .options(selectinload(Booking.property))
        .outerjoin(Review, Review.booking_id == Booking.id)
        .where(Booking.guest_id == user.id)
        .where(Booking.status == BookingStatus.completed)
        .where(Review.id.is_(None))
        .order_by(Booking.updated_at.desc())
    )
    rows = (await db.execute(stmt)).scalars().all()
    items: list[PendingReviewItem] = []
    for b in rows:
        if b.property is None:
            continue
        image = None
        imgs = getattr(b.property, "images", None)
        if imgs:
            first = imgs[0] if isinstance(imgs, list) else None
            image = (
                first
                if isinstance(first, str)
                else getattr(first, "url", None)
            )
        items.append(
            PendingReviewItem(
                booking_id=b.id,
                booking_code=b.booking_code,
                property_id=b.property_id,
                property_name=b.property.name,
                property_image=image,
                check_in=datetime.combine(b.check_in, datetime.min.time()),
                check_out=datetime.combine(b.check_out, datetime.min.time()),
                completed_at=b.updated_at,
            )
        )
    return items


# ── Host reply ──────────────────────────────────────────────
@router.post("/{review_id}/respond", response_model=ReviewOut)
async def respond_to_review(
    review_id: int,
    body: OwnerResponseCreate,
    user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db),
):
    review = await db.get(Review, review_id)
    if review is None:
        raise HTTPException(status_code=404, detail="Review not found")

    prop = await db.get(Property, review.property_id)
    if prop is None or prop.owner_id != user.id:
        raise HTTPException(
            status_code=403,
            detail="فقط مالك العقار يمكنه الرد / Only the owner can reply",
        )
    if review.owner_response:
        raise HTTPException(status_code=409, detail="Already responded")

    review.owner_response = body.response.strip()
    review.owner_response_at = datetime.now(timezone.utc)
    await db.flush()

    # Notify the guest so the reply shows in their inbox.
    await create_notification(
        db, review.reviewer_id,
        title="رد على تقييمك",
        body=f"رد مالك العقار على تقييمك لـ {prop.name}",
        notif_type=NotificationType.review_received,
    )
    # Re-fetch with the reviewer relationship eagerly loaded so the
    # Pydantic response can serialize it without triggering async I/O.
    fresh = (
        await db.execute(
            select(Review)
            .options(selectinload(Review.reviewer))
            .where(Review.id == review.id)
        )
    ).scalar_one()
    logger.info("review_responded", review_id=fresh.id, owner_id=user.id)
    return ReviewOut.model_validate(fresh)


# ── Report a review ─────────────────────────────────────────
@router.post("/{review_id}/report", response_model=MessageResponse)
async def report_review(
    review_id: int,
    user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db),
):
    """Flag a review for admin moderation.

    After 3 reports the review is auto-hidden until an admin reviews it.
    """
    review = await db.get(Review, review_id)
    if review is None:
        raise HTTPException(status_code=404, detail="Review not found")
    # Reviewer can't report their own review.
    if review.reviewer_id == user.id:
        raise HTTPException(status_code=400, detail="Cannot report your own review")

    review.report_count = (review.report_count or 0) + 1
    if review.report_count >= 3 and not review.is_hidden:
        review.is_hidden = True
        logger.info("review_auto_hidden", review_id=review.id)
    await db.flush()
    return MessageResponse(message="Reported", message_ar="تم الإبلاغ")
