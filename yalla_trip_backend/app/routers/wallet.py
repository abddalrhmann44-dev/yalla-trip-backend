"""Wallet + referral endpoints.

* ``GET  /wallet/me``                – balance + recent ledger + ref code
* ``POST /wallet/me/redeem/preview`` – max-redeemable helper for a subtotal
* ``GET  /wallet/referrals/me``      – referrals summary
* ``POST /wallet/admin/{user_id}/adjust`` – manual +/- correction (admin)
"""

from __future__ import annotations

import structlog
from fastapi import APIRouter, Depends, HTTPException, Query, Request
from pydantic import BaseModel, Field
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import get_settings
from app.database import get_db
from app.middleware.auth_middleware import (
    get_current_active_user, require_role,
)
from app.models.user import User, UserRole
from app.models.wallet import (
    Referral, ReferralStatus, Wallet, WalletTransaction, WalletTxnType,
)
from app.schemas.wallet import (
    ReferralOut, ReferralSummary, WalletAdjustRequest, WalletRedeemPreview,
    WalletSummary, WalletTxnOut,
)
from app.services import wallet_service
from app.services.audit_service import log_action

logger = structlog.get_logger(__name__)
router = APIRouter(prefix="/wallet", tags=["Wallet"])

_admin_only = require_role(UserRole.admin)


# ══════════════════════════════════════════════════════════════
#  User – balance + ledger
# ══════════════════════════════════════════════════════════════
@router.get("/me", response_model=WalletSummary)
async def my_wallet(
    me: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db),
):
    wallet = await wallet_service.get_or_create_wallet(db, me.id)
    code = await wallet_service.ensure_referral_code(db, me)

    recent = (
        await db.execute(
            select(WalletTransaction)
            .where(WalletTransaction.wallet_id == wallet.id)
            .order_by(WalletTransaction.created_at.desc())
            .limit(30)
        )
    ).scalars().all()

    return WalletSummary(
        balance=round(wallet.balance, 2),
        lifetime_earned=round(wallet.lifetime_earned, 2),
        lifetime_spent=round(wallet.lifetime_spent, 2),
        referral_code=code,
        recent_transactions=[WalletTxnOut.model_validate(r) for r in recent],
    )


@router.post("/me/redeem/preview", response_model=WalletRedeemPreview)
async def redeem_preview(
    subtotal: float = Query(gt=0, description="Booking subtotal in EGP"),
    me: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db),
):
    wallet = await wallet_service.get_or_create_wallet(db, me.id)
    cap = wallet_service.max_redeemable(subtotal)
    max_applicable = min(wallet.balance, cap)
    settings = get_settings()
    reason = None
    if wallet.balance >= cap and cap < wallet.balance:
        reason = (
            f"الحد الأقصى {settings.WALLET_MAX_REDEEM_PERCENT:.0f}% "
            f"من قيمة الحجز"
        )
    return WalletRedeemPreview(
        available_balance=round(wallet.balance, 2),
        max_redeemable=round(max_applicable, 2),
        cap_reason=reason,
    )


# ══════════════════════════════════════════════════════════════
#  User – top-up (card payment)
# ══════════════════════════════════════════════════════════════
class WalletTopupRequest(BaseModel):
    """Amount the user wishes to load into their wallet (EGP)."""
    amount: float = Field(..., gt=0, le=50000)
    # Optional opaque reference returned by the payment gateway; kept
    # for audit trails and future reconciliation webhooks.  Not
    # validated here – the gateway integration layer is responsible.
    gateway_reference: str | None = Field(default=None, max_length=128)


@router.post("/me/topup", response_model=WalletSummary)
async def topup_wallet(
    body: WalletTopupRequest,
    me: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db),
):
    """Credit the user's wallet.

    Intended to be called after the Flutter client has completed a
    card payment via the existing payment gateway.  For the MVP this
    endpoint trusts the caller and immediately credits the balance;
    in production the same effect should be produced by a gateway
    webhook to prevent spoofing.
    """
    amount = round(float(body.amount), 2)
    await wallet_service.credit(
        db, me.id, amount,
        txn_type=WalletTxnType.topup,
        description=(
            f"شحن محفظة عبر البطاقة / Card top-up"
            + (f" (ref {body.gateway_reference})" if body.gateway_reference else "")
        ),
    )
    wallet = await wallet_service.get_or_create_wallet(db, me.id)
    code = await wallet_service.ensure_referral_code(db, me)

    recent = (
        await db.execute(
            select(WalletTransaction)
            .where(WalletTransaction.wallet_id == wallet.id)
            .order_by(WalletTransaction.created_at.desc())
            .limit(30)
        )
    ).scalars().all()
    return WalletSummary(
        balance=round(wallet.balance, 2),
        lifetime_earned=round(wallet.lifetime_earned, 2),
        lifetime_spent=round(wallet.lifetime_spent, 2),
        referral_code=code,
        recent_transactions=[WalletTxnOut.model_validate(r) for r in recent],
    )


# ══════════════════════════════════════════════════════════════
#  User – referrals
# ══════════════════════════════════════════════════════════════
@router.get("/referrals/me", response_model=ReferralSummary)
async def my_referrals(
    me: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db),
):
    code = await wallet_service.ensure_referral_code(db, me)
    settings = get_settings()

    refs = (
        await db.execute(
            select(Referral)
            .where(Referral.referrer_id == me.id)
            .order_by(Referral.created_at.desc())
        )
    ).scalars().all()

    rewarded = sum(1 for r in refs if r.status == ReferralStatus.rewarded)
    pending = sum(1 for r in refs if r.status == ReferralStatus.pending)
    earned = sum(r.reward_amount or 0 for r in refs)

    out_refs = [
        ReferralOut(
            id=r.id,
            invitee_id=r.invitee_id,
            invitee_name=r.invitee.name if r.invitee else None,
            status=r.status,
            reward_amount=r.reward_amount,
            rewarded_at=r.rewarded_at,
            created_at=r.created_at,
        )
        for r in refs
    ]

    return ReferralSummary(
        referral_code=code,
        referral_link=f"{settings.PUBLIC_APP_URL.rstrip('/')}/signup?ref={code}",
        total_referrals=len(refs),
        rewarded_count=rewarded,
        pending_count=pending,
        total_earned=round(earned, 2),
        referrals=out_refs,
    )


# ══════════════════════════════════════════════════════════════
#  Admin – adjustments + inspection
# ══════════════════════════════════════════════════════════════
@router.post("/admin/{user_id}/adjust", response_model=WalletSummary)
async def admin_adjust(
    user_id: int,
    body: WalletAdjustRequest,
    request: Request,
    admin: User = Depends(_admin_only),
    db: AsyncSession = Depends(get_db),
):
    if body.amount == 0:
        raise HTTPException(
            status_code=400, detail="amount must be non-zero",
        )

    target = await db.get(User, user_id)
    if target is None:
        raise HTTPException(status_code=404, detail="User not found")

    wallet = await wallet_service.get_or_create_wallet(db, user_id)
    before_balance = wallet.balance

    try:
        if body.amount > 0:
            await wallet_service.credit(
                db, user_id, body.amount,
                txn_type=WalletTxnType.admin_adjust,
                description=body.description,
                admin_id=admin.id,
            )
        else:
            # Route negative admin corrections through the debit helper
            # so we still hit the insufficient-balance guard.
            wallet_row = await wallet_service.get_or_create_wallet(db, user_id)
            if wallet_row.balance + body.amount < -1e-6:
                raise HTTPException(
                    status_code=400,
                    detail=(
                        f"Cannot debit {-body.amount}: "
                        f"current balance is {wallet_row.balance}"
                    ),
                )
            await wallet_service._write_txn(
                db, wallet_row,
                amount=body.amount,      # already negative
                txn_type=WalletTxnType.admin_adjust,
                description=body.description,
                admin_id=admin.id,
            )
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))

    await db.refresh(wallet)

    await log_action(
        db, request=request, actor=admin,
        action="wallet.adjust",
        target_type="user", target_id=user_id,
        before={"balance": before_balance},
        after={
            "balance": wallet.balance,
            "amount": body.amount,
            "description": body.description,
        },
    )

    recent = (
        await db.execute(
            select(WalletTransaction)
            .where(WalletTransaction.wallet_id == wallet.id)
            .order_by(WalletTransaction.created_at.desc())
            .limit(30)
        )
    ).scalars().all()

    code = target.referral_code or await wallet_service.ensure_referral_code(db, target)

    return WalletSummary(
        balance=round(wallet.balance, 2),
        lifetime_earned=round(wallet.lifetime_earned, 2),
        lifetime_spent=round(wallet.lifetime_spent, 2),
        referral_code=code,
        recent_transactions=[WalletTxnOut.model_validate(r) for r in recent],
    )


@router.get("/admin/stats")
async def admin_stats(
    _: User = Depends(_admin_only),
    db: AsyncSession = Depends(get_db),
):
    """Aggregate wallet / referral health metrics."""
    total_wallets = (
        await db.execute(select(func.count(Wallet.id)))
    ).scalar() or 0
    outstanding = (
        await db.execute(select(func.coalesce(func.sum(Wallet.balance), 0)))
    ).scalar() or 0
    earned = (
        await db.execute(
            select(func.coalesce(func.sum(Wallet.lifetime_earned), 0))
        )
    ).scalar() or 0
    spent = (
        await db.execute(
            select(func.coalesce(func.sum(Wallet.lifetime_spent), 0))
        )
    ).scalar() or 0

    total_refs = (
        await db.execute(select(func.count(Referral.id)))
    ).scalar() or 0
    rewarded_refs = (
        await db.execute(
            select(func.count(Referral.id)).where(
                Referral.status == ReferralStatus.rewarded
            )
        )
    ).scalar() or 0

    return {
        "total_wallets": int(total_wallets),
        "outstanding_credit": float(outstanding),
        "lifetime_earned": float(earned),
        "lifetime_spent": float(spent),
        "total_referrals": int(total_refs),
        "rewarded_referrals": int(rewarded_refs),
    }
