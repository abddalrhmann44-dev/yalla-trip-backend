"""Admin-only audit-log browsing endpoints."""

from __future__ import annotations

from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.middleware.auth_middleware import require_role
from app.models.audit_log import AuditLogEntry
from app.models.user import User, UserRole
from app.schemas.audit_log import AuditLogOut

router = APIRouter(prefix="/admin/audit", tags=["Admin Audit Log"])
_admin_only = require_role(UserRole.admin)


@router.get("", response_model=list[AuditLogOut])
async def list_entries(
    action: str | None = Query(
        default=None,
        description="Exact action key, e.g. 'user.suspend'.",
    ),
    action_prefix: str | None = Query(
        default=None,
        description="Match actions starting with this string, e.g. 'payout.'.",
    ),
    actor_id: int | None = None,
    target_type: str | None = None,
    target_id: int | None = None,
    since: datetime | None = None,
    until: datetime | None = None,
    limit: int = Query(100, ge=1, le=500),
    offset: int = Query(0, ge=0),
    _: User = Depends(_admin_only),
    db: AsyncSession = Depends(get_db),
):
    stmt = select(AuditLogEntry)
    if action:
        stmt = stmt.where(AuditLogEntry.action == action)
    if action_prefix:
        stmt = stmt.where(AuditLogEntry.action.like(f"{action_prefix}%"))
    if actor_id is not None:
        stmt = stmt.where(AuditLogEntry.actor_id == actor_id)
    if target_type:
        stmt = stmt.where(AuditLogEntry.target_type == target_type)
    if target_id is not None:
        stmt = stmt.where(AuditLogEntry.target_id == target_id)
    if since is not None:
        stmt = stmt.where(AuditLogEntry.created_at >= since)
    if until is not None:
        stmt = stmt.where(AuditLogEntry.created_at <= until)

    stmt = (
        stmt.order_by(AuditLogEntry.created_at.desc())
        .offset(offset)
        .limit(limit)
    )
    rows = (await db.execute(stmt)).scalars().all()
    return [AuditLogOut.model_validate(r) for r in rows]


@router.get("/{entry_id}", response_model=AuditLogOut)
async def get_entry(
    entry_id: int,
    _: User = Depends(_admin_only),
    db: AsyncSession = Depends(get_db),
):
    row = await db.get(AuditLogEntry, entry_id)
    if row is None:
        raise HTTPException(status_code=404, detail="Audit entry not found")
    return AuditLogOut.model_validate(row)


@router.get("/stats/overview")
async def stats_overview(
    _: User = Depends(_admin_only),
    db: AsyncSession = Depends(get_db),
):
    """Aggregate counts per action – useful for the admin dashboard."""
    total = (
        await db.execute(select(func.count(AuditLogEntry.id)))
    ).scalar() or 0

    # Top 10 most-frequent actions (lifetime).
    by_action = (
        await db.execute(
            select(
                AuditLogEntry.action,
                func.count(AuditLogEntry.id).label("n"),
            )
            .group_by(AuditLogEntry.action)
            .order_by(func.count(AuditLogEntry.id).desc())
            .limit(10)
        )
    ).all()

    # Top 5 most-active actors.
    by_actor = (
        await db.execute(
            select(
                AuditLogEntry.actor_email,
                func.count(AuditLogEntry.id).label("n"),
            )
            .group_by(AuditLogEntry.actor_email)
            .order_by(func.count(AuditLogEntry.id).desc())
            .limit(5)
        )
    ).all()

    return {
        "total_entries": int(total),
        "top_actions": [
            {"action": a, "count": int(n)} for a, n in by_action
        ],
        "top_actors": [
            {"actor": e, "count": int(n)} for e, n in by_actor
        ],
    }
