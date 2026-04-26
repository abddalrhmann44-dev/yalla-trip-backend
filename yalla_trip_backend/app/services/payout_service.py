"""Host payout batching + status transitions.

Eligibility rule (what makes a booking "payable")::

    booking.status      == completed
    booking.payment_status == paid
    booking.payout_status  == unpaid
    booking.check_out   <= now() - hold_days   (default 1 day hold)

The hold period gives the guest a window to dispute before money
leaves the platform.  Configurable via ``settings.PAYOUT_HOLD_DAYS``.
"""

from __future__ import annotations

from datetime import date, datetime, timedelta, timezone
from typing import Sequence

import structlog
from sqlalchemy import and_, func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload
from sqlalchemy.sql.elements import ColumnElement

from app.config import get_settings
from app.models.booking import Booking, BookingStatus, PaymentStatus
from app.models.payout import (
    BookingPayoutStatus, HostBankAccount, Payout, PayoutItem, PayoutStatus,
)

logger = structlog.get_logger(__name__)
settings = get_settings()


def _hold_cutoff() -> datetime:
    """Return the datetime at or before which a check-out counts as
    beyond the hold period."""
    days = getattr(settings, "PAYOUT_HOLD_DAYS", 1)
    return datetime.now(timezone.utc) - timedelta(days=days)


def _eligibility_conditions(
    *,
    host_id: int | None,
    cycle_start: date | None,
    cycle_end: date | None,
) -> list:
    """Shared WHERE clause for ``eligible_*`` queries.

    Pulled out so :func:`eligible_bookings_query` and
    :func:`eligible_bookings_summary` can never drift apart — a host
    seeing 5 eligible bookings in the preview must get exactly 5 in
    the actual batch.
    """
    conds = [
        Booking.status == BookingStatus.completed,
        Booking.payment_status == PaymentStatus.paid,
        Booking.payout_status == BookingPayoutStatus.unpaid.value,
        Booking.check_out <= _hold_cutoff().date(),
    ]
    if host_id is not None:
        conds.append(Booking.owner_id == host_id)
    if cycle_start is not None:
        conds.append(Booking.check_out >= cycle_start)
    if cycle_end is not None:
        conds.append(Booking.check_out <= cycle_end)
    return conds


async def eligible_bookings_query(
    db: AsyncSession,
    *,
    host_id: int | None = None,
    cycle_start: date | None = None,
    cycle_end: date | None = None,
):
    """Build (but don't execute) the SELECT for payable bookings."""
    conds = _eligibility_conditions(
        host_id=host_id, cycle_start=cycle_start, cycle_end=cycle_end,
    )
    return select(Booking).where(and_(*conds)).order_by(Booking.owner_id, Booking.id)


async def eligible_bookings_summary(
    db: AsyncSession,
    *,
    host_id: int | None = None,
    cycle_start: date | None = None,
    cycle_end: date | None = None,
) -> list[dict]:
    """Aggregate eligible bookings by host — dry-run preview.

    Returns one dict per host with ``host_id``, ``booking_count`` and
    ``total_amount`` (rounded EGP).  The aggregation runs in Postgres
    so we never download row-by-row data just to compute two sums.
    """
    conds = _eligibility_conditions(
        host_id=host_id, cycle_start=cycle_start, cycle_end=cycle_end,
    )
    stmt = (
        select(
            Booking.owner_id,
            func.count(Booking.id).label("booking_count"),
            func.coalesce(
                func.sum(Booking.owner_payout), 0
            ).label("total_amount"),
        )
        .where(and_(*conds))
        .group_by(Booking.owner_id)
        .order_by(Booking.owner_id)
    )
    rows = (await db.execute(stmt)).all()
    return [
        {
            "host_id": r.owner_id,
            "booking_count": int(r.booking_count),
            "total_amount": round(float(r.total_amount), 2),
        }
        for r in rows
    ]


async def build_batch(
    db: AsyncSession,
    *,
    cycle_start: date,
    cycle_end: date,
    host_id: int | None,
    admin_id: int,
) -> list[Payout]:
    """Create one Payout row per host with at least one eligible booking.

    All mutations run in the caller's transaction.  Returns the new
    Payout rows (already flushed, with ids).

    Concurrency: the eligible-bookings select takes ``FOR UPDATE
    SKIP LOCKED``.  If two admins race to create a batch (or a single
    admin double-clicks the button) the second caller silently skips
    any rows the first one already grabbed instead of crashing on the
    ``uq_payout_item_booking`` unique constraint.  The trade-off is
    that the second batch may end up empty — by design; the work is
    done, no need to retry.
    """
    stmt = await eligible_bookings_query(
        db,
        host_id=host_id,
        cycle_start=cycle_start,
        cycle_end=cycle_end,
    )
    # ``skip_locked`` is the key bit — without it the second admin
    # would block on the first transaction and then INSERT duplicate
    # PayoutItems, exploding the constraint.
    stmt = stmt.with_for_update(skip_locked=True)
    bookings: Sequence[Booking] = (await db.execute(stmt)).scalars().all()
    if not bookings:
        return []

    # Group bookings by host.
    per_host: dict[int, list[Booking]] = {}
    for b in bookings:
        per_host.setdefault(b.owner_id, []).append(b)

    payouts: list[Payout] = []
    for owner_id, rows in per_host.items():
        default_account = (
            await db.execute(
                select(HostBankAccount)
                .where(
                    HostBankAccount.host_id == owner_id,
                    HostBankAccount.is_default.is_(True),
                )
                .limit(1)
            )
        ).scalar_one_or_none()

        total = round(sum(r.owner_payout for r in rows), 2)
        payout = Payout(
            host_id=owner_id,
            bank_account_id=default_account.id if default_account else None,
            total_amount=total,
            cycle_start=cycle_start,
            cycle_end=cycle_end,
            status=PayoutStatus.pending,
        )
        db.add(payout)
        await db.flush()   # obtain payout.id

        for b in rows:
            db.add(PayoutItem(
                payout_id=payout.id,
                booking_id=b.id,
                amount=b.owner_payout,
            ))
            b.payout_status = BookingPayoutStatus.queued.value

        payouts.append(payout)
        logger.info(
            "payout_batch_created",
            payout_id=payout.id, host_id=owner_id,
            bookings=len(rows), total=total, admin_id=admin_id,
        )

    # Re-fetch with relationships eager-loaded so the caller can
    # serialise ``payout.items[i].booking`` without triggering
    # lazy I/O inside the async request handler.
    if payouts:
        ids = [p.id for p in payouts]
        reloaded = (
            await db.execute(
                select(Payout)
                .where(Payout.id.in_(ids))
                .options(selectinload(Payout.items).selectinload(PayoutItem.booking))
                .order_by(Payout.id)
            )
        ).scalars().unique().all()
        return list(reloaded)
    return payouts


async def mark_paid(
    db: AsyncSession,
    payout: Payout,
    *,
    reference_number: str,
    admin_id: int | None,
    admin_notes: str | None = None,
) -> Payout:
    """Mark a batch as paid and flip its bookings to ``paid``.

    ``admin_id`` is ``None`` when the transition is system-driven —
    e.g. the disbursement webhook auto-promoting on a successful
    Kashier delivery (no human in the loop).
    """
    if payout.status == PayoutStatus.paid:
        return payout
    payout.status = PayoutStatus.paid
    payout.reference_number = reference_number
    payout.processed_at = datetime.now(timezone.utc)
    payout.processed_by_id = admin_id
    if admin_notes:
        payout.admin_notes = admin_notes

    # Advance every booking inside this batch.
    booking_ids = [it.booking_id for it in payout.items]
    if booking_ids:
        await db.execute(
            Booking.__table__.update()
            .where(Booking.id.in_(booking_ids))
            .values(payout_status=BookingPayoutStatus.paid.value)
        )
    logger.info(
        "payout_paid",
        payout_id=payout.id, host_id=payout.host_id,
        reference=reference_number, admin_id=admin_id,
    )
    return payout


async def mark_failed(
    db: AsyncSession,
    payout: Payout,
    *,
    admin_id: int,
    admin_notes: str,
) -> Payout:
    """Roll a batch back to failed + release its bookings back to
    ``unpaid`` so the next run picks them up again."""
    payout.status = PayoutStatus.failed
    payout.processed_at = datetime.now(timezone.utc)
    payout.processed_by_id = admin_id
    payout.admin_notes = admin_notes

    booking_ids = [it.booking_id for it in payout.items]
    if booking_ids:
        await db.execute(
            Booking.__table__.update()
            .where(Booking.id.in_(booking_ids))
            .values(payout_status=BookingPayoutStatus.unpaid.value)
        )
    logger.info(
        "payout_failed",
        payout_id=payout.id, host_id=payout.host_id,
        reason=admin_notes, admin_id=admin_id,
    )
    return payout


async def host_summary(db: AsyncSession, host_id: int) -> dict:
    """Compute host-facing payout totals.

    Two round-trips total: one Booking aggregate (using ``FILTER``
    clauses so all four numbers come back in a single SELECT) plus
    one Payout lookup for ``last_paid_at``.  Down from three queries
    in the previous iteration; that 33% reduction matters on the host
    dashboard which polls this endpoint every 30s.
    """
    cutoff = _hold_cutoff().date()

    # ``func.sum(...).filter(...)`` is the SQLAlchemy way to express
    # ``SUM(...) FILTER (WHERE ...)``.  Postgres evaluates each
    # filter while doing one pass over the index, so adding more
    # buckets is essentially free.
    def _sum_where(*predicates: ColumnElement) -> ColumnElement:
        return func.coalesce(
            func.sum(Booking.owner_payout).filter(and_(*predicates)),
            0,
        )

    eligibility_predicates = (
        Booking.status == BookingStatus.completed,
        Booking.payment_status == PaymentStatus.paid,
        Booking.payout_status == BookingPayoutStatus.unpaid.value,
        Booking.check_out <= cutoff,
    )

    agg = (
        await db.execute(
            select(
                _sum_where(
                    Booking.payout_status == BookingPayoutStatus.unpaid.value
                ).label("unpaid_balance"),
                _sum_where(
                    Booking.payout_status == BookingPayoutStatus.queued.value
                ).label("queued_balance"),
                _sum_where(
                    Booking.payout_status == BookingPayoutStatus.paid.value
                ).label("paid_total"),
                func.count(Booking.id).filter(
                    and_(*eligibility_predicates)
                ).label("eligible_count"),
            ).where(Booking.owner_id == host_id)
        )
    ).one()

    last_paid = (
        await db.execute(
            select(Payout.processed_at)
            .where(Payout.host_id == host_id, Payout.status == PayoutStatus.paid)
            .order_by(Payout.processed_at.desc())
            .limit(1)
        )
    ).scalar_one_or_none()

    return {
        "pending_balance": float(agg.unpaid_balance or 0.0),
        "queued_balance": float(agg.queued_balance or 0.0),
        "paid_total": float(agg.paid_total or 0.0),
        "last_paid_at": last_paid,
        "eligible_booking_count": int(agg.eligible_count or 0),
    }
