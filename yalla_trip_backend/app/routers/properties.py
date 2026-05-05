"""Properties router – list / detail / CRUD / image upload."""

from __future__ import annotations

import asyncio
import math
from collections import Counter
from datetime import date, datetime, timedelta, timezone
from typing import List, Optional

import structlog
from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException, Query, UploadFile, File, status
from pydantic import BaseModel
from sqlalchemy import Select, case, func, select, and_, or_
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.middleware.auth_middleware import require_role
from app.models.booking import Booking, BookingStatus, PaymentStatus
from app.models.availability_rule import AvailabilityRule, RuleType
from app.models.calendar import CalendarBlock
from app.models.property import Area, Category, Property, PropertyStatus
from app.models.user import User, UserRole
from app.schemas.common import PaginatedResponse
from app.schemas.property import (
    AVAILABLE_SERVICES,
    PropertyCreate,
    PropertyOut,
    PropertyUpdate,
    _CLEANING_FEE_CATEGORIES,
    _CLOSING_TIME_CATEGORIES,
    _MULTI_ROOM_CATEGORIES,
    _UNLIMITED_CATEGORIES,
    _UTILITY_CATEGORIES,
)
from app.services.s3_service import delete_image, upload_image

# ── Image upload constants ──────────────────────────────────
# Centralised so KYC + listing-image endpoints stay in sync; previous
# inconsistency rejected HEIC on /id-documents while accepting it on
# /images, frustrating iPhone hosts mid-onboarding.
_ALLOWED_IMAGE_MIMES = {
    "image/jpeg",
    "image/jpg",
    "image/png",
    "image/webp",
    "image/gif",
    "image/heic",
    "image/heif",
}


_EXT_TO_MIME: dict[str, str] = {
    ".jpg": "image/jpeg",
    ".jpeg": "image/jpeg",
    ".png": "image/png",
    ".webp": "image/webp",
    ".gif": "image/gif",
    ".heic": "image/jpeg",
    ".heif": "image/jpeg",
}


def _normalise_image_ct(
    content_type: str | None,
    filename: str | None = None,
) -> str | None:
    """Return a canonical S3 content-type, or ``None`` if unsupported.

    HEIC/HEIF are tagged as JPEG because ``image_picker`` on iOS
    transcodes to JPEG when ``imageQuality < 100`` — only the raw
    capture path lands as HEIC and the S3 layer expects JPEG.

    When ``content_type`` is ``application/octet-stream`` (common with
    the Dart ``http`` package on iOS), the MIME type is inferred from
    the file extension instead of being rejected outright.
    """
    ct = (content_type or "").lower()

    # Dart http MultipartFile often sends application/octet-stream on
    # iOS — fall back to the filename extension.
    if ct in ("application/octet-stream", "") and filename:
        ext = "." + filename.rsplit(".", 1)[-1].lower() if "." in filename else ""
        ct = _EXT_TO_MIME.get(ext, ct)

    if ct not in _ALLOWED_IMAGE_MIMES:
        return None
    if ct in ("image/heic", "image/heif"):
        return "image/jpeg"
    if ct == "image/jpg":
        return "image/jpeg"
    return ct


# Fields the host is allowed to PATCH on /properties/{id}.  Anything
# outside this set (status, is_verified, is_featured, owner_id, ...)
# stays admin-only — even if a future PropertyUpdate schema accidentally
# exposes them.  Defence-in-depth.
_HOST_EDITABLE_FIELDS = frozenset({
    "name", "description", "area", "category",
    "price_per_night", "weekend_price",
    "cleaning_fee", "electricity_fee", "water_fee", "security_deposit",
    "bedrooms", "bathrooms", "max_guests", "total_rooms",
    "closing_time", "trip_duration_hours",
    "services", "amenities",
    "is_available", "instant_booking",
    "negotiable", "cash_on_arrival_enabled",
    "latitude", "longitude",
})


class MyPropertiesStats(BaseModel):
    """Aggregate stats for the host dashboard — single round-trip.

    Replaces the Flutter side computing these from the full property
    list (which lacked revenue/occupancy entirely) and avoids the
    O(properties × round-trips) call pattern hosts saw on slow networks.
    """
    total_properties: int
    active_properties: int
    avg_rating: float
    total_reviews: int
    revenue_30d: float
    revenue_all_time: float
    upcoming_bookings: int
    pending_kyc: int

logger = structlog.get_logger(__name__)
router = APIRouter(prefix="/properties", tags=["Properties"])


# ── Haversine distance filter (km) ───────────────────────
def _distance_expr(lat: float, lng: float):
    """Return a SQLAlchemy expression for Haversine distance in km."""
    return (
        6371
        * func.acos(
            func.cos(func.radians(lat))
            * func.cos(func.radians(Property.latitude))
            * func.cos(func.radians(Property.longitude) - func.radians(lng))
            + func.sin(func.radians(lat)) * func.sin(func.radians(Property.latitude))
        )
    )


# ── Date-availability sub-query ──────────────────────────
# Returns a boolean column "has conflict" for the given date range so we
# can EXCLUDE any property that already has an overlapping non-cancelled
# booking.  Two bookings A,B conflict when
#   A.check_in < B.check_out  AND  B.check_in < A.check_out
# (standard half-open interval intersection).
def _conflicting_booking_subq(
    check_in: date, check_out: date,
):
    return (
        select(Booking.property_id)
        .where(
            Booking.status.in_(
                [BookingStatus.pending, BookingStatus.confirmed]
            ),
            Booking.check_in < check_out,
            Booking.check_out > check_in,
        )
        .subquery()
    )


def _apply_filters(
    stmt: Select,
    *,
    area: Optional[Area],
    category: Optional[Category],
    min_price: Optional[float],
    max_price: Optional[float],
    min_rating: Optional[float],
    bedrooms: Optional[int],
    max_guests: Optional[int],
    instant_booking: Optional[bool],
    search: Optional[str],
    amenities: Optional[List[str]],
    check_in: Optional[date],
    check_out: Optional[date],
    include_unapproved: bool,
) -> Select:
    # Guest-facing search must never surface soft-deleted listings.
    stmt = stmt.where(Property.deleted_at.is_(None))
    if area:
        stmt = stmt.where(Property.area == area)
    if category:
        stmt = stmt.where(Property.category == category)
    if min_price is not None:
        stmt = stmt.where(Property.price_per_night >= min_price)
    if max_price is not None:
        stmt = stmt.where(Property.price_per_night <= max_price)
    if min_rating is not None:
        stmt = stmt.where(Property.rating >= min_rating)
    if bedrooms is not None:
        stmt = stmt.where(Property.bedrooms >= bedrooms)
    if max_guests is not None:
        stmt = stmt.where(Property.max_guests >= max_guests)
    if instant_booking is not None:
        stmt = stmt.where(Property.instant_booking == instant_booking)

    # Multi-field text search — name + description — case-insensitive.
    if search:
        needle = f"%{search.strip()}%"
        stmt = stmt.where(
            or_(
                Property.name.ilike(needle),
                Property.description.ilike(needle),
            )
        )

    # ``amenities`` is a Postgres text[]; require ALL requested values
    # to be present using the contains (``@>``) operator.
    if amenities:
        stmt = stmt.where(Property.amenities.contains(amenities))

    # Exclude anything with a conflicting booking, a calendar block
    # (manual or imported), or a closed availability rule for the window.
    if check_in and check_out and check_out > check_in:
        conflict_sq = _conflicting_booking_subq(check_in, check_out)
        block_sq = (
            select(CalendarBlock.property_id)
            .where(
                CalendarBlock.start_date < check_out,
                CalendarBlock.end_date > check_in,
            )
            .subquery()
        )
        closed_sq = (
            select(AvailabilityRule.property_id)
            .where(
                AvailabilityRule.rule_type == RuleType.closed,
                AvailabilityRule.start_date < check_out,
                AvailabilityRule.end_date > check_in,
            )
            .subquery()
        )
        stmt = stmt.where(
            Property.id.notin_(select(conflict_sq.c.property_id)),
            Property.id.notin_(select(block_sq.c.property_id)),
            Property.id.notin_(select(closed_sq.c.property_id)),
        )

    # Public search must only show approved + available inventory;
    # admin callers can opt into the full set via ``include_unapproved``.
    if not include_unapproved:
        stmt = stmt.where(Property.status == PropertyStatus.approved)
    stmt = stmt.where(Property.is_available.is_(True))
    return stmt


@router.get("/services")
async def get_available_services():
    """Return available services list and category rules for the Flutter form."""
    return {
        "services": AVAILABLE_SERVICES,
        "category_rules": {
            "utility_fees": [c.value for c in _UTILITY_CATEGORIES],
            "cleaning_fee": [c.value for c in _CLEANING_FEE_CATEGORIES],
            "multi_room": [c.value for c in _MULTI_ROOM_CATEGORIES],
            "unlimited_capacity": [c.value for c in _UNLIMITED_CATEGORIES],
            "closing_time": [c.value for c in _CLOSING_TIME_CATEGORIES],
        },
    }


_SORT_PATTERN = (
    r"^(price_asc|price_desc|rating|newest|popularity|distance|best_match)$"
)


@router.get("", response_model=PaginatedResponse[PropertyOut])
async def list_properties(
    page: int = Query(1, ge=1),
    limit: int = Query(20, ge=1, le=100),
    area: Optional[Area] = None,
    category: Optional[Category] = None,
    min_price: Optional[float] = Query(None, ge=0),
    max_price: Optional[float] = Query(None, ge=0),
    min_rating: Optional[float] = Query(None, ge=0, le=5),
    bedrooms: Optional[int] = Query(None, ge=0),
    max_guests: Optional[int] = Query(None, ge=1),
    instant_booking: Optional[bool] = None,
    search: Optional[str] = None,
    amenities: Optional[List[str]] = Query(
        None, description="Require all listed amenities (AND semantics)",
    ),
    check_in: Optional[date] = Query(
        None, description="Filter out properties booked during this range",
    ),
    check_out: Optional[date] = None,
    sort_by: str = Query("best_match", pattern=_SORT_PATTERN),
    latitude: Optional[float] = None,
    longitude: Optional[float] = None,
    radius_km: Optional[float] = Query(None, gt=0),
    db: AsyncSession = Depends(get_db),
):
    """Search + filter the public property catalogue.

    Sorting modes
    -------------
    * ``best_match``  – featured → rating → review_count → newest
    * ``price_asc`` / ``price_desc``
    * ``rating``     – highest rated first
    * ``newest``     – most recently listed
    * ``popularity`` – most booked in the past 90 days
    * ``distance``   – requires ``latitude`` + ``longitude``

    The availability window (``check_in`` + ``check_out``) is enforced
    at the query level so guests never see already-taken inventory.
    """
    # Date-range sanity: ignore silently rather than 400 so old clients
    # that send only a check_in still work.
    if check_in and check_out and check_out <= check_in:
        check_in = check_out = None

    stmt = select(Property)
    stmt = _apply_filters(
        stmt,
        area=area,
        category=category,
        min_price=min_price,
        max_price=max_price,
        min_rating=min_rating,
        bedrooms=bedrooms,
        max_guests=max_guests,
        instant_booking=instant_booking,
        search=search,
        amenities=amenities,
        check_in=check_in,
        check_out=check_out,
        include_unapproved=False,
    )

    # ── Distance filter + column  ─────────────────────────
    dist_col = None
    if latitude is not None and longitude is not None:
        dist_col = _distance_expr(latitude, longitude).label("distance_km")
        stmt = stmt.where(
            and_(Property.latitude.isnot(None), Property.longitude.isnot(None))
        )
        if radius_km is not None:
            stmt = stmt.where(dist_col <= radius_km)

    # ── Sorting ──────────────────────────────────────────
    if sort_by == "price_asc":
        stmt = stmt.order_by(Property.price_per_night.asc())
    elif sort_by == "price_desc":
        stmt = stmt.order_by(Property.price_per_night.desc())
    elif sort_by == "rating":
        stmt = stmt.order_by(
            Property.rating.desc(), Property.review_count.desc(),
        )
    elif sort_by == "newest":
        stmt = stmt.order_by(Property.created_at.desc())
    elif sort_by == "popularity":
        # Count recent confirmed bookings → join as a scalar subquery.
        recency = date.today() - timedelta(days=90)
        pop_subq = (
            select(func.count(Booking.id))
            .where(
                Booking.property_id == Property.id,
                Booking.status == BookingStatus.confirmed,
                Booking.created_at >= recency,
            )
            .correlate(Property)
            .scalar_subquery()
        )
        stmt = stmt.order_by(pop_subq.desc(), Property.rating.desc())
    elif sort_by == "distance":
        if dist_col is None:
            raise HTTPException(
                status_code=400,
                detail="sort_by=distance requires latitude+longitude",
            )
        stmt = stmt.order_by(dist_col.asc())
    else:
        # best_match: featured first, then rating, then review count,
        # then newest.  Gives a sensible landing-page ordering out of
        # the box even when the caller passes no filters.
        stmt = stmt.order_by(
            Property.is_featured.desc(),
            Property.rating.desc(),
            Property.review_count.desc(),
            Property.created_at.desc(),
        )

    # ── count + paginate ─────────────────────────────────
    count_stmt = select(func.count()).select_from(stmt.subquery())
    total = (await db.execute(count_stmt)).scalar() or 0
    pages = math.ceil(total / limit) if total else 0

    stmt = stmt.offset((page - 1) * limit).limit(limit)
    rows = (await db.execute(stmt)).scalars().all()

    return PaginatedResponse(
        items=[PropertyOut.model_validate(r) for r in rows],
        total=total,
        page=page,
        limit=limit,
        pages=pages,
    )


# ── Autocomplete / suggestions ───────────────────────────
@router.get("/suggest")
async def suggest_properties(
    q: str = Query(..., min_length=1, max_length=100),
    limit: int = Query(8, ge=1, le=20),
    db: AsyncSession = Depends(get_db),
):
    """Lightweight autocomplete for the search bar.

    Returns a mix of:
    * matching property names (with id for deep-linking), and
    * distinct area values that contain the query.

    Results are shaped so the Flutter client can render a single list
    with category badges.
    """
    needle = f"%{q.strip()}%"

    prop_rows = (
        await db.execute(
            select(Property.id, Property.name, Property.area)
            .where(
                Property.status == PropertyStatus.approved,
                Property.is_available.is_(True),
                Property.name.ilike(needle),
            )
            .order_by(Property.rating.desc(), Property.review_count.desc())
            .limit(limit)
        )
    ).all()

    suggestions = [
        {
            "type": "property",
            "id": r.id,
            "label": r.name,
            "secondary": r.area.value,
        }
        for r in prop_rows
    ]

    # Area values that loosely contain the needle.
    q_lower = q.strip().lower()
    for area in Area:
        if q_lower and (q_lower in area.value.lower() or q_lower in area.name):
            suggestions.append(
                {"type": "area", "id": None, "label": area.value, "secondary": "منطقة"}
            )

    return {"query": q, "suggestions": suggestions[:limit]}


@router.get("/mine", response_model=list[PropertyOut])
async def my_properties(
    user: User = Depends(require_role(UserRole.owner, UserRole.admin)),
    db: AsyncSession = Depends(get_db),
):
    """Return ALL non-deleted properties owned by the current user."""
    result = await db.execute(
        select(Property)
        .where(
            Property.owner_id == user.id,
            Property.deleted_at.is_(None),
        )
        .order_by(Property.created_at.desc())
    )
    return [PropertyOut.model_validate(p) for p in result.scalars().all()]


@router.get("/mine/stats", response_model=MyPropertiesStats)
async def my_properties_stats(
    user: User = Depends(require_role(UserRole.owner, UserRole.admin)),
    db: AsyncSession = Depends(get_db),
):
    """Aggregate dashboard stats in two queries.

    Replaces the Flutter-side ``_activeCount`` / ``_avgRating`` /
    ``_totalReviews`` getters which had to download every property
    just to compute three integers, and adds the metrics the host
    actually wants front-and-centre: revenue (30d + lifetime) and
    upcoming bookings.
    """
    now = datetime.now(timezone.utc)
    cutoff_30d = now - timedelta(days=30)

    # Single Booking aggregate covering revenue (30d + lifetime) and
    # upcoming-bookings count via FILTER clauses.
    booking_agg = (
        await db.execute(
            select(
                func.coalesce(
                    func.sum(Booking.owner_payout).filter(
                        and_(
                            Booking.status == BookingStatus.completed,
                            Booking.payment_status == PaymentStatus.paid,
                            Booking.created_at >= cutoff_30d,
                        )
                    ),
                    0,
                ).label("revenue_30d"),
                func.coalesce(
                    func.sum(Booking.owner_payout).filter(
                        and_(
                            Booking.status == BookingStatus.completed,
                            Booking.payment_status == PaymentStatus.paid,
                        )
                    ),
                    0,
                ).label("revenue_all_time"),
                func.count(Booking.id).filter(
                    and_(
                        Booking.status.in_(
                            [BookingStatus.pending, BookingStatus.confirmed]
                        ),
                        Booking.check_in >= now.date(),
                    )
                ).label("upcoming_bookings"),
            ).where(Booking.owner_id == user.id)
        )
    ).one()

    # Single Property aggregate covering totals + ratings.
    prop_agg = (
        await db.execute(
            select(
                func.count(Property.id).label("total"),
                func.count(Property.id).filter(
                    Property.is_available.is_(True)
                ).label("active"),
                func.coalesce(
                    func.avg(Property.rating).filter(Property.rating > 0), 0
                ).label("avg_rating"),
                func.coalesce(func.sum(Property.review_count), 0).label("total_reviews"),
                func.count(Property.id).filter(
                    and_(
                        Property.id_document_front_url.is_(None),
                        Property.id_document_back_url.is_(None),
                    )
                ).label("pending_kyc"),
            ).where(
                Property.owner_id == user.id,
                Property.deleted_at.is_(None),
            )
        )
    ).one()

    return MyPropertiesStats(
        total_properties=int(prop_agg.total or 0),
        active_properties=int(prop_agg.active or 0),
        avg_rating=round(float(prop_agg.avg_rating or 0.0), 2),
        total_reviews=int(prop_agg.total_reviews or 0),
        revenue_30d=round(float(booking_agg.revenue_30d or 0.0), 2),
        revenue_all_time=round(float(booking_agg.revenue_all_time or 0.0), 2),
        upcoming_bookings=int(booking_agg.upcoming_bookings or 0),
        pending_kyc=int(prop_agg.pending_kyc or 0),
    )


@router.get("/{property_id}/similar", response_model=list[PropertyOut])
async def similar_properties(
    property_id: int,
    limit: int = Query(8, ge=1, le=20),
    db: AsyncSession = Depends(get_db),
):
    """Return properties similar to the given one (same area/category)."""
    source = (
        await db.execute(
            select(Property).where(
                Property.id == property_id,
                Property.deleted_at.is_(None),
            )
        )
    ).scalar_one_or_none()
    if source is None:
        raise HTTPException(status_code=404, detail="Property not found")

    # Price window: ±40% of source price_per_night
    low = float(source.price_per_night) * 0.6
    high = float(source.price_per_night) * 1.4

    stmt = (
        select(Property)
        .where(Property.id != property_id)
        .where(Property.deleted_at.is_(None))
        .where(Property.is_available == True)  # noqa: E712
        .where(
            (Property.area == source.area) | (Property.category == source.category)
        )
        .where(Property.price_per_night.between(low, high))
        .order_by(Property.rating.desc(), Property.created_at.desc())
        .limit(limit)
    )
    rows = (await db.execute(stmt)).scalars().all()

    # Fallback: if too few matches inside the price window, widen the query.
    if len(rows) < max(3, limit // 2):
        wider = (
            select(Property)
            .where(Property.id != property_id)
            .where(Property.deleted_at.is_(None))
            .where(Property.is_available == True)  # noqa: E712
            .where(
                (Property.area == source.area)
                | (Property.category == source.category)
            )
            .order_by(Property.rating.desc(), Property.created_at.desc())
            .limit(limit)
        )
        rows = (await db.execute(wider)).scalars().all()

    return [PropertyOut.model_validate(r) for r in rows]


@router.get("/{property_id}", response_model=PropertyOut)
async def get_property(property_id: int, db: AsyncSession = Depends(get_db)):
    result = await db.execute(
        select(Property).where(
            Property.id == property_id,
            Property.deleted_at.is_(None),
        )
    )
    prop = result.scalar_one_or_none()
    if prop is None:
        raise HTTPException(status_code=404, detail="العقار غير موجود / Property not found")
    return PropertyOut.model_validate(prop)


@router.get("/{property_id}/booked-dates")
async def booked_dates(
    property_id: int,
    from_date: date = Query(default=None, description="Start of range (default: today)"),
    to_date: date = Query(default=None, description="End of range (default: +90 days)"),
    db: AsyncSession = Depends(get_db),
):
    """Return availability info for a property over a date range.

    - **Chalet (total_rooms=1):** returns fully_booked_dates to grey-out in the calendar.
    - **Hotel (total_rooms=N):** returns per-date availability so Flutter can show
      "3 غرف متاحة" and only grey-out dates where all rooms are taken.
    """
    # defaults
    if from_date is None:
        from_date = date.today()
    if to_date is None:
        to_date = from_date + timedelta(days=90)

    # verify property exists
    result = await db.execute(select(Property).where(Property.id == property_id))
    prop = result.scalar_one_or_none()
    if prop is None:
        raise HTTPException(status_code=404, detail="العقار غير موجود / Property not found")

    # fetch active bookings that overlap with the requested range
    stmt = select(Booking.check_in, Booking.check_out).where(
        Booking.property_id == property_id,
        Booking.status.in_([BookingStatus.pending, BookingStatus.confirmed]),
        Booking.check_in < to_date,
        Booking.check_out > from_date,
    )
    rows = (await db.execute(stmt)).all()

    # count how many bookings cover each date
    date_counts: Counter[date] = Counter()
    for check_in, check_out in rows:
        day = max(check_in, from_date)
        end = min(check_out, to_date)
        while day < end:
            date_counts[day] += 1
            day += timedelta(days=1)

    total_rooms = prop.total_rooms
    is_unlimited = total_rooms == 0

    response: dict = {
        "property_id": property_id,
        "total_rooms": total_rooms,
        "unlimited": is_unlimited,
        "from_date": from_date.isoformat(),
        "to_date": to_date.isoformat(),
    }

    if is_unlimited:
        # Beach / Aqua Park — never fully booked, just show booking count
        response["fully_booked_dates"] = []
        response["total_fully_booked_days"] = 0
        response["total_bookings"] = len(rows)
        if prop.closing_time:
            response["closing_time"] = prop.closing_time
        return response

    # fully booked = dates where all rooms are taken
    fully_booked = sorted(
        d.isoformat() for d, count in date_counts.items() if count >= total_rooms
    )

    response["fully_booked_dates"] = fully_booked
    response["total_fully_booked_days"] = len(fully_booked)

    # for multi-room properties, also include per-date availability
    if total_rooms > 1:
        availability = {}
        day = from_date
        while day < to_date:
            booked_count = date_counts.get(day, 0)
            available = total_rooms - booked_count
            if available < total_rooms:  # only include dates with some bookings
                availability[day.isoformat()] = {
                    "booked": booked_count,
                    "available": available,
                }
            day += timedelta(days=1)
        response["date_availability"] = availability

    return response


@router.post("", response_model=PropertyOut, status_code=status.HTTP_201_CREATED)
async def create_property(
    body: PropertyCreate,
    user: User = Depends(require_role(UserRole.owner, UserRole.admin)),
    db: AsyncSession = Depends(get_db),
):
    try:
        prop = Property(**body.model_dump(), owner_id=user.id)
        db.add(prop)
        await db.flush()
        await db.refresh(prop)
        logger.info("property_created", property_id=prop.id, owner_id=user.id)
        return PropertyOut.model_validate(prop)
    except HTTPException:
        raise
    except Exception as exc:
        logger.error(
            "property_create_failed",
            error=repr(exc),
            error_type=type(exc).__name__,
            area=body.area if hasattr(body, 'area') else 'N/A',
        )
        raise HTTPException(
            status_code=500,
            detail=f"فشل إنشاء العقار: {type(exc).__name__}: {exc}",
        )


@router.put("/{property_id}", response_model=PropertyOut)
async def update_property(
    property_id: int,
    body: PropertyUpdate,
    user: User = Depends(require_role(UserRole.owner, UserRole.admin)),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(Property).where(
            Property.id == property_id,
            Property.deleted_at.is_(None),
        )
    )
    prop = result.scalar_one_or_none()
    if prop is None:
        raise HTTPException(status_code=404, detail="العقار غير موجود / Property not found")
    if prop.owner_id != user.id and user.role != UserRole.admin:
        raise HTTPException(status_code=403, detail="ليس لديك صلاحية / Not your property")

    # Whitelist host-editable fields.  Even if PropertyUpdate ever grows
    # an ``owner_id`` / ``status`` / ``is_verified`` field by accident,
    # the host can never write through to it from this endpoint — admin
    # endpoints handle those.  Admins skip the filter so support can
    # still patch any column from the same route.
    is_admin = user.role == UserRole.admin
    for key, value in body.model_dump(exclude_unset=True).items():
        if not is_admin and key not in _HOST_EDITABLE_FIELDS:
            logger.warning(
                "property_update_blocked_field",
                property_id=property_id,
                user_id=user.id,
                field=key,
            )
            continue
        setattr(prop, key, value)
    await db.flush()
    await db.refresh(prop)
    return PropertyOut.model_validate(prop)


@router.delete("/{property_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_property(
    property_id: int,
    user: User = Depends(require_role(UserRole.owner, UserRole.admin)),
    db: AsyncSession = Depends(get_db),
):
    """Soft-delete a property.

    The previous hard-delete path was a real-money disaster: the FK
    ``bookings.property_id`` is ``ON DELETE CASCADE``, so removing a
    listing also wiped every paid + confirmed booking attached to it.
    A malicious host could exploit this to nuke guest bookings (and
    the audit trail with them).

    Now:

    * If any non-terminal booking exists → 409, instructing the host
      to cancel them through the proper flow first.
    * Otherwise stamp ``deleted_at`` and flip ``is_available`` so the
      listing disappears from search.  No row is removed.
    """
    result = await db.execute(
        select(Property).where(
            Property.id == property_id,
            Property.deleted_at.is_(None),
        )
    )
    prop = result.scalar_one_or_none()
    if prop is None:
        raise HTTPException(status_code=404, detail="العقار غير موجود / Property not found")
    if prop.owner_id != user.id and user.role != UserRole.admin:
        raise HTTPException(status_code=403, detail="ليس لديك صلاحية / Not your property")

    # Block the delete if any active booking references this property.
    # ``pending`` and ``confirmed`` are the non-terminal states; both
    # represent guests who paid (or committed to pay) and would be
    # silently wiped by a CASCADE on hard delete.
    active_bookings = (
        await db.execute(
            select(func.count(Booking.id)).where(
                Booking.property_id == property_id,
                Booking.status.in_(
                    [BookingStatus.pending, BookingStatus.confirmed]
                ),
            )
        )
    ).scalar() or 0
    if active_bookings > 0:
        raise HTTPException(
            status_code=409,
            detail=(
                f"لا يمكن الحذف: عليه {active_bookings} حجز نشط. "
                "ألغها أولاً أو أوقف العقار بدلاً من الحذف."
            ),
        )

    prop.deleted_at = datetime.now(timezone.utc)
    prop.is_available = False
    await db.flush()
    logger.info(
        "property_soft_deleted",
        property_id=property_id,
        owner_id=prop.owner_id,
        actor_id=user.id,
    )


@router.post("/{property_id}/images", response_model=PropertyOut)
async def upload_property_images(
    property_id: int,
    files: List[UploadFile] = File(...),
    user: User = Depends(require_role(UserRole.owner, UserRole.admin)),
    db: AsyncSession = Depends(get_db),
):
    """Upload up to 40 photos for a listing.

    Files are uploaded to S3 in parallel via :func:`asyncio.gather`,
    so a 40-photo batch finishes in roughly the latency of one PUT
    instead of summing 40 sequential round-trips (~20s freeze on a
    typical phone connection in the previous implementation).
    """
    try:
        result = await db.execute(
            select(Property).where(
                Property.id == property_id,
                Property.deleted_at.is_(None),
            )
        )
        prop = result.scalar_one_or_none()
        if prop is None:
            raise HTTPException(status_code=404, detail="العقار غير موجود / Property not found")
        if prop.owner_id != user.id and user.role != UserRole.admin:
            raise HTTPException(status_code=403, detail="ليس لديك صلاحية / Not your property")

        if len(files) > 40:
            raise HTTPException(
                status_code=400,
                detail="الحد الأقصى 40 صورة / Max 40 images",
            )

        # Pre-filter MIME types so we don't pay an S3 round-trip for
        # files we already know we'll reject.
        accepted: list[tuple[UploadFile, str]] = []
        rejected: list[dict[str, str | None]] = []
        for f in files:
            s3_ct = _normalise_image_ct(f.content_type, f.filename)
            if s3_ct is None:
                rejected.append({
                    "filename": f.filename,
                    "content_type": (f.content_type or "").lower() or None,
                })
                logger.warning(
                    "property_image_rejected_mime",
                    property_id=property_id,
                    filename=f.filename,
                    content_type=f.content_type,
                )
                continue
            accepted.append((f, s3_ct))

        async def _put_one(
            f: UploadFile, s3_ct: str
        ) -> tuple[UploadFile, str | None]:
            url = await upload_image(
                f.file,
                folder=f"properties/{property_id}",
                content_type=s3_ct,
            )
            return f, url

        # Parallel upload.  ``return_exceptions=True`` so one failed file
        # doesn't tank the whole batch — the caller still sees the
        # successes via the response body, and the failures via the
        # ``rejected`` list.
        results = await asyncio.gather(
            *[_put_one(f, s3_ct) for f, s3_ct in accepted],
            return_exceptions=True,
        )

        urls: list[str] = list(prop.images or [])
        for entry in results:
            if isinstance(entry, BaseException):
                logger.error(
                    "property_image_s3_upload_exception",
                    property_id=property_id,
                    error=str(entry),
                )
                rejected.append({"filename": None, "content_type": None})
                continue
            f, url = entry
            if url is None:
                rejected.append({"filename": f.filename, "content_type": f.content_type})
                logger.error(
                    "property_image_s3_upload_failed",
                    property_id=property_id,
                    filename=f.filename,
                )
                continue
            urls.append(url)

        # If the caller sent files but *none* survived the pipeline,
        # fail loudly rather than returning a misleading 200.
        if files and not any(r for r in results if not isinstance(r, BaseException) and r[1]) and rejected:
            raise HTTPException(
                status_code=400,
                detail={
                    "message": "فشل رفع كل الصور / All image uploads failed",
                    "rejected": rejected,
                },
            )

        prop.images = urls
        await db.flush()
        await db.refresh(prop)
        logger.info(
            "property_images_uploaded",
            property_id=property_id,
            accepted=len(files) - len(rejected),
            rejected=len(rejected),
            total_now=len(urls),
        )
        return PropertyOut.model_validate(prop)
    except HTTPException:
        raise
    except Exception as exc:
        logger.error(
            "property_images_upload_failed",
            property_id=property_id,
            error=repr(exc),
            error_type=type(exc).__name__,
        )
        raise HTTPException(
            status_code=500,
            detail=f"فشل رفع الصور: {type(exc).__name__}: {exc}",
        )


@router.post("/{property_id}/id-documents", response_model=PropertyOut)
async def upload_property_id_documents(
    property_id: int,
    front: UploadFile = File(..., description="ID front face, camera capture"),
    back: UploadFile = File(..., description="ID back face, camera capture"),
    user: User = Depends(require_role(UserRole.owner, UserRole.admin)),
    db: AsyncSession = Depends(get_db),
):
    """Owner uploads their national-ID front + back scans for KYC.

    These URLs are stored directly on the Property row so the admin
    dashboard can review them alongside the listing.  No ownership
    contract is required — the owner's personal ID is the only
    document Talaa collects from the owner side.
    """
    try:
        result = await db.execute(select(Property).where(Property.id == property_id))
        prop = result.scalar_one_or_none()
        if prop is None:
            raise HTTPException(status_code=404, detail="العقار غير موجود / Property not found")
        if prop.owner_id != user.id and user.role != UserRole.admin:
            raise HTTPException(
                status_code=403, detail="ليس لديك صلاحية / Not your property"
            )

        front_ct = _normalise_image_ct(front.content_type, front.filename)
        back_ct = _normalise_image_ct(back.content_type, back.filename)
        logger.info(
            "id_doc_upload_start",
            property_id=property_id,
            front_ct_raw=front.content_type,
            back_ct_raw=back.content_type,
            front_ct=front_ct,
            back_ct=back_ct,
        )
        if front_ct is None or back_ct is None:
            raise HTTPException(
                status_code=415,
                detail="صيغة الصورة غير مدعومة / Unsupported image format",
            )

        # Upload both faces in parallel.  Critical: if one of the two
        # PUTs succeeds and the other fails, we *must* delete the orphan
        # to avoid leaking national-ID scans into S3 with no DB pointer.
        front_url, back_url = await asyncio.gather(
            upload_image(
                front.file, folder=f"properties/{property_id}/id", content_type=front_ct,
            ),
            upload_image(
                back.file, folder=f"properties/{property_id}/id", content_type=back_ct,
            ),
        )
        if front_url is None or back_url is None:
            logger.error(
                "id_doc_s3_upload_returned_none",
                property_id=property_id,
                front_url=front_url,
                back_url=back_url,
            )
            # Roll back any partial upload so we never leave personal
            # documents orphaned in S3.
            if front_url is not None:
                try:
                    await delete_image(front_url)
                except Exception:  # pragma: no cover — best-effort cleanup
                    logger.exception(
                        "id_document_orphan_cleanup_failed",
                        url=front_url, property_id=property_id,
                    )
            if back_url is not None:
                try:
                    await delete_image(back_url)
                except Exception:  # pragma: no cover
                    logger.exception(
                        "id_document_orphan_cleanup_failed",
                        url=back_url, property_id=property_id,
                    )
            raise HTTPException(
                status_code=500,
                detail="فشل رفع البطاقة / Failed to upload ID images",
            )

        prop.id_document_front_url = front_url
        prop.id_document_back_url = back_url
        await db.flush()
        await db.refresh(prop)
        logger.info(
            "property_id_documents_uploaded",
            property_id=property_id, owner_id=user.id,
        )
        return PropertyOut.model_validate(prop)
    except HTTPException:
        raise
    except Exception as exc:
        logger.error(
            "id_doc_upload_failed",
            property_id=property_id,
            error=repr(exc),
            error_type=type(exc).__name__,
        )
        raise HTTPException(
            status_code=500,
            detail=f"فشل رفع البطاقة: {type(exc).__name__}: {exc}",
        )


@router.delete("/{property_id}/images", response_model=PropertyOut)
async def delete_property_image(
    property_id: int,
    image_url: str = Query(..., description="Full S3 URL of the image to delete"),
    background: BackgroundTasks = None,  # type: ignore[assignment]
    user: User = Depends(require_role(UserRole.owner, UserRole.admin)),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(Property).where(
            Property.id == property_id,
            Property.deleted_at.is_(None),
        )
    )
    prop = result.scalar_one_or_none()
    if prop is None:
        raise HTTPException(status_code=404, detail="العقار غير موجود / Property not found")
    if prop.owner_id != user.id and user.role != UserRole.admin:
        raise HTTPException(status_code=403, detail="ليس لديك صلاحية / Not your property")

    urls: list[str] = list(prop.images or [])
    if image_url not in urls:
        raise HTTPException(status_code=404, detail="الصورة غير موجودة / Image not found")

    # Update the DB *first*, then schedule the S3 delete as a
    # background task.  If the S3 call fails we leak one orphan
    # blob (cheap to GC nightly) instead of leaving a dangling URL
    # in the listing's image array — a much worse UX bug.
    urls.remove(image_url)
    prop.images = urls
    await db.flush()
    await db.refresh(prop)
    if background is not None:
        background.add_task(delete_image, image_url)
    else:
        # Tests / direct calls without a BackgroundTasks instance
        # fall back to inline delete; production always has it.
        await delete_image(image_url)
    return PropertyOut.model_validate(prop)
