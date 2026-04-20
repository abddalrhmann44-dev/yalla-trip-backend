"""Host payout endpoints.

* ``/payouts/bank-accounts`` – host manages their accounts.
* ``/payouts/me``            – host sees their payout history.
* ``/payouts/admin``         – admin batches + marks paid/failed + CSV.
"""

from __future__ import annotations

import csv
import io
from datetime import date

import structlog
from fastapi import APIRouter, Depends, HTTPException, Query, Request, Response, status
from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.database import get_db
from app.middleware.auth_middleware import (
    get_current_active_user, require_role,
)
from app.models.payout import (
    BankAccountType, HostBankAccount, Payout, PayoutStatus,
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
    existing_count = (
        await db.execute(
            select(HostBankAccount).where(HostBankAccount.host_id == user.id)
        )
    ).scalars().all()
    is_default = body.is_default or not existing_count

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
    # Guard: can't delete the default when others exist and this is
    # the only one linked to a pending payout.
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


@router.get("/admin/eligible/preview")
async def admin_eligible_preview(
    cycle_start: date,
    cycle_end: date,
    host_id: int | None = None,
    _: User = Depends(_admin_only),
    db: AsyncSession = Depends(get_db),
):
    """Dry-run: how many bookings / EGP would be included in a batch
    without creating one."""
    stmt = await payout_service.eligible_bookings_query(
        db, host_id=host_id, cycle_start=cycle_start, cycle_end=cycle_end,
    )
    rows = (await db.execute(stmt)).scalars().all()
    by_host: dict[int, dict] = {}
    for b in rows:
        bucket = by_host.setdefault(b.owner_id, {
            "host_id": b.owner_id,
            "booking_count": 0,
            "total_amount": 0.0,
        })
        bucket["booking_count"] += 1
        bucket["total_amount"] += b.owner_payout
    return {
        "total_bookings": len(rows),
        "total_amount": round(sum(b.owner_payout for b in rows), 2),
        "hosts": [
            {**v, "total_amount": round(v["total_amount"], 2)}
            for v in by_host.values()
        ],
    }
