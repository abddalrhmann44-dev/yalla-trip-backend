"""Wave 25 — auto-dispute scheduler for cash-on-arrival bookings.

Background loop that flips one-sided cash-collection confirmations
into the ``disputed`` state once 48 h have elapsed without the
counter-party signing off.  This is the safety valve for the
deposit + cash-on-arrival flow:

* Host marks "received" but the guest never confirms ⇒ either the
  guest forgot, or the host is trying to release the payout without
  actually collecting cash.  Either way, an admin needs to look.
* Guest marks "arrived" but the host never confirms ⇒ either the
  host forgot, or the guest is trying to release the payout without
  having paid.  Same admin-review outcome.

The dispute window is configurable via ``CASH_DISPUTE_TIMEOUT_HOURS``
(default 48).  We sweep every ``CASH_DISPUTE_SWEEP_INTERVAL_MIN``
minutes (default 30); the cost of a sweep is one indexed query plus
a handful of UPDATEs, so this is cheap to run frequently.

Design notes
------------
* The scheduler is started from the FastAPI lifespan, so it shuts
  down cleanly on SIGTERM and never outlives the worker process.
* It uses :func:`get_db` to acquire a fresh session per sweep — this
  matches the rest of the codebase and avoids long-running
  transactions that block migrations.
* Failures inside the loop are caught and logged; the scheduler must
  *never* crash the API process.
* The function is idempotent: re-running a sweep is a no-op once
  every eligible booking has been dispute-flagged.
"""

from __future__ import annotations

import asyncio
from contextlib import suppress
from datetime import datetime, timedelta, timezone

import structlog
from sqlalchemy import or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import get_settings
from app.database import async_session
from app.models.booking import Booking, CashCollectionStatus
from app.models.notification import NotificationType
from app.services.notification_service import create_notification

logger = structlog.get_logger(__name__)
settings = get_settings()


def _timeout_hours() -> int:
    """Read the dispute window at sweep time so ops can tune it
    without a redeploy (env var change + worker restart suffices)."""
    return int(getattr(settings, "CASH_DISPUTE_TIMEOUT_HOURS", 48))


def _sweep_interval_seconds() -> int:
    """Interval between sweeps, in seconds.  Defaults to 30 minutes
    which gives a worst-case 30 min latency on top of the 48 h
    timeout — well within the precision admins need."""
    minutes = int(getattr(settings, "CASH_DISPUTE_SWEEP_INTERVAL_MIN", 30))
    return max(60, minutes * 60)  # never spin tighter than 1 min


async def _flag_disputed(db: AsyncSession, booking: Booking) -> None:
    """Move ``booking`` to ``disputed`` and ping both parties + ops.

    The function is intentionally narrow — it only writes the
    state-transition + notifications.  The actual financial fallout
    (refunds / payouts) is decided by an admin reviewing the
    dispute, never by the scheduler.
    """
    booking.cash_collection_status = CashCollectionStatus.disputed
    await db.flush()

    # Guest + host get the same wording in Arabic so neither side
    # feels singled out.  The translation layer can refine later.
    body = (
        f"لم يكتمل تأكيد استلام الكاش لحجز {booking.booking_code}. "
        "تم تحويل الحالة إلى المراجعة، وسيتواصل معك فريق الدعم."
    )
    for user_id in (booking.guest_id, booking.owner_id):
        with suppress(Exception):
            await create_notification(
                db,
                user_id,
                title="حجز قيد المراجعة",
                body=body,
                notif_type=NotificationType.booking_cancelled,
            )

    logger.info(
        "cash_collection_disputed",
        booking_id=booking.id,
        booking_code=booking.booking_code,
        owner_confirmed_at=booking.owner_cash_confirmed_at,
        guest_confirmed_at=booking.guest_arrival_confirmed_at,
    )


async def sweep_once(db: AsyncSession) -> int:
    """Run one dispute sweep.  Returns the number of bookings flagged.

    Exposed publicly so the test suite (and ad-hoc CLI invocations)
    can drive a single iteration deterministically without spinning
    up the asyncio loop.
    """
    cutoff = datetime.now(timezone.utc) - timedelta(hours=_timeout_hours())

    # We're looking for bookings that have been sitting in a
    # one-sided confirmation state past the cutoff.  The OR-of-ANDs
    # below maps directly onto that:
    #   * owner_confirmed AND owner_cash_confirmed_at < cutoff
    #   * guest_confirmed AND guest_arrival_confirmed_at < cutoff
    stmt = select(Booking).where(
        or_(
            (Booking.cash_collection_status
                == CashCollectionStatus.owner_confirmed)
            & (Booking.owner_cash_confirmed_at < cutoff),
            (Booking.cash_collection_status
                == CashCollectionStatus.guest_confirmed)
            & (Booking.guest_arrival_confirmed_at < cutoff),
        )
    )
    rows = (await db.execute(stmt)).scalars().all()
    for booking in rows:
        await _flag_disputed(db, booking)

    if rows:
        await db.commit()
    return len(rows)


async def _run_loop() -> None:
    """Top-level loop owned by the FastAPI lifespan.

    Each iteration runs in its own DB session so a stray exception
    can never poison the next sweep.  The sleep happens *after* the
    work, so if the scheduler crashes mid-sweep and is restarted by
    uvicorn's auto-reload it picks up immediately rather than
    waiting for a full interval.
    """
    interval = _sweep_interval_seconds()
    logger.info(
        "cash_collection_scheduler_started",
        interval_seconds=interval,
        timeout_hours=_timeout_hours(),
    )
    while True:
        try:
            async with async_session() as db:
                flagged = await sweep_once(db)
                if flagged:
                    logger.info(
                        "cash_collection_sweep_flagged",
                        count=flagged,
                    )
        except asyncio.CancelledError:
            # Lifespan shutdown — break cleanly so the task ends.
            logger.info("cash_collection_scheduler_stopped")
            raise
        except Exception as exc:  # pragma: no cover — defensive
            # Never let the loop die: log and keep ticking.
            logger.error("cash_collection_sweep_failed", error=str(exc))
        await asyncio.sleep(interval)


# ── Public lifespan helpers ──────────────────────────────────

_task: asyncio.Task | None = None


def start() -> asyncio.Task:
    """Spin up the background loop and return the task handle.

    Idempotent — calling ``start`` while a task is already running is
    a no-op so worker auto-reloads don't fork extra schedulers.
    """
    global _task
    if _task is not None and not _task.done():
        return _task
    _task = asyncio.create_task(_run_loop(), name="cash_collection_scheduler")
    return _task


async def stop() -> None:
    """Cancel the background loop and wait for it to wind down."""
    global _task
    if _task is None:
        return
    _task.cancel()
    with suppress(asyncio.CancelledError):
        await _task
    _task = None
