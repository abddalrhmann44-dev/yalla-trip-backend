"""Host payout endpoints.

* ``/payouts/bank-accounts`` – host manages their accounts.
* ``/payouts/me``            – host sees their payout history.
* ``/payouts/admin``         – admin batches + marks paid/failed + CSV.
"""

from __future__ import annotations

import csv
import io
from datetime import date, datetime, timezone

import structlog
from fastapi import APIRouter, Depends, HTTPException, Query, Request, Response, status
from sqlalchemy import func, select, update
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.database import get_db
from app.middleware.auth_middleware import (
    get_current_active_user, require_role,
)
from app.models.payout import (
    BankAccountType, DisburseStatus, HostBankAccount, Payout, PayoutStatus,
)
from app.models.user import User, UserRole
from app.schemas.payout import (
    BankAccountCreate, BankAccountOut, BankAccountUpdate,
    HostPayoutSummary, PayoutCreateBatch, PayoutItemOut, PayoutMarkFailed,
    PayoutMarkPaid, PayoutOut,
)
from app.models.payout import PayoutItem
from app.services import payout_service
from app.services.audit_service import log_action
from app.services.disburse import (
    DisburseChannel, DisburseRequest, DisburseResultStatus, get_disburse_gateway,
)
from app.services.notification_service import create_notification
from app.models.notification import NotificationType

logger = structlog.get_logger(__name__)
router = APIRouter(prefix="/payouts", tags=["Host Payouts"])

_EAGER = (
    selectinload(Payout.items).selectinload(PayoutItem.booking),
)

_admin_only = require_role(UserRole.admin)


def _serialize_payout(p: Payout) -> PayoutOut:
    items = [
        PayoutItemOut(
            id=it.id,
            booking_id=it.booking_id,
            amount=it.amount,
            booking_code=getattr(it.booking, "booking_code", None),
        )
        for it in p.items
    ]
    return PayoutOut(
        id=p.id,
        host_id=p.host_id,
        bank_account_id=p.bank_account_id,
        total_amount=p.total_amount,
        cycle_start=p.cycle_start,
        cycle_end=p.cycle_end,
        status=p.status,
        reference_number=p.reference_number,
        admin_notes=p.admin_notes,
        processed_at=p.processed_at,
        created_at=p.created_at,
        items=items,
        # Wave 26 — disbursement leg.  Falls back to ``not_started`` for
        # legacy rows that pre-date the column.
        disburse_provider=p.disburse_provider,
        disburse_ref=p.disburse_ref,
        disburse_status=p.disburse_status,
        disbursed_at=p.disbursed_at,
        disburse_receipt_url=p.disburse_receipt_url,
    )


# ══════════════════════════════════════════════════════════════
#  Host bank accounts
# ══════════════════════════════════════════════════════════════
@router.get("/bank-accounts", response_model=list[BankAccountOut])
async def list_my_bank_accounts(
    user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db),
):
    rows = (
        await db.execute(
            select(HostBankAccount)
            .where(HostBankAccount.host_id == user.id)
            .order_by(
                HostBankAccount.is_default.desc(),
                HostBankAccount.created_at.desc(),
            )
        )
    ).scalars().all()
    return [BankAccountOut.from_model(r) for r in rows]


@router.post(
    "/bank-accounts",
    response_model=BankAccountOut,
    status_code=status.HTTP_201_CREATED,
)
async def add_bank_account(
    body: BankAccountCreate,
    user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db),
):
    # If the new account is flagged default, unset any previous default.
    if body.is_default:
        await db.execute(
            update(HostBankAccount)
            .where(HostBankAccount.host_id == user.id)
            .values(is_default=False)
        )
    # First account always becomes default, regardless of the flag.
    # Use COUNT(*) instead of loading every row just to check emptiness
    # — a host with 50 retired accounts shouldn't pay 50 rows of I/O
    # for a single "is this the first?" question.
    existing_count = (
        await db.execute(
            select(func.count(HostBankAccount.id)).where(
                HostBankAccount.host_id == user.id
            )
        )
    ).scalar() or 0
    is_default = body.is_default or existing_count == 0

    row = HostBankAccount(
        host_id=user.id,
        type=body.type,
        account_name=body.account_name.strip(),
        bank_name=body.bank_name,
        iban=body.iban if body.type == BankAccountType.iban else None,
        wallet_phone=body.wallet_phone if body.type == BankAccountType.wallet else None,
        instapay_address=(
            body.instapay_address if body.type == BankAccountType.instapay else None
        ),
        is_default=is_default,
    )
    db.add(row)
    await db.flush()
    await db.refresh(row)
    return BankAccountOut.from_model(row)


@router.patch("/bank-accounts/{account_id}", response_model=BankAccountOut)
async def update_bank_account(
    account_id: int,
    body: BankAccountUpdate,
    user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db),
):
    row = await db.get(HostBankAccount, account_id)
    if row is None or row.host_id != user.id:
        raise HTTPException(status_code=404, detail="Bank account not found")

    data = body.model_dump(exclude_unset=True)
    if data.get("is_default") is True:
        await db.execute(
            update(HostBankAccount)
            .where(
                HostBankAccount.host_id == user.id,
                HostBankAccount.id != account_id,
            )
            .values(is_default=False)
        )
    for k, v in data.items():
        setattr(row, k, v)
    await db.flush()
    await db.refresh(row)
    return BankAccountOut.from_model(row)


@router.delete(
    "/bank-accounts/{account_id}",
    status_code=status.HTTP_204_NO_CONTENT,
)
async def delete_bank_account(
    account_id: int,
    user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db),
):
    row = await db.get(HostBankAccount, account_id)
    if row is None or row.host_id != user.id:
        raise HTTPException(status_code=404, detail="Bank account not found")
    # Guard: refuse the delete if any non-terminal payout still points
    # at this account.  Removing it now would orphan the payout (FK is
    # ``ON DELETE SET NULL``) and the admin would discover the missing
    # destination only when trying to disburse — too late.
    pending_payouts = (
        await db.execute(
            select(func.count(Payout.id)).where(
                Payout.bank_account_id == account_id,
                Payout.status.in_(
                    [PayoutStatus.pending, PayoutStatus.processing]
                ),
            )
        )
    ).scalar() or 0
    if pending_payouts > 0:
        raise HTTPException(
            status_code=409,
            detail=(
                f"Cannot delete: linked to {pending_payouts} "
                "pending/processing payout(s). Mark them paid or failed first."
            ),
        )
    await db.delete(row)
    await db.flush()


# ══════════════════════════════════════════════════════════════
#  Host-facing payouts
# ══════════════════════════════════════════════════════════════
@router.get("/me/summary", response_model=HostPayoutSummary)
async def my_payout_summary(
    user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db),
):
    data = await payout_service.host_summary(db, user.id)
    return HostPayoutSummary(**data)


@router.get("/me", response_model=list[PayoutOut])
async def my_payouts(
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
    user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db),
):
    rows = (
        await db.execute(
            select(Payout)
            .where(Payout.host_id == user.id)
            .options(*_EAGER)
            .order_by(Payout.created_at.desc())
            .offset(offset).limit(limit)
        )
    ).scalars().unique().all()
    return [_serialize_payout(p) for p in rows]


# ══════════════════════════════════════════════════════════════
#  Admin
# ══════════════════════════════════════════════════════════════
@router.get("/admin", response_model=list[PayoutOut])
async def admin_list(
    status_filter: PayoutStatus | None = Query(default=None, alias="status"),
    host_id: int | None = None,
    limit: int = Query(100, ge=1, le=500),
    offset: int = Query(0, ge=0),
    _: User = Depends(_admin_only),
    db: AsyncSession = Depends(get_db),
):
    stmt = select(Payout).options(*_EAGER)
    if status_filter is not None:
        stmt = stmt.where(Payout.status == status_filter)
    if host_id is not None:
        stmt = stmt.where(Payout.host_id == host_id)
    stmt = stmt.order_by(Payout.created_at.desc()).offset(offset).limit(limit)

    rows = (await db.execute(stmt)).scalars().unique().all()
    return [_serialize_payout(p) for p in rows]


@router.get("/admin/{payout_id}", response_model=PayoutOut)
async def admin_get(
    payout_id: int,
    _: User = Depends(_admin_only),
    db: AsyncSession = Depends(get_db),
):
    row = (
        await db.execute(
            select(Payout).where(Payout.id == payout_id).options(*_EAGER)
        )
    ).scalar_one_or_none()
    if row is None:
        raise HTTPException(status_code=404, detail="Payout not found")
    return _serialize_payout(row)


@router.post(
    "/admin/batch",
    response_model=list[PayoutOut],
    status_code=status.HTTP_201_CREATED,
)
async def admin_create_batch(
    body: PayoutCreateBatch,
    request: Request,
    admin: User = Depends(_admin_only),
    db: AsyncSession = Depends(get_db),
):
    """Create a payout batch for the given date window.

    One Payout row is returned per host with at least one eligible
    booking.  The matched bookings are flipped to ``queued`` – they
    won't be picked up by a subsequent batch until the current one
    either ``paid`` (→ ``paid``) or ``failed`` (→ back to ``unpaid``).
    """
    payouts = await payout_service.build_batch(
        db,
        cycle_start=body.cycle_start,
        cycle_end=body.cycle_end,
        host_id=body.host_id,
        admin_id=admin.id,
    )
    if payouts:
        await log_action(
            db, request=request, actor=admin,
            action="payout.batch_create",
            target_type="payout_batch",
            after={
                "cycle_start": body.cycle_start.isoformat(),
                "cycle_end": body.cycle_end.isoformat(),
                "payout_count": len(payouts),
                "total_amount": sum(p.total_amount for p in payouts),
                "payout_ids": [p.id for p in payouts],
            },
        )
    return [_serialize_payout(p) for p in payouts]


@router.post("/admin/{payout_id}/mark-paid", response_model=PayoutOut)
async def admin_mark_paid(
    payout_id: int,
    body: PayoutMarkPaid,
    request: Request,
    admin: User = Depends(_admin_only),
    db: AsyncSession = Depends(get_db),
):
    row = (
        await db.execute(
            select(Payout).where(Payout.id == payout_id).options(*_EAGER)
        )
    ).scalar_one_or_none()
    if row is None:
        raise HTTPException(status_code=404, detail="Payout not found")
    if row.status == PayoutStatus.paid:
        raise HTTPException(status_code=400, detail="Payout already marked paid")
    await payout_service.mark_paid(
        db, row,
        reference_number=body.reference_number,
        admin_id=admin.id,
        admin_notes=body.admin_notes,
    )
    await log_action(
        db, request=request, actor=admin,
        action="payout.mark_paid",
        target_type="payout", target_id=payout_id,
        after={
            "reference_number": body.reference_number,
            "total_amount": row.total_amount,
            "booking_count": len(row.items),
        },
    )
    await db.flush()
    await db.refresh(row)
    return _serialize_payout(row)


@router.post("/admin/{payout_id}/mark-failed", response_model=PayoutOut)
async def admin_mark_failed(
    payout_id: int,
    body: PayoutMarkFailed,
    request: Request,
    admin: User = Depends(_admin_only),
    db: AsyncSession = Depends(get_db),
):
    row = (
        await db.execute(
            select(Payout).where(Payout.id == payout_id).options(*_EAGER)
        )
    ).scalar_one_or_none()
    if row is None:
        raise HTTPException(status_code=404, detail="Payout not found")
    if row.status == PayoutStatus.paid:
        raise HTTPException(
            status_code=400,
            detail="Cannot mark a paid payout as failed – issue a refund instead",
        )
    await payout_service.mark_failed(
        db, row, admin_id=admin.id, admin_notes=body.admin_notes,
    )
    await log_action(
        db, request=request, actor=admin,
        action="payout.mark_failed",
        target_type="payout", target_id=payout_id,
        after={
            "reason": body.admin_notes,
            "total_amount": row.total_amount,
            "booking_count": len(row.items),
        },
    )
    await db.flush()
    await db.refresh(row)
    return _serialize_payout(row)


@router.get("/admin/{payout_id}/csv")
async def admin_export_csv(
    payout_id: int,
    _: User = Depends(_admin_only),
    db: AsyncSession = Depends(get_db),
):
    """Download the accounting CSV for one payout.

    Columns are chosen to match what Egyptian banks / wallet gateways
    accept when uploading a batch transfer file.
    """
    row = (
        await db.execute(
            select(Payout).where(Payout.id == payout_id).options(*_EAGER)
        )
    ).scalar_one_or_none()
    if row is None:
        raise HTTPException(status_code=404, detail="Payout not found")

    # Preload host + bank_account via existing relationships.
    host = row.host
    bank = row.bank_account

    buf = io.StringIO()
    writer = csv.writer(buf)
    writer.writerow([
        "payout_id", "host_id", "host_name", "account_type",
        "account_name", "bank_name", "iban", "wallet_phone",
        "instapay_address", "total_amount_egp", "cycle_start", "cycle_end",
        "booking_count",
    ])
    writer.writerow([
        row.id,
        row.host_id,
        getattr(host, "name", ""),
        bank.type.value if bank else "",
        bank.account_name if bank else "",
        bank.bank_name or "" if bank else "",
        bank.iban or "" if bank else "",
        bank.wallet_phone or "" if bank else "",
        bank.instapay_address or "" if bank else "",
        f"{row.total_amount:.2f}",
        row.cycle_start.isoformat(),
        row.cycle_end.isoformat(),
        len(row.items),
    ])
    writer.writerow([])   # blank separator
    writer.writerow(["booking_id", "booking_code", "amount_egp"])
    for it in row.items:
        writer.writerow([
            it.booking_id,
            getattr(it.booking, "booking_code", ""),
            f"{it.amount:.2f}",
        ])

    return Response(
        content=buf.getvalue(),
        media_type="text/csv",
        headers={
            "Content-Disposition": f'attachment; filename="payout-{row.id}.csv"',
        },
    )


# ══════════════════════════════════════════════════════════════
#  Wave 26 — automated disbursement (Kashier / mock)
# ══════════════════════════════════════════════════════════════
def _channel_for(account: HostBankAccount) -> DisburseChannel:
    """Map a bank account row to the gateway's channel enum."""
    if account.type == BankAccountType.iban:
        return DisburseChannel.iban
    if account.type == BankAccountType.wallet:
        return DisburseChannel.wallet
    return DisburseChannel.instapay


@router.post("/admin/{payout_id}/disburse", response_model=PayoutOut)
async def admin_disburse(
    payout_id: int,
    request: Request,
    admin: User = Depends(_admin_only),
    db: AsyncSession = Depends(get_db),
):
    """Fire the configured disbursement gateway for one payout.

    Idempotent: a payout already in ``initiated`` / ``processing`` /
    ``succeeded`` is rejected so the admin can't double-pay by
    refreshing the dashboard.  Failed disbursements *can* be retried
    — admins flip back to ``not_started`` via :func:`admin_mark_failed`
    or by editing the row directly in the support tool.
    """
    # Lock the row so a double-click / two simultaneous admin tabs
    # can't both pass the ``not_started`` check and call Kashier
    # twice.  Kashier itself dedupes on ``merchantOrderId`` but we
    # don't want to rely solely on that — a real money path needs
    # belt-and-braces serialisation on our side too.
    row = (
        await db.execute(
            select(Payout)
            .where(Payout.id == payout_id)
            .with_for_update()
            .options(*_EAGER, selectinload(Payout.bank_account))
        )
    ).scalar_one_or_none()
    if row is None:
        raise HTTPException(status_code=404, detail="Payout not found")

    if row.disburse_status in (
        DisburseStatus.initiated,
        DisburseStatus.processing,
        DisburseStatus.succeeded,
    ):
        raise HTTPException(
            status_code=400,
            detail=(
                f"Disburse already in state '{row.disburse_status.value}'. "
                "Wait for the webhook or mark the payout failed first."
            ),
        )
    if row.bank_account is None:
        raise HTTPException(
            status_code=400,
            detail="Payout has no bank account on file — host must add one.",
        )

    gateway = get_disburse_gateway()
    req = DisburseRequest(
        payout_id=row.id,
        amount_egp=row.total_amount,
        channel=_channel_for(row.bank_account),
        account_name=row.bank_account.account_name,
        iban=row.bank_account.iban,
        wallet_phone=row.bank_account.wallet_phone,
        instapay_address=row.bank_account.instapay_address,
        note=f"Talaa payout #{row.id}",
    )
    result = await gateway.initiate(req)

    # Map the gateway-layer status onto our DB enum.  ``succeeded`` is
    # rare on the sync path (mock can return it; Kashier almost never
    # does) but we honour it so the receipt UI can light up
    # immediately when it happens.
    if result.status == DisburseResultStatus.failed:
        new_status = DisburseStatus.failed
    elif result.status == DisburseResultStatus.succeeded:
        new_status = DisburseStatus.succeeded
    else:
        new_status = DisburseStatus.initiated

    row.disburse_provider = gateway.name
    row.disburse_ref = result.provider_ref
    row.disburse_status = new_status
    # Stamp the moment we hit the gateway so the reconciliation
    # scheduler can age this row off ``DISBURSE_SLA_HOURS`` accurately
    # rather than relying on ``created_at`` (which is the *batch*
    # timestamp, often days earlier).
    row.disburse_initiated_at = datetime.now(timezone.utc)
    # Snapshot the gateway response — invaluable when reconciling a
    # missing webhook six months later.
    row.disburse_payload = {
        "request": {
            "channel": req.channel.value,
            "amount_egp": req.amount_egp,
            "note": req.note,
        },
        "response": result.raw,
    }
    await db.flush()

    await log_action(
        db, request=request, actor=admin,
        action="payout.disburse_initiated",
        target_type="payout", target_id=payout_id,
        after={
            "provider": gateway.name,
            "provider_ref": result.provider_ref,
            "amount": row.total_amount,
            "status": new_status.value,
            "message": result.provider_message,
        },
    )

    if new_status == DisburseStatus.failed:
        # Loud failure — admin needs to know to fall back to manual.
        raise HTTPException(
            status_code=502,
            detail=result.provider_message or "Disbursement gateway rejected the request",
        )

    await db.refresh(row)
    return _serialize_payout(row)


@router.post("/disburse/webhook", status_code=status.HTTP_200_OK)
async def disburse_webhook(
    request: Request,
    db: AsyncSession = Depends(get_db),
):
    """Inbound notification from the disbursement gateway.

    Public endpoint — authenticated by HMAC signature inside the
    gateway's :meth:`parse_webhook` (we never trust the network).
    On a verified success/failure we flip ``disburse_status`` and,
    on success, automatically mark the payout ``paid`` so the host
    sees the green check immediately.
    """
    body = await request.body()
    headers = {k: v for k, v in request.headers.items()}
    gateway = get_disburse_gateway()
    parsed = await gateway.parse_webhook(headers, body)
    if parsed is None:
        # Bad signature, malformed payload, or unknown order id —
        # respond 401 so the gateway will retry (most retry on 5xx
        # but very few on 401, which is what we want for *bad*
        # signatures).  Use 400 for malformed payloads.
        raise HTTPException(status_code=401, detail="Invalid webhook")

    # Lock the payout row.  Gateways routinely fire the same webhook
    # twice (once on success, once on a retry from their queue) and
    # without a row lock both copies sail past the ``already_terminal``
    # check, double-running ``mark_paid`` and double-sending the
    # "تم تحويل أرباحك" notification.  ``with_for_update`` serialises
    # the two requests so only the first one observes ``processing``
    # and the second hits the terminal-state branch below.
    row = (
        await db.execute(
            select(Payout)
            .where(Payout.id == parsed.payout_id)
            .with_for_update()
            .options(*_EAGER)
        )
    ).scalar_one_or_none()
    if row is None:
        # Webhook arrived for a payout we don't know — log and 200
        # so the gateway stops retrying.
        logger.warning("disburse_webhook_unknown_payout", payout_id=parsed.payout_id)
        return {"ok": True, "ignored": "unknown_payout"}

    # Idempotency: webhooks can fire twice (once on success, once on
    # a retry from the gateway's side).  Bail if we've already
    # processed a terminal state for this provider_ref.
    if row.disburse_status in (DisburseStatus.succeeded, DisburseStatus.failed):
        return {"ok": True, "ignored": "already_terminal"}

    # Cross-check the provider_ref.  A mismatch usually means a
    # replay from a different payout — refuse loudly.
    if row.disburse_ref and parsed.provider_ref and row.disburse_ref != parsed.provider_ref:
        logger.warning(
            "disburse_webhook_ref_mismatch",
            payout_id=row.id,
            stored_ref=row.disburse_ref,
            webhook_ref=parsed.provider_ref,
        )
        raise HTTPException(status_code=400, detail="provider_ref mismatch")

    if parsed.succeeded:
        # Cross-check the gateway-claimed amount against our own
        # records before flipping anything.  A mismatch here means
        # either a buggy webhook or a forged one (HMAC pass with
        # wrong values).  Either way, *do not* mark the payout paid
        # — we'd notify the host that ``total_amount`` arrived when
        # in reality the gateway moved a different sum.  Tolerance
        # is 1 piastre (0.01 EGP) to absorb the rounding inherent
        # in EGP→piastre→EGP round-trips.
        if (
            parsed.amount_egp is not None
            and abs(parsed.amount_egp - row.total_amount) > 0.01
        ):
            logger.error(
                "disburse_webhook_amount_mismatch",
                payout_id=row.id,
                provider_ref=parsed.provider_ref,
                claimed_amount=parsed.amount_egp,
                expected_amount=row.total_amount,
            )
            row.disburse_status = DisburseStatus.failed
            row.admin_notes = (
                f"Webhook amount mismatch: gateway said "
                f"{parsed.amount_egp:.2f}, expected {row.total_amount:.2f}"
            )
            # Append the suspicious payload so support can inspect it.
            payload_log = dict(row.disburse_payload or {})
            mismatched = list(payload_log.get("mismatched_webhooks", []))
            mismatched.append(parsed.raw)
            payload_log["mismatched_webhooks"] = mismatched[-20:]
            row.disburse_payload = payload_log
            await db.flush()
            return {"ok": True, "ignored": "amount_mismatch"}

        row.disburse_status = DisburseStatus.succeeded
        row.disbursed_at = datetime.now(timezone.utc)
        # Promote the bookkeeping side too — the host shouldn't have
        # to wait for a separate admin click once the gateway has
        # confirmed delivery.  Reuse the gateway's own ref as the
        # ``reference_number`` so the host sees one consistent id.
        if row.status != PayoutStatus.paid:
            await payout_service.mark_paid(
                db, row,
                reference_number=row.disburse_ref or "auto-disbursed",
                admin_id=None,  # system-driven; audit_service handles None
                admin_notes=parsed.message,
            )
        # Notify the host so they don't have to refresh the app.
        try:
            await create_notification(
                db, row.host_id,
                title="تم تحويل أرباحك ✅",
                body=(
                    f"تم تحويل {row.total_amount:.2f} ج.م لحسابك. "
                    f"رقم العملية: {row.disburse_ref or '—'}"
                ),
                notif_type=NotificationType.booking_confirmed,
                data={"payout_id": str(row.id)},
            )
        except Exception:  # pragma: no cover — notifications are best-effort
            pass
    elif parsed.failed:
        row.disburse_status = DisburseStatus.failed
    else:
        # Intermediate status (e.g. PROCESSING after a queue update).
        row.disburse_status = DisburseStatus.processing

    # Append-only payload log so support can scroll through state
    # transitions without joining the audit_log table.  Capped at
    # the most recent 20 entries so a misbehaving gateway can't
    # blow up the JSONB row size (TOAST blow-up = slow reads).
    payload_log = dict(row.disburse_payload or {})
    webhooks = list(payload_log.get("webhooks", []))
    webhooks.append(parsed.raw)
    payload_log["webhooks"] = webhooks[-20:]
    row.disburse_payload = payload_log

    await db.flush()
    return {"ok": True}


@router.get("/admin/eligible/preview")
async def admin_eligible_preview(
    cycle_start: date,
    cycle_end: date,
    host_id: int | None = None,
    _: User = Depends(_admin_only),
    db: AsyncSession = Depends(get_db),
):
    """Dry-run: how many bookings / EGP would be included in a batch
    without creating one.

    Aggregation runs in Postgres via ``GROUP BY`` rather than pulling
    every booking row into Python — a preview window with 500 hosts
    × 30 bookings each used to download ~15K rows just to compute
    two sums.  Now it's one indexed scan returning at most one row
    per host.
    """
    rows = await payout_service.eligible_bookings_summary(
        db, host_id=host_id, cycle_start=cycle_start, cycle_end=cycle_end,
    )
    return {
        "total_bookings": sum(r["booking_count"] for r in rows),
        "total_amount": round(sum(r["total_amount"] for r in rows), 2),
        "hosts": rows,
    }
