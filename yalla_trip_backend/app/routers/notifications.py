"""Notifications router – CRUD for user notifications."""

from __future__ import annotations

import math

import structlog
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import func, select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.middleware.auth_middleware import get_current_active_user
from app.models.notification import Notification
from app.models.user import User
from app.schemas.common import MessageResponse, PaginatedResponse
from app.schemas.notification import NotificationOut

logger = structlog.get_logger(__name__)
router = APIRouter(prefix="/notifications", tags=["Notifications"])


@router.get("", response_model=PaginatedResponse[NotificationOut])
async def list_notifications(
    page: int = Query(1, ge=1),
    limit: int = Query(20, ge=1, le=100),
    unread_only: bool = False,
    user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db),
):
    stmt = select(Notification).where(Notification.user_id == user.id)
    if unread_only:
        stmt = stmt.where(Notification.is_read == False)  # noqa: E712
    stmt = stmt.order_by(Notification.created_at.desc())

    total = (await db.execute(select(func.count()).select_from(stmt.subquery()))).scalar() or 0
    pages = math.ceil(total / limit) if total else 0

    rows = (await db.execute(stmt.offset((page - 1) * limit).limit(limit))).scalars().all()
    return PaginatedResponse(
        items=[NotificationOut.model_validate(r) for r in rows],
        total=total, page=page, limit=limit, pages=pages,
    )


@router.get("/unread-count")
async def unread_count(
    user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db),
):
    count = (
        await db.execute(
            select(func.count(Notification.id)).where(
                Notification.user_id == user.id,
                Notification.is_read == False,  # noqa: E712
            )
        )
    ).scalar() or 0
    return {"unread_count": count}


@router.put("/mark-all-read", response_model=MessageResponse)
async def mark_all_read(
    user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db),
):
    await db.execute(
        update(Notification)
        .where(Notification.user_id == user.id, Notification.is_read == False)  # noqa: E712
        .values(is_read=True)
    )
    await db.flush()
    return MessageResponse(
        message="All notifications marked as read",
        message_ar="تم قراءة جميع الإشعارات",
    )


@router.put("/{notification_id}/read", response_model=NotificationOut)
async def mark_read(
    notification_id: int,
    user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(Notification).where(
            Notification.id == notification_id,
            Notification.user_id == user.id,
        )
    )
    notif = result.scalar_one_or_none()
    if notif is None:
        raise HTTPException(status_code=404, detail="Notification not found")
    notif.is_read = True
    await db.flush()
    await db.refresh(notif)
    return NotificationOut.model_validate(notif)


@router.delete("/{notification_id}", response_model=MessageResponse)
async def delete_notification(
    notification_id: int,
    user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(Notification).where(
            Notification.id == notification_id,
            Notification.user_id == user.id,
        )
    )
    notif = result.scalar_one_or_none()
    if notif is None:
        raise HTTPException(status_code=404, detail="Notification not found")
    await db.delete(notif)
    await db.flush()
    return MessageResponse(
        message="Notification deleted",
        message_ar="تم حذف الإشعار",
    )
