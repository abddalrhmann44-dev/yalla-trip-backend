"""Properties router – list / detail / CRUD / image upload."""

from __future__ import annotations

import math
from collections import Counter
from datetime import date, timedelta
from typing import List, Optional

import structlog
from fastapi import APIRouter, Depends, HTTPException, Query, UploadFile, File, status
from sqlalchemy import Select, func, select, and_
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.middleware.auth_middleware import get_current_active_user, require_role
from app.models.booking import Booking, BookingStatus
from app.models.property import Area, Category, Property
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


def _apply_filters(
    stmt: Select,
    area: Optional[Area],
    category: Optional[Category],
    min_price: Optional[float],
    max_price: Optional[float],
    min_rating: Optional[float],
    bedrooms: Optional[int],
    max_guests: Optional[int],
    instant_booking: Optional[bool],
    search: Optional[str],
) -> Select:
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
    if search:
        stmt = stmt.where(Property.name.ilike(f"%{search}%"))
    stmt = stmt.where(Property.is_available == True)  # noqa: E712
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
    sort_by: str = Query("newest", pattern=r"^(price_asc|price_desc|rating|newest)$"),
    latitude: Optional[float] = None,
    longitude: Optional[float] = None,
    radius_km: Optional[float] = Query(None, gt=0),
    db: AsyncSession = Depends(get_db),
):
    stmt = select(Property)
    stmt = _apply_filters(
        stmt, area, category, min_price, max_price,
        min_rating, bedrooms, max_guests, instant_booking, search,
    )

    # distance filter
    if latitude is not None and longitude is not None and radius_km is not None:
        dist = _distance_expr(latitude, longitude)
        stmt = stmt.where(
            and_(Property.latitude.isnot(None), Property.longitude.isnot(None))
        ).where(dist <= radius_km)

    # sorting
    if sort_by == "price_asc":
        stmt = stmt.order_by(Property.price_per_night.asc())
    elif sort_by == "price_desc":
        stmt = stmt.order_by(Property.price_per_night.desc())
    elif sort_by == "rating":
        stmt = stmt.order_by(Property.rating.desc())
    else:
        stmt = stmt.order_by(Property.created_at.desc())

    # count
    count_stmt = select(func.count()).select_from(stmt.subquery())
    total = (await db.execute(count_stmt)).scalar() or 0
    pages = math.ceil(total / limit) if total else 0

    # paginate
    stmt = stmt.offset((page - 1) * limit).limit(limit)
    rows = (await db.execute(stmt)).scalars().all()

    return PaginatedResponse(
        items=[PropertyOut.model_validate(r) for r in rows],
        total=total,
        page=page,
        limit=limit,
        pages=pages,
    )


@router.get("/{property_id}", response_model=PropertyOut)
async def get_property(property_id: int, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(Property).where(Property.id == property_id))
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
    prop = Property(**body.model_dump(), owner_id=user.id)
    db.add(prop)
    await db.flush()
    await db.refresh(prop)
    logger.info("property_created", property_id=prop.id, owner_id=user.id)
    return PropertyOut.model_validate(prop)


@router.put("/{property_id}", response_model=PropertyOut)
async def update_property(
    property_id: int,
    body: PropertyUpdate,
    user: User = Depends(require_role(UserRole.owner, UserRole.admin)),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(Property).where(Property.id == property_id))
    prop = result.scalar_one_or_none()
    if prop is None:
        raise HTTPException(status_code=404, detail="العقار غير موجود / Property not found")
    if prop.owner_id != user.id and user.role != UserRole.admin:
        raise HTTPException(status_code=403, detail="ليس لديك صلاحية / Not your property")

    for key, value in body.model_dump(exclude_unset=True).items():
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
    result = await db.execute(select(Property).where(Property.id == property_id))
    prop = result.scalar_one_or_none()
    if prop is None:
        raise HTTPException(status_code=404, detail="العقار غير موجود / Property not found")
    if prop.owner_id != user.id and user.role != UserRole.admin:
        raise HTTPException(status_code=403, detail="ليس لديك صلاحية / Not your property")
    await db.delete(prop)
    await db.flush()


@router.post("/{property_id}/images", response_model=PropertyOut)
async def upload_property_images(
    property_id: int,
    files: List[UploadFile] = File(...),
    user: User = Depends(require_role(UserRole.owner, UserRole.admin)),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(Property).where(Property.id == property_id))
    prop = result.scalar_one_or_none()
    if prop is None:
        raise HTTPException(status_code=404, detail="العقار غير موجود / Property not found")
    if prop.owner_id != user.id and user.role != UserRole.admin:
        raise HTTPException(status_code=403, detail="ليس لديك صلاحية / Not your property")

    if len(files) > 10:
        raise HTTPException(status_code=400, detail="الحد الأقصى 10 صور / Max 10 images")

    urls: list[str] = list(prop.images or [])
    for f in files:
        if f.content_type not in ("image/jpeg", "image/png", "image/webp"):
            continue
        url = await upload_image(f.file, folder=f"properties/{property_id}", content_type=f.content_type)
        if url is not None:
            urls.append(url)

    prop.images = urls
    await db.flush()
    await db.refresh(prop)
    return PropertyOut.model_validate(prop)


@router.delete("/{property_id}/images", response_model=PropertyOut)
async def delete_property_image(
    property_id: int,
    image_url: str = Query(..., description="Full S3 URL of the image to delete"),
    user: User = Depends(require_role(UserRole.owner, UserRole.admin)),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(select(Property).where(Property.id == property_id))
    prop = result.scalar_one_or_none()
    if prop is None:
        raise HTTPException(status_code=404, detail="العقار غير موجود / Property not found")
    if prop.owner_id != user.id and user.role != UserRole.admin:
        raise HTTPException(status_code=403, detail="ليس لديك صلاحية / Not your property")

    urls: list[str] = list(prop.images or [])
    if image_url not in urls:
        raise HTTPException(status_code=404, detail="الصورة غير موجودة / Image not found")

    await delete_image(image_url)
    urls.remove(image_url)
    prop.images = urls
    await db.flush()
    await db.refresh(prop)
    return PropertyOut.model_validate(prop)
