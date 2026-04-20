"""Reports / dispute-resolution endpoints.

Any authenticated user can file a report against a property, another
user, a review or a booking.  Admins see a unified queue and either
``resolve`` (taking action) or ``dismiss`` (false alarm) each entry.

The target's existence is validated server-side so we don't end up
with dangling reports after a delete.
"""

from __future__ import annotations

from datetime import datetime, timezone

import structlog
from fastapi import APIRouter, Depends, HTTPException, Query, status
from pydantic import BaseModel, Field
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.middleware.auth_middleware import (
    get_current_active_user, require_role,
)
from app.models.booking import Booking
from app.models.property import Property
from app.models.report import (
    Report, ReportReason, ReportStatus, ReportTarget,
)
from app.models.review import Review
from app.models.user import User, UserRole

logger = structlog.get_logger(__name__)
router = APIRouter(prefix="/reports", tags=["Reports"])

_admin_only = require_role(UserRole.admin)


# ══════════════════════════════════════════════════════════════
#  Schemas
# ══════════════════════════════════════════════════════════════
class ReportCreate(BaseModel):
    target_type: ReportTarget
    target_id: int = Field(gt=0)
    reason: ReportReason
    details: str | None = Field(default=None, max_length=2000)


class ReportResolve(BaseModel):
    notes: str | None = Field(default=None, max_length=2000)


class ReportOut(BaseModel):
    id: int
    reporter_id: int
    target_type: ReportTarget
    target_id: int
    reason: ReportReason
    details: str | None
    status: ReportStatus
    resolution_notes: str | None
    resolved_by_id: int | None
    resolved_at: datetime | None
    created_at: datetime

    class Config:
        from_attributes = True


# ══════════════════════════════════════════════════════════════
#  Helpers
# ══════════════════════════════════════════════════════════════
_TARGET_MODEL = {
    ReportTarget.property: Property,
    ReportTarget.user: User,
    ReportTarget.review: Review,
    ReportTarget.booking: Booking,
}


async def _target_exists(
    db: AsyncSession, target_type: ReportTarget, target_id: int
) -> bool:
    model = _TARGET_MODEL[target_type]
    row = await db.execute(select(model.id).where(model.id == target_id))
    return row.scalar_one_or_none() is not None


# ══════════════════════════════════════════════════════════════
#  Public endpoints (any authenticated user)
# ══════════════════════════════════════════════════════════════
@router.post("", response_model=ReportOut, status_code=status.HTTP_201_CREATED)
async def create_report(
    body: ReportCreate,
    user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db),
):
    if body.target_type == ReportTarget.user and body.target_id == user.id:
        raise HTTPException(status_code=400, detail="Cannot report yourself")

    if not await _target_exists(db, body.target_type, body.target_id):
        raise HTTPException(
            status_code=404,
            detail=f"{body.target_type.value} {body.target_id} not found",
        )

    row = Report(
        reporter_id=user.id,
        target_type=body.target_type,
        target_id=body.target_id,
        reason=body.reason,
        details=body.details,
    )
    db.add(row)
    await db.flush()
    await db.refresh(row)
    logger.info(
        "report_filed",
        report_id=row.id,
        reporter=user.id,
        target=f"{body.target_type.value}:{body.target_id}",
        reason=body.reason.value,
    )
    return ReportOut.model_validate(row)


@router.get("/mine", response_model=list[ReportOut])
async def my_reports(
    user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db),
):
    rows = (
        await db.execute(
            select(Report)
            .where(Report.reporter_id == user.id)
            .order_by(Report.created_at.desc())
        )
    ).scalars().all()
    return [ReportOut.model_validate(r) for r in rows]


# ══════════════════════════════════════════════════════════════
#  Admin endpoints
# ══════════════════════════════════════════════════════════════
@router.get("/admin", response_model=list[ReportOut])
async def admin_list_reports(
    status_filter: ReportStatus | None = Query(None, alias="status"),
    target_type: ReportTarget | None = None,
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
    _: User = Depends(_admin_only),
    db: AsyncSession = Depends(get_db),
):
    stmt = select(Report)
    if status_filter:
        stmt = stmt.where(Report.status == status_filter)
    if target_type:
        stmt = stmt.where(Report.target_type == target_type)
    stmt = stmt.order_by(Report.created_at.desc()).offset(offset).limit(limit)

    rows = (await db.execute(stmt)).scalars().all()
    return [ReportOut.model_validate(r) for r in rows]


@router.get("/admin/stats")
async def admin_report_stats(
    _: User = Depends(_admin_only),
    db: AsyncSession = Depends(get_db),
):
    rows = (
        await db.execute(
            select(Report.status, func.count(Report.id))
            .group_by(Report.status)
        )
    ).all()
    counts = {s.value: 0 for s in ReportStatus}
    for status_, count in rows:
        counts[status_.value] = int(count)
    return {"counts_by_status": counts, "total": sum(counts.values())}


@router.patch("/admin/{report_id}/resolve", response_model=ReportOut)
async def admin_resolve(
    report_id: int,
    body: ReportResolve | None = None,
    admin: User = Depends(_admin_only),
    db: AsyncSession = Depends(get_db),
):
    report = await db.get(Report, report_id)
    if report is None:
        raise HTTPException(status_code=404, detail="Report not found")
    if report.status != ReportStatus.pending:
        raise HTTPException(
            status_code=400,
            detail=f"Report already {report.status.value}",
        )
    report.status = ReportStatus.resolved
    report.resolution_notes = body.notes if body else None
    report.resolved_by_id = admin.id
    report.resolved_at = datetime.now(timezone.utc)
    await db.flush()
    await db.refresh(report)
    logger.info(
        "report_resolved", report_id=report_id, admin=admin.id,
    )
    return ReportOut.model_validate(report)


@router.patch("/admin/{report_id}/dismiss", response_model=ReportOut)
async def admin_dismiss(
    report_id: int,
    body: ReportResolve | None = None,
    admin: User = Depends(_admin_only),
    db: AsyncSession = Depends(get_db),
):
    report = await db.get(Report, report_id)
    if report is None:
        raise HTTPException(status_code=404, detail="Report not found")
    if report.status != ReportStatus.pending:
        raise HTTPException(
            status_code=400,
            detail=f"Report already {report.status.value}",
        )
    report.status = ReportStatus.dismissed
    report.resolution_notes = body.notes if body else None
    report.resolved_by_id = admin.id
    report.resolved_at = datetime.now(timezone.utc)
    await db.flush()
    await db.refresh(report)
    logger.info(
        "report_dismissed", report_id=report_id, admin=admin.id,
    )
    return ReportOut.model_validate(report)
