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


async def eligible_bookings_query(
    db: AsyncSession,
    *,
    host_id: int | None = None,
    cycle_start: date | None = None,
    cycle_end: date | None = None,
):
    """Build (but don't execute) the SELECT for payable bookings."""
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
    return select(Booking).where(and_(*conds)).order_by(Booking.owner_id, Booking.id)


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
    """
    stmt = await eligible_bookings_query(
        db,
        host_id=host_id,
        cycle_start=cycle_start,
        cycle_end=cycle_end,
    )
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
    """Compute host-facing payout totals in one round trip."""
    rows = await db.execute(
        select(Booking.payout_status, func.coalesce(func.sum(Booking.owner_payout), 0))
        .where(Booking.owner_id == host_id)
        .group_by(Booking.payout_status)
    )
    totals = {status: float(amount) for status, amount in rows.all()}

    eligible_count = (
        await db.execute(
            select(func.count(Booking.id)).where(
                Booking.owner_id == host_id,
                Booking.status == BookingStatus.completed,
                Booking.payment_status == PaymentStatus.paid,
                Booking.payout_status == BookingPayoutStatus.unpaid.value,
                Booking.check_out <= _hold_cutoff().date(),
            )
        )
    ).scalar() or 0

    last_paid = (
        await db.execute(
            select(Payout.processed_at)
            .where(Payout.host_id == host_id, Payout.status == PayoutStatus.paid)
            .order_by(Payout.processed_at.desc())
            .limit(1)
        )
    ).scalar_one_or_none()

    return {
        "pending_balance": totals.get(BookingPayoutStatus.unpaid.value, 0.0),
        "queued_balance": totals.get(BookingPayoutStatus.queued.value, 0.0),
        "paid_total": totals.get(BookingPayoutStatus.paid.value, 0.0),
        "last_paid_at": last_paid,
        "eligible_booking_count": int(eligible_count),
    }
