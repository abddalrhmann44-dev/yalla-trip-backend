"""Host availability editor – per-date pricing, min-stay, closed days.

All endpoints require the caller to own the property (or be admin).
"""

from __future__ import annotations

import asyncio
from datetime import date, timedelta

import structlog
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import and_, delete, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.middleware.auth_middleware import get_current_active_user
from app.models.availability_rule import AvailabilityRule, RuleType
from app.models.booking import Booking, BookingStatus
from app.models.calendar import CalendarBlock
from app.models.property import Property
from app.models.user import User, UserRole
from app.schemas.availability import (
    AvailabilityRuleCreate,
    AvailabilityRuleOut,
    AvailabilityRuleUpdate,
    BulkDeleteRequest,
    BulkRulesCreate,
    DayDetail,
)

logger = structlog.get_logger(__name__)
router = APIRouter(prefix="/availability", tags=["Availability"])


# ── Helpers ────────────────────────────────────────────────
async def _check_owns_property(
    db: AsyncSession, property_id: int, user: User,
) -> None:
    """Lightweight ownership check used by mutation endpoints.

    Selects only ``owner_id`` instead of the full Property row — the
    previous version triggered ``lazy=selectin`` on the owner relation
    on every call (~6 endpoints), wasting one extra query per request
    just to enforce a permission check.
    """
    row = (
        await db.execute(
            select(Property.owner_id).where(
                Property.id == property_id,
                Property.deleted_at.is_(None),
            )
        )
    ).first()
    if row is None:
        raise HTTPException(status_code=404, detail="العقار غير موجود / Property not found")
    if row.owner_id != user.id and user.role != UserRole.admin:
        raise HTTPException(status_code=403, detail="ليس لديك صلاحية / Forbidden")


async def _get_own_property(
    db: AsyncSession, property_id: int, user: User,
) -> Property:
    """Return the full Property row if user owns it or is admin.

    Use this only when the caller actually needs the row data (e.g.
    pricing on the calendar grid).  For pure ownership checks call
    :func:`_check_owns_property` instead.
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
        raise HTTPException(status_code=403, detail="ليس لديك صلاحية / Forbidden")
    return prop


# ══════════════════════════════════════════════════════════════
#  CRUD – individual rules
# ══════════════════════════════════════════════════════════════

@router.get(
    "/{property_id}/rules",
    response_model=list[AvailabilityRuleOut],
)
async def list_rules(
    property_id: int,
    rule_type: RuleType | None = None,
    from_date: date | None = None,
    to_date: date | None = None,
    user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db),
):
    """List availability rules for a property the caller owns."""
    await _check_owns_property(db, property_id, user)

    stmt = (
        select(AvailabilityRule)
        .where(AvailabilityRule.property_id == property_id)
        .order_by(AvailabilityRule.start_date)
    )
    if rule_type:
        stmt = stmt.where(AvailabilityRule.rule_type == rule_type)
    if from_date:
        stmt = stmt.where(AvailabilityRule.end_date > from_date)
    if to_date:
        stmt = stmt.where(AvailabilityRule.start_date < to_date)

    rows = (await db.execute(stmt)).scalars().all()
    return [AvailabilityRuleOut.model_validate(r) for r in rows]


@router.post(
    "/{property_id}/rules",
    response_model=AvailabilityRuleOut,
    status_code=status.HTTP_201_CREATED,
)
async def create_rule(
    property_id: int,
    body: AvailabilityRuleCreate,
    user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db),
):
    """Create a single availability rule."""
    await _check_owns_property(db, property_id, user)

    rule = AvailabilityRule(
        property_id=property_id,
        rule_type=body.rule_type,
        start_date=body.start_date,
        end_date=body.end_date,
        price_override=body.price_override,
        min_nights=body.min_nights,
        label=body.label,
        note=body.note,
    )
    db.add(rule)
    await db.flush()
    await db.refresh(rule)
    logger.info("availability_rule_created", rule_id=rule.id, property_id=property_id)
    return AvailabilityRuleOut.model_validate(rule)


@router.put(
    "/{property_id}/rules/{rule_id}",
    response_model=AvailabilityRuleOut,
)
async def update_rule(
    property_id: int,
    rule_id: int,
    body: AvailabilityRuleUpdate,
    user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db),
):
    """Update an existing availability rule."""
    await _check_owns_property(db, property_id, user)

    result = await db.execute(
        select(AvailabilityRule).where(
            AvailabilityRule.id == rule_id,
            AvailabilityRule.property_id == property_id,
        )
    )
    rule = result.scalar_one_or_none()
    if rule is None:
        raise HTTPException(status_code=404, detail="القاعدة غير موجودة / Rule not found")

    for field, value in body.model_dump(exclude_unset=True).items():
        setattr(rule, field, value)

    # Re-validate date ordering
    if rule.end_date <= rule.start_date:
        raise HTTPException(
            status_code=422,
            detail="end_date must be after start_date",
        )

    await db.flush()
    await db.refresh(rule)
    return AvailabilityRuleOut.model_validate(rule)


@router.delete(
    "/{property_id}/rules/{rule_id}",
    status_code=status.HTTP_204_NO_CONTENT,
)
async def delete_rule(
    property_id: int,
    rule_id: int,
    user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db),
):
    """Delete a single availability rule."""
    await _check_owns_property(db, property_id, user)

    result = await db.execute(
        select(AvailabilityRule).where(
            AvailabilityRule.id == rule_id,
            AvailabilityRule.property_id == property_id,
        )
    )
    rule = result.scalar_one_or_none()
    if rule is None:
        raise HTTPException(status_code=404, detail="القاعدة غير موجودة / Rule not found")

    await db.delete(rule)
    await db.flush()


# ══════════════════════════════════════════════════════════════
#  Bulk operations (calendar editor batch save)
# ══════════════════════════════════════════════════════════════

@router.post(
    "/{property_id}/rules/bulk",
    response_model=list[AvailabilityRuleOut],
    status_code=status.HTTP_201_CREATED,
)
async def bulk_create_rules(
    property_id: int,
    body: BulkRulesCreate,
    user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db),
):
    """Create multiple rules at once (batch from calendar editor).

    The previous implementation called ``await db.refresh(r)`` for
    every rule — 30 refreshes for a 30-rule batch saved by the host
    on the calendar editor.  ``flush`` already populates ids and
    server defaults; the refresh loop was pure overhead.
    """
    await _check_owns_property(db, property_id, user)

    created = []
    for item in body.rules:
        rule = AvailabilityRule(
            property_id=property_id,
            rule_type=item.rule_type,
            start_date=item.start_date,
            end_date=item.end_date,
            price_override=item.price_override,
            min_nights=item.min_nights,
            label=item.label,
            note=item.note,
        )
        db.add(rule)
        created.append(rule)

    await db.flush()  # populates id + server-default created_at

    logger.info("availability_rules_bulk_created", count=len(created), property_id=property_id)
    return [AvailabilityRuleOut.model_validate(r) for r in created]


@router.post(
    "/{property_id}/rules/bulk-delete",
    status_code=status.HTTP_204_NO_CONTENT,
)
async def bulk_delete_rules(
    property_id: int,
    body: BulkDeleteRequest,
    user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db),
):
    """Delete multiple rules by ID."""
    await _check_owns_property(db, property_id, user)

    await db.execute(
        delete(AvailabilityRule).where(
            AvailabilityRule.id.in_(body.ids),
            AvailabilityRule.property_id == property_id,
        )
    )
    await db.flush()


# ══════════════════════════════════════════════════════════════
#  Calendar grid – per-day view for the Flutter calendar editor
# ══════════════════════════════════════════════════════════════

@router.get(
    "/{property_id}/calendar",
    response_model=list[DayDetail],
)
async def calendar_grid(
    property_id: int,
    start: date = Query(..., description="First day (inclusive)"),
    end: date = Query(..., description="Last day (exclusive)"),
    user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db),
):
    """Return per-day availability details for the Flutter calendar editor.

    Merges base pricing, rule overrides, bookings, and iCal blocks into
    a flat day-by-day list the UI can render directly.
    """
    if end <= start:
        raise HTTPException(status_code=422, detail="end must be after start")
    if (end - start).days > 366:
        raise HTTPException(status_code=422, detail="Range too large (max 366 days)")

    prop = await _get_own_property(db, property_id, user)

    # Fetch rules / bookings / blocks in parallel — they're independent
    # SELECTs and the previous serial path added 3× round-trip latency
    # to a hot endpoint the host hits every time they navigate months.
    rules_q = select(AvailabilityRule).where(
        AvailabilityRule.property_id == property_id,
        AvailabilityRule.start_date < end,
        AvailabilityRule.end_date > start,
    ).order_by(AvailabilityRule.created_at)
    bookings_q = select(Booking.check_in, Booking.check_out).where(
        Booking.property_id == property_id,
        Booking.status.in_([BookingStatus.pending, BookingStatus.confirmed]),
        Booking.check_in < end,
        Booking.check_out > start,
    )
    blocks_q = select(CalendarBlock.start_date, CalendarBlock.end_date).where(
        CalendarBlock.property_id == property_id,
        CalendarBlock.start_date < end,
        CalendarBlock.end_date > start,
    )
    rules_res, bookings_res, blocks_res = await asyncio.gather(
        db.execute(rules_q),
        db.execute(bookings_q),
        db.execute(blocks_q),
    )
    rules = rules_res.scalars().all()
    bookings = bookings_res.all()
    blocks = blocks_res.all()

    # Pre-compute per-day lookup arrays so the per-day loop becomes
    # O(days) instead of O(days × rules + days × bookings + days × blocks).
    # On a 12-month calendar with 200 bookings this is the difference
    # between ~100K and ~6K Python iterations.
    total_days = (end - start).days
    booked_arr = [False] * total_days
    blocked_arr = [False] * total_days
    rule_arr: list[list[AvailabilityRule]] = [[] for _ in range(total_days)]

    def _stamp(arr: list[bool], lo_d: date, hi_d: date) -> None:
        lo = max(0, (lo_d - start).days)
        hi = min(total_days, (hi_d - start).days)
        for i in range(lo, hi):
            arr[i] = True

    for ci, co in bookings:
        _stamp(booked_arr, ci, co)
    for bs, be in blocks:
        _stamp(blocked_arr, bs, be)
    for rule in rules:
        lo = max(0, (rule.start_date - start).days)
        hi = min(total_days, (rule.end_date - start).days)
        for i in range(lo, hi):
            rule_arr[i].append(rule)

    # Walk days using only the per-day buckets — cheap.
    days: list[DayDetail] = []
    weekend_price = prop.weekend_price or prop.price_per_night
    weekday_price = prop.price_per_night
    for i in range(total_days):
        day = start + timedelta(days=i)
        base_price = float(
            weekend_price if day.weekday() in (4, 5) else weekday_price
        )

        effective_price = base_price
        is_closed = False
        min_nights = 1
        labels: list[str] = []

        for rule in rule_arr[i]:
            if rule.rule_type == RuleType.pricing and rule.price_override is not None:
                effective_price = rule.price_override
                if rule.label:
                    labels.append(rule.label)
            elif rule.rule_type == RuleType.min_stay and rule.min_nights is not None:
                min_nights = max(min_nights, rule.min_nights)
            elif rule.rule_type == RuleType.closed:
                is_closed = True
                if rule.label:
                    labels.append(rule.label)

        days.append(DayDetail(
            date=day,
            base_price=base_price,
            effective_price=effective_price,
            is_closed=is_closed,
            min_nights=min_nights,
            is_booked=booked_arr[i],
            is_blocked=blocked_arr[i],
            labels=labels,
        ))

    return days
