"""Host analytics – revenue, occupancy, per-property breakdown.

Scope
-----
These endpoints are available to any authenticated ``owner`` (or
``admin``) and ALWAYS return data scoped to that owner's properties.
Admins get the same per-owner slice as everyone else, which keeps the
caller logic dead simple on the Flutter side.

Queries intentionally use SQL aggregation (not Python loops over all
bookings) so they stay fast once hosts have hundreds of bookings.
"""

from __future__ import annotations

from datetime import date, datetime, timedelta, timezone
from typing import Literal

import structlog
from fastapi import APIRouter, Depends, Query
from pydantic import BaseModel
from sqlalchemy import and_, func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.middleware.auth_middleware import require_role
from app.models.booking import Booking, BookingStatus, PaymentStatus
from app.models.property import Property
from app.models.review import Review
from app.models.user import User, UserRole

logger = structlog.get_logger(__name__)
router = APIRouter(prefix="/analytics", tags=["Analytics"])


# ══════════════════════════════════════════════════════════════
#  Response schemas
# ══════════════════════════════════════════════════════════════
class Totals(BaseModel):
    properties_count: int
    bookings_count: int
    bookings_completed: int
    bookings_upcoming: int
    revenue_total: float       # sum of owner_payout across paid bookings
    revenue_pending: float     # confirmed but not yet completed
    avg_rating: float
    reviews_count: int


class MonthlyPoint(BaseModel):
    month: str           # YYYY-MM
    bookings: int
    revenue: float


class TopProperty(BaseModel):
    property_id: int
    name: str
    bookings: int
    revenue: float
    avg_rating: float
    review_count: int


class OccupancyPoint(BaseModel):
    date: date
    booked_nights: int
    total_available: int
    occupancy_rate: float  # 0.0 – 1.0


class OwnerAnalyticsOut(BaseModel):
    range_from: date
    range_to: date
    totals: Totals
    monthly: list[MonthlyPoint]
    top_properties: list[TopProperty]
    occupancy: list[OccupancyPoint]


# ══════════════════════════════════════════════════════════════
#  Main endpoint
# ══════════════════════════════════════════════════════════════
@router.get("/owner", response_model=OwnerAnalyticsOut)
async def owner_analytics(
    period: Literal["month", "quarter", "year"] = Query("month"),
    user: User = Depends(require_role(UserRole.owner, UserRole.admin)),
    db: AsyncSession = Depends(get_db),
):
    """Return an aggregate view of the caller's hosting business."""
    now = datetime.now(timezone.utc).date()
    lookback_days = {"month": 30, "quarter": 90, "year": 365}[period]
    range_from = now - timedelta(days=lookback_days)

    owner_id = user.id

    # ── 1. Totals ──────────────────────────────────────────────
    prop_count = (
        await db.execute(
            select(func.count(Property.id)).where(Property.owner_id == owner_id)
        )
    ).scalar_one()

    bookings_total = (
        await db.execute(
            select(func.count(Booking.id)).where(Booking.owner_id == owner_id)
        )
    ).scalar_one()

    completed = (
        await db.execute(
            select(func.count(Booking.id))
            .where(Booking.owner_id == owner_id)
            .where(Booking.status == BookingStatus.completed)
        )
    ).scalar_one()

    upcoming = (
        await db.execute(
            select(func.count(Booking.id))
            .where(Booking.owner_id == owner_id)
            .where(
                Booking.status.in_(
                    [BookingStatus.pending, BookingStatus.confirmed]
                )
            )
            .where(Booking.check_in >= now)
        )
    ).scalar_one()

    revenue_total = (
        await db.execute(
            select(func.coalesce(func.sum(Booking.owner_payout), 0.0))
            .where(Booking.owner_id == owner_id)
            .where(Booking.payment_status == PaymentStatus.paid)
            .where(
                Booking.status.in_(
                    [BookingStatus.completed, BookingStatus.confirmed]
                )
            )
        )
    ).scalar_one()

    revenue_pending = (
        await db.execute(
            select(func.coalesce(func.sum(Booking.owner_payout), 0.0))
            .where(Booking.owner_id == owner_id)
            .where(Booking.status == BookingStatus.confirmed)
            .where(Booking.payment_status == PaymentStatus.paid)
            .where(Booking.check_out >= now)
        )
    ).scalar_one()

    review_stats = (
        await db.execute(
            select(
                func.coalesce(func.avg(Review.rating), 0.0),
                func.count(Review.id),
            )
            .join(Property, Property.id == Review.property_id)
            .where(Property.owner_id == owner_id)
            .where(Review.is_hidden.is_(False))
        )
    ).first()
    avg_rating = float(review_stats[0] or 0.0) if review_stats else 0.0
    review_count = int(review_stats[1] or 0) if review_stats else 0

    totals = Totals(
        properties_count=int(prop_count or 0),
        bookings_count=int(bookings_total or 0),
        bookings_completed=int(completed or 0),
        bookings_upcoming=int(upcoming or 0),
        revenue_total=float(revenue_total or 0.0),
        revenue_pending=float(revenue_pending or 0.0),
        avg_rating=round(avg_rating, 2),
        reviews_count=review_count,
    )

    # ── 2. Monthly trend ───────────────────────────────────────
    month_expr = func.to_char(Booking.created_at, "YYYY-MM")
    monthly_rows = (
        await db.execute(
            select(
                month_expr.label("month"),
                func.count(Booking.id),
                func.coalesce(func.sum(Booking.owner_payout), 0.0),
            )
            .where(Booking.owner_id == owner_id)
            .where(Booking.created_at >= range_from)
            .group_by(month_expr)
            .order_by(month_expr)
        )
    ).all()
    monthly = [
        MonthlyPoint(
            month=str(row[0]),
            bookings=int(row[1] or 0),
            revenue=float(row[2] or 0.0),
        )
        for row in monthly_rows
    ]

    # ── 3. Top performing properties ───────────────────────────
    top_rows = (
        await db.execute(
            select(
                Property.id,
                Property.name,
                func.count(Booking.id).label("b_count"),
                func.coalesce(func.sum(Booking.owner_payout), 0.0).label("rev"),
                func.coalesce(Property.rating, 0.0),
                func.coalesce(Property.review_count, 0),
            )
            .outerjoin(
                Booking,
                and_(
                    Booking.property_id == Property.id,
                    Booking.payment_status == PaymentStatus.paid,
                ),
            )
            .where(Property.owner_id == owner_id)
            .group_by(
                Property.id, Property.name,
                Property.rating, Property.review_count,
            )
            .order_by(func.sum(Booking.owner_payout).desc().nulls_last())
            .limit(5)
        )
    ).all()
    top_properties = [
        TopProperty(
            property_id=int(row[0]),
            name=str(row[1]),
            bookings=int(row[2] or 0),
            revenue=float(row[3] or 0.0),
            avg_rating=float(row[4] or 0.0),
            review_count=int(row[5] or 0),
        )
        for row in top_rows
    ]

    # ── 4. Occupancy (next 30 days) ────────────────────────────
    occupancy_days: list[OccupancyPoint] = []
    if prop_count:
        # For each of the next 30 days, count bookings that overlap.
        day_series = [now + timedelta(days=i) for i in range(30)]
        booked_rows = (
            await db.execute(
                select(
                    Booking.check_in,
                    Booking.check_out,
                )
                .where(Booking.owner_id == owner_id)
                .where(
                    Booking.status.in_(
                        [BookingStatus.confirmed, BookingStatus.completed]
                    )
                )
                .where(Booking.check_out >= now)
                .where(Booking.check_in <= now + timedelta(days=30))
            )
        ).all()

        # Simple in-memory overlap (30 days × N bookings is tiny).
        for d in day_series:
            booked = sum(
                1 for ci, co in booked_rows if ci <= d < co
            )
            occupancy_days.append(
                OccupancyPoint(
                    date=d,
                    booked_nights=booked,
                    total_available=int(prop_count),
                    occupancy_rate=(
                        booked / prop_count if prop_count else 0.0
                    ),
                )
            )

    logger.info(
        "owner_analytics",
        owner_id=owner_id,
        period=period,
        properties=prop_count,
        bookings=totals.bookings_count,
    )

    return OwnerAnalyticsOut(
        range_from=range_from,
        range_to=now,
        totals=totals,
        monthly=monthly,
        top_properties=top_properties,
        occupancy=occupancy_days,
    )
