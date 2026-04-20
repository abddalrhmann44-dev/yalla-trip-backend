"""Promo-code endpoints.

* ``POST /promo-codes/validate`` – any logged-in user previews a code
  against a quoted booking amount.

* ``/promo-codes/admin/*`` – admin CRUD + usage stats.
"""

from __future__ import annotations

import structlog
from fastapi import APIRouter, Depends, HTTPException, Query, Request, status
from sqlalchemy import func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.middleware.auth_middleware import (
    get_current_active_user, require_role,
)
from app.models.promo_code import PromoCode, PromoRedemption
from app.models.user import User, UserRole
from app.schemas.promo_code import (
    PromoCodeCreate, PromoCodeOut, PromoCodeUpdate,
    PromoRedemptionOut, PromoValidateRequest, PromoValidateResponse,
)
from app.services.audit_service import log_action
from app.services.promo_service import validate_code

logger = structlog.get_logger(__name__)
router = APIRouter(prefix="/promo-codes", tags=["Promo codes"])

_admin_only = require_role(UserRole.admin)


# ══════════════════════════════════════════════════════════════
#  User-facing
# ══════════════════════════════════════════════════════════════
@router.post("/validate", response_model=PromoValidateResponse)
async def validate_promo(
    body: PromoValidateRequest,
    user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db),
):
    """Preview a promo code before creating a booking."""
    res = await validate_code(db, body.code, body.booking_amount, user.id)
    return PromoValidateResponse(
        valid=res.valid,
        code=res.code,
        discount_amount=res.discount_amount,
        final_amount=res.final_amount,
        reason=res.reason,
        reason_ar=res.reason_ar,
    )


# ══════════════════════════════════════════════════════════════
#  Admin
# ══════════════════════════════════════════════════════════════
@router.post(
    "/admin",
    response_model=PromoCodeOut,
    status_code=status.HTTP_201_CREATED,
)
async def admin_create(
    body: PromoCodeCreate,
    request: Request,
    admin: User = Depends(_admin_only),
    db: AsyncSession = Depends(get_db),
):
    if body.valid_from and body.valid_until and body.valid_until <= body.valid_from:
        raise HTTPException(
            status_code=400, detail="valid_until must be after valid_from"
        )

    promo = PromoCode(
        code=body.code,
        description=body.description,
        type=body.type,
        value=body.value,
        max_discount=body.max_discount,
        min_booking_amount=body.min_booking_amount,
        max_uses=body.max_uses,
        max_uses_per_user=body.max_uses_per_user,
        valid_from=body.valid_from,
        valid_until=body.valid_until,
        is_active=body.is_active,
        created_by_id=admin.id,
    )
    db.add(promo)
    try:
        await db.flush()
    except IntegrityError:
        await db.rollback()
        raise HTTPException(
            status_code=409, detail=f"Code '{body.code}' already exists"
        )
    await db.refresh(promo)
    await log_action(
        db, request=request, actor=admin,
        action="promo.create",
        target_type="promo_code", target_id=promo.id,
        after={
            "code": promo.code,
            "type": promo.type.value,
            "value": promo.value,
            "max_uses": promo.max_uses,
        },
    )
    logger.info("promo_created", code=promo.code, admin=admin.id)
    return PromoCodeOut.model_validate(promo)


@router.get("/admin", response_model=list[PromoCodeOut])
async def admin_list(
    is_active: bool | None = None,
    search: str | None = None,
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
    _: User = Depends(_admin_only),
    db: AsyncSession = Depends(get_db),
):
    stmt = select(PromoCode)
    if is_active is not None:
        stmt = stmt.where(PromoCode.is_active.is_(is_active))
    if search:
        stmt = stmt.where(PromoCode.code.ilike(f"%{search.upper()}%"))
    stmt = stmt.order_by(PromoCode.created_at.desc()).offset(offset).limit(limit)

    rows = (await db.execute(stmt)).scalars().all()
    return [PromoCodeOut.model_validate(r) for r in rows]


@router.get("/admin/{promo_id}", response_model=PromoCodeOut)
async def admin_get(
    promo_id: int,
    _: User = Depends(_admin_only),
    db: AsyncSession = Depends(get_db),
):
    promo = await db.get(PromoCode, promo_id)
    if promo is None:
        raise HTTPException(status_code=404, detail="Promo code not found")
    return PromoCodeOut.model_validate(promo)


@router.patch("/admin/{promo_id}", response_model=PromoCodeOut)
async def admin_update(
    promo_id: int,
    body: PromoCodeUpdate,
    _: User = Depends(_admin_only),
    db: AsyncSession = Depends(get_db),
):
    promo = await db.get(PromoCode, promo_id)
    if promo is None:
        raise HTTPException(status_code=404, detail="Promo code not found")
    data = body.model_dump(exclude_unset=True)
    for k, v in data.items():
        setattr(promo, k, v)
    await db.flush()
    await db.refresh(promo)
    logger.info("promo_updated", code=promo.code, changes=list(data.keys()))
    return PromoCodeOut.model_validate(promo)


@router.delete(
    "/admin/{promo_id}",
    status_code=status.HTTP_204_NO_CONTENT,
)
async def admin_delete(
    promo_id: int,
    request: Request,
    admin: User = Depends(_admin_only),
    db: AsyncSession = Depends(get_db),
):
    """Hard-delete a promo code.

    Cascades to its ``promo_redemptions`` rows (ON DELETE CASCADE) so
    historical bookings keep their ``promo_discount`` value but lose
    the pointer to the source code.  Prefer ``PATCH {is_active:false}``
    if you want to preserve the audit trail.
    """
    promo = await db.get(PromoCode, promo_id)
    if promo is None:
        raise HTTPException(status_code=404, detail="Promo code not found")
    snapshot = {
        "code": promo.code,
        "type": promo.type.value,
        "value": promo.value,
        "uses_count": promo.uses_count,
    }
    await db.delete(promo)
    await db.flush()
    await log_action(
        db, request=request, actor=admin,
        action="promo.delete",
        target_type="promo_code", target_id=promo_id,
        before=snapshot,
    )
    logger.info("promo_deleted", promo_id=promo_id)


@router.get(
    "/admin/{promo_id}/redemptions",
    response_model=list[PromoRedemptionOut],
)
async def admin_redemptions(
    promo_id: int,
    limit: int = Query(100, ge=1, le=500),
    offset: int = Query(0, ge=0),
    _: User = Depends(_admin_only),
    db: AsyncSession = Depends(get_db),
):
    """Per-code usage log – each redemption points to its booking."""
    if await db.get(PromoCode, promo_id) is None:
        raise HTTPException(status_code=404, detail="Promo code not found")
    rows = (
        await db.execute(
            select(PromoRedemption)
            .where(PromoRedemption.promo_id == promo_id)
            .order_by(PromoRedemption.created_at.desc())
            .offset(offset)
            .limit(limit)
        )
    ).scalars().all()
    return [PromoRedemptionOut.model_validate(r) for r in rows]


@router.get("/admin/stats/overview")
async def admin_stats_overview(
    _: User = Depends(_admin_only),
    db: AsyncSession = Depends(get_db),
):
    """Platform-wide promo stats for the admin dashboard."""
    total_codes = (
        await db.execute(select(func.count(PromoCode.id)))
    ).scalar() or 0
    active_codes = (
        await db.execute(
            select(func.count(PromoCode.id)).where(PromoCode.is_active.is_(True))
        )
    ).scalar() or 0
    total_redemptions = (
        await db.execute(select(func.count(PromoRedemption.id)))
    ).scalar() or 0
    total_discount = (
        await db.execute(
            select(func.coalesce(func.sum(PromoRedemption.discount_amount), 0))
        )
    ).scalar() or 0
    return {
        "total_codes": int(total_codes),
        "active_codes": int(active_codes),
        "total_redemptions": int(total_redemptions),
        "total_discount_given": float(total_discount),
        "currency": "EGP",
    }
