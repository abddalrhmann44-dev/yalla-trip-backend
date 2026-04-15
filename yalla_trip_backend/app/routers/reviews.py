"""Reviews router – create review + list by property."""

from __future__ import annotations

import math

import structlog
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.middleware.auth_middleware import get_current_active_user
from app.models.booking import Booking, BookingStatus
from app.models.notification import NotificationType
from app.models.property import Property
from app.models.review import Review
from app.models.user import User
from app.schemas.common import PaginatedResponse
from app.schemas.review import ReviewCreate, ReviewOut
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
    stmt = (
        select(Review)
        .where(Review.property_id == property_id)
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
