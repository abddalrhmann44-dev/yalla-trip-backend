"""Wave 26 — disbursement reconciliation scheduler.

Background loop that catches payouts whose ``disburse_status``
got stuck because the success / failure webhook never arrived.
Webhook loss is rare on Kashier's side (they retry up to 5 times
over 24h) but happens routinely on *our* side: an API redeploy at
the wrong moment, a transient 5xx from a downstream notification
service, an HMAC tweak we forgot to coordinate.  Without this
sweeper a stuck payout silently parks money in flight and the
host has no way to recover.

Strategy
--------
Every :data:`DISBURSE_RECONCILE_INTERVAL_MIN` minutes we look up
payouts in :class:`DisburseStatus.initiated` / ``processing``
that:

* Have a ``disburse_ref`` (no ref = nothing to look up).
* Were initiated more than :data:`DISBURSE_SLA_HOURS` ago — we
  only chase the gateway *after* its own retry window has
  expired, otherwise we'd just race the in-flight webhook.

For each one we call :meth:`DisburseGateway.fetch_status` and
mirror the result back through the same code paths the webhook
handler uses (``mark_paid`` on success, ``disburse_status =
failed`` on failure, untouched otherwise so we look again next
sweep).

Design
------
* Same lifespan plumbing as :pymod:`cash_collection_scheduler`:
  ``start()`` / ``stop()`` are idempotent so worker reloads don't
  fork extra loops.
* Per-sweep DB session — never long-running transactions.
* Failures inside the loop are caught and logged; the scheduler
  must never crash the API process.
* A handful of UPDATEs per sweep, indexed on ``disburse_status``
  + ``created_at`` (the existing index combo is fine), so this
  is cheap to run hourly.
"""

from __future__ import annotations

import asyncio
from contextlib import suppress
from datetime import datetime, timedelta, timezone

import structlog
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.config import get_settings
from app.database import async_session
from app.models.payout import DisburseStatus, Payout, PayoutItem, PayoutStatus
from app.services import payout_service
from app.services.disburse import DisburseWebhook, get_disburse_gateway

logger = structlog.get_logger(__name__)
settings = get_settings()


def _sla_hours() -> int:
    """How long to wait after ``initiate`` before chasing the gateway.

    Reads at sweep time so ops can dial it up/down without a
    redeploy.  Defaults to the same value the contract docs the
    Kashier IBAN-transfer SLA at.
    """
    return int(getattr(settings, "DISBURSE_SLA_HOURS", 48))


def _interval_seconds() -> int:
    """Interval between sweeps.  Hourly by default — fine-grained
    enough to keep the host's "stuck for 3h" frustration window
    short, coarse enough that the gateway doesn't see polling abuse.
    """
    minutes = int(getattr(settings, "DISBURSE_RECONCILE_INTERVAL_MIN", 60))
    return max(60, minutes * 60)


async def _apply_status(
    db: AsyncSession, payout: Payout, parsed: DisburseWebhook
) -> str:
    """Mirror :func:`routers.payouts.disburse_webhook` for a polled
    status update.

    Returns a short tag (`succeeded` / `failed` / `still_processing`)
    so the loop can log a useful summary line.
    """
    if parsed.succeeded:
        payout.disburse_status = DisburseStatus.succeeded
        payout.disbursed_at = datetime.now(timezone.utc)
        if payout.status != PayoutStatus.paid:
            await payout_service.mark_paid(
                db, payout,
                reference_number=payout.disburse_ref or "auto-disbursed",
                admin_id=None,  # system-driven
                admin_notes=parsed.message,
            )
        # Append the polled response to the payload log so support
        # can see where the terminal state actually came from.
        payload_log = dict(payout.disburse_payload or {})
        payload_log.setdefault("reconciled", []).append(parsed.raw)
        payout.disburse_payload = payload_log
        return "succeeded"

    if parsed.failed:
        payout.disburse_status = DisburseStatus.failed
        payload_log = dict(payout.disburse_payload or {})
        payload_log.setdefault("reconciled", []).append(parsed.raw)
        payout.disburse_payload = payload_log
        return "failed"

    # Still in flight on the gateway side — leave as ``processing``
    # so the next sweep picks it up.  We do *not* flip from
    # ``initiated`` to ``processing`` here because that's the
    # webhook's job; doing so from a poll would mask a missed
    # initial PROCESSING webhook (useful diagnostic signal).
    return "still_processing"


async def sweep_once(db: AsyncSession) -> dict[str, int]:
    """Run one reconciliation sweep.

    Public so tests can drive a single iteration deterministically.
    Returns counters by outcome — handy for the logger and for
    /admin/health endpoints down the line.
    """
    cutoff = datetime.now(timezone.utc) - timedelta(hours=_sla_hours())

    stmt = (
        select(Payout)
        .where(
            Payout.disburse_status.in_(
                [DisburseStatus.initiated, DisburseStatus.processing]
            )
        )
        .where(Payout.disburse_ref.is_not(None))
        # Age the row off the *actual* disburse timestamp.  Falling
        # back to ``created_at`` keeps in-flight rows that pre-date
        # the column working until the next disburse stamps the new
        # field — see migration ``c4d9_payout_concurrency_hardening``
        # for the backfill that handles this gracefully.
        .where(
            func.coalesce(
                Payout.disburse_initiated_at, Payout.created_at
            ) < cutoff
        )
        .options(selectinload(Payout.items).selectinload(PayoutItem.booking))
    )
    rows = (await db.execute(stmt)).scalars().all()

    if not rows:
        return {"checked": 0, "succeeded": 0, "failed": 0, "still_processing": 0}

    gateway = get_disburse_gateway()
    counters = {"checked": 0, "succeeded": 0, "failed": 0, "still_processing": 0}

    for payout in rows:
        counters["checked"] += 1
        try:
            parsed = await gateway.fetch_status(payout.disburse_ref or "")
        except Exception as exc:  # pragma: no cover — defensive
            logger.warning(
                "disburse_reconcile_fetch_error",
                payout_id=payout.id,
                error=str(exc),
            )
            continue

        if parsed is None:
            # Gateway either doesn't support read-back, or returned
            # a payload we couldn't parse.  Surface as a noisy warn
            # so ops can investigate; we'll try again next sweep.
            logger.warning(
                "disburse_reconcile_no_status",
                payout_id=payout.id,
                provider_ref=payout.disburse_ref,
            )
            continue

        outcome = await _apply_status(db, payout, parsed)
        counters[outcome] += 1
        logger.info(
            "disburse_reconciled",
            payout_id=payout.id,
            provider_ref=payout.disburse_ref,
            outcome=outcome,
        )

    await db.commit()
    return counters


async def _run_loop() -> None:
    interval = _interval_seconds()
    logger.info(
        "disburse_reconciler_started",
        interval_seconds=interval,
        sla_hours=_sla_hours(),
    )
    while True:
        try:
            async with async_session() as db:
                counters = await sweep_once(db)
                if counters["checked"]:
                    logger.info("disburse_reconcile_sweep", **counters)
        except asyncio.CancelledError:
            logger.info("disburse_reconciler_stopped")
            raise
        except Exception as exc:  # pragma: no cover — defensive
            logger.error("disburse_reconcile_failed", error=str(exc))
        await asyncio.sleep(interval)


# ── Public lifespan helpers ──────────────────────────────────

_task: asyncio.Task | None = None


def start() -> asyncio.Task:
    global _task
    if _task is not None and not _task.done():
        return _task
    _task = asyncio.create_task(_run_loop(), name="disburse_reconciler")
    return _task


async def stop() -> None:
    global _task
    if _task is None:
        return
    _task.cancel()
    with suppress(asyncio.CancelledError):
        await _task
    _task = None
