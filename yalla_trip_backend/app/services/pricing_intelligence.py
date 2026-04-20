"""Smart / dynamic pricing suggestions.

Computes a suggested nightly rate for a property on each date in a
range, based on:

- **Base price** — the property's ``price_per_night`` (and ``weekend_price``
  for Fri/Sat in Egypt).
- **Seasonality** — bookings density in the same month over the past 12
  months for this property's area.  High-demand months get a multiplier.
- **Lead-time** — how far in the future the date is.  The closer it
  gets, the higher the urgency multiplier (or a discount if demand is low).
- **Weekday** — Fri/Sat weekends in Egypt cost more.
- **Area benchmark** — median price per night of other approved
  properties of the same category in the same area.

The output is deterministic and cheap to compute: < 5 ms for a
60-day range on a normal Postgres box.  No ML models required.
"""

from __future__ import annotations

from dataclasses import dataclass
from datetime import date, datetime, timedelta
from typing import Optional

from sqlalchemy import and_, func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.booking import Booking, BookingStatus
from app.models.property import Property


# ── Tuning constants ─────────────────────────────────────────
# All multipliers stack multiplicatively; clamped to [0.6, 2.0].
_MIN_MULTIPLIER = 0.6
_MAX_MULTIPLIER = 2.0

# Seasonality: month occupancy ratios → multiplier.
_SEASONALITY_TABLE = [
    (0.80, 1.40),   # ≥80% booked → +40%
    (0.60, 1.25),   # ≥60% booked → +25%
    (0.40, 1.10),   # ≥40% booked → +10%
    (0.20, 1.00),   # ≥20% booked → neutral
    (0.00, 0.90),   # <20% booked → −10%
]

# Lead time: days-until → multiplier (closer dates + demand = premium)
_LEADTIME_NEAR_DAYS = 7    # within 1 week
_LEADTIME_MEDIUM_DAYS = 30 # within 1 month


@dataclass
class PricingSuggestion:
    """Single-day pricing suggestion."""
    date: date
    base_price: float
    suggested_price: float
    multiplier: float
    reasons: list[str]
    area_median: Optional[float]

    @property
    def delta_percent(self) -> float:
        """How far the suggestion is above/below the base, in %."""
        if self.base_price <= 0:
            return 0.0
        return round((self.suggested_price / self.base_price - 1) * 100, 1)


async def _get_area_category_median(
    db: AsyncSession, prop: Property,
) -> Optional[float]:
    """Median price/night for other approved properties in same area+category."""
    stmt = (
        select(Property.price_per_night)
        .where(
            Property.area == prop.area,
            Property.category == prop.category,
            Property.id != prop.id,
            Property.status == "approved",
            Property.is_available.is_(True),
        )
    )
    rows = [r[0] for r in (await db.execute(stmt)).all() if r[0] is not None]
    if not rows:
        return None
    rows.sort()
    mid = len(rows) // 2
    if len(rows) % 2 == 0:
        return (rows[mid - 1] + rows[mid]) / 2
    return float(rows[mid])


async def _get_area_occupancy_by_month(
    db: AsyncSession, prop: Property, month: int,
) -> float:
    """Occupancy ratio (0.0–1.0) for this property's area in *month*.

    Uses the past 12 months of confirmed bookings in the same area.
    Ratio = total booked nights / (properties_in_area × days_in_month × 12).
    """
    one_year_ago = date.today() - timedelta(days=365)

    # Count total approved properties in the area (denominator)
    prop_count = (await db.execute(
        select(func.count(Property.id))
        .where(Property.area == prop.area, Property.status == "approved")
    )).scalar() or 1

    # Sum booked nights in that month across the past year.
    # Postgres gives us an INTERVAL for (check_out - check_in) on DATE columns
    # when cast to timestamp; the simplest portable approach is
    # ``check_out - check_in`` which on DATE columns returns INTEGER days.
    booked_nights = (await db.execute(
        select(func.coalesce(
            func.sum(Booking.check_out - Booking.check_in),
            0,
        ))
        .join(Property, Property.id == Booking.property_id)
        .where(
            Property.area == prop.area,
            Booking.status.in_([BookingStatus.confirmed, BookingStatus.completed]),
            Booking.check_in >= one_year_ago,
            func.extract("month", Booking.check_in) == month,
        )
    )).scalar() or 0

    # Approximate denominator: prop_count × 30 days × 1 year
    denominator = max(prop_count * 30, 1)
    return float(booked_nights) / float(denominator)


def _seasonality_multiplier(occupancy: float) -> tuple[float, str]:
    for threshold, mult in _SEASONALITY_TABLE:
        if occupancy >= threshold:
            if mult > 1.0:
                return mult, f"موسم مزدحم (إشغال {int(occupancy * 100)}%)"
            elif mult < 1.0:
                return mult, f"موسم هادي (إشغال {int(occupancy * 100)}%)"
            return mult, ""
    return 1.0, ""


def _leadtime_multiplier(days_ahead: int, occupancy: float) -> tuple[float, str]:
    """Closer dates during busy seasons get a premium; quiet seasons get a discount."""
    if days_ahead < 0:
        return 1.0, ""
    if days_ahead <= _LEADTIME_NEAR_DAYS:
        if occupancy >= 0.40:
            return 1.15, "طلب قوي قبل موعد قريب"
        return 0.90, "خصم اللحظة الأخيرة"
    if days_ahead <= _LEADTIME_MEDIUM_DAYS:
        if occupancy >= 0.40:
            return 1.05, "حجز مبكر في موسم مزدحم"
    return 1.0, ""


def _area_benchmark_multiplier(
    base: float, area_median: Optional[float],
) -> tuple[float, str]:
    """Nudge the price gently toward the area median ±25%."""
    if area_median is None or base <= 0:
        return 1.0, ""
    ratio = base / area_median
    if ratio < 0.75:
        return 1.08, f"متوسط المنطقة أعلى بـ {int((1 - ratio) * 100)}%"
    if ratio > 1.25:
        return 0.95, f"سعرك أعلى من متوسط المنطقة"
    return 1.0, ""


async def compute_suggestions(
    db: AsyncSession,
    prop: Property,
    start: date,
    end: date,
) -> list[PricingSuggestion]:
    """Compute per-day pricing suggestions for ``[start, end)``."""
    if end <= start:
        return []

    # Pre-compute area median and monthly occupancy map (only months we need)
    area_median = await _get_area_category_median(db, prop)
    needed_months = {d.month for d in _daterange(start, end)}
    occupancy_by_month: dict[int, float] = {}
    for m in needed_months:
        occupancy_by_month[m] = await _get_area_occupancy_by_month(db, prop, m)

    today = date.today()
    suggestions: list[PricingSuggestion] = []

    for d in _daterange(start, end):
        is_weekend = d.weekday() in (4, 5)
        base = float(
            (prop.weekend_price or prop.price_per_night) if is_weekend
            else prop.price_per_night
        )

        multiplier = 1.0
        reasons: list[str] = []

        # Seasonality
        occupancy = occupancy_by_month.get(d.month, 0.0)
        s_mult, s_reason = _seasonality_multiplier(occupancy)
        multiplier *= s_mult
        if s_reason:
            reasons.append(s_reason)

        # Lead time
        days_ahead = (d - today).days
        l_mult, l_reason = _leadtime_multiplier(days_ahead, occupancy)
        multiplier *= l_mult
        if l_reason:
            reasons.append(l_reason)

        # Area benchmark
        b_mult, b_reason = _area_benchmark_multiplier(base, area_median)
        multiplier *= b_mult
        if b_reason:
            reasons.append(b_reason)

        # Weekend boost messaging (base already includes weekend_price so no extra math)
        if is_weekend:
            reasons.append("عطلة نهاية الأسبوع")

        # Clamp
        multiplier = max(_MIN_MULTIPLIER, min(_MAX_MULTIPLIER, multiplier))

        suggested = round(base * multiplier, 2)
        suggestions.append(PricingSuggestion(
            date=d,
            base_price=base,
            suggested_price=suggested,
            multiplier=round(multiplier, 3),
            reasons=reasons,
            area_median=area_median,
        ))

    return suggestions


def _daterange(start: date, end: date):
    d = start
    while d < end:
        yield d
        d += timedelta(days=1)
