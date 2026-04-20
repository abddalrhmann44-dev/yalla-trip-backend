"""Device-token management – register / unregister push devices."""

from __future__ import annotations

from datetime import datetime, timezone

import structlog
from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, Field
from sqlalchemy import delete, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.middleware.auth_middleware import get_current_active_user
from app.models.device_token import DevicePlatform, DeviceToken
from app.models.user import User
from app.schemas.common import MessageResponse

logger = structlog.get_logger(__name__)
router = APIRouter(prefix="/devices", tags=["Devices"])


class DeviceRegister(BaseModel):
    token: str = Field(..., min_length=8, max_length=512)
    platform: DevicePlatform = DevicePlatform.android
    app_version: str | None = Field(None, max_length=32)


class DeviceOut(BaseModel):
    id: int
    token: str
    platform: DevicePlatform
    app_version: str | None = None
    last_seen_at: datetime
    created_at: datetime

    model_config = {"from_attributes": True}


@router.post(
    "",
    response_model=DeviceOut,
    status_code=status.HTTP_201_CREATED,
)
async def register_device(
    body: DeviceRegister,
    user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db),
):
    """Idempotent – if the token already exists we just refresh it."""
    existing = (
        await db.execute(
            select(DeviceToken)
            .where(DeviceToken.user_id == user.id)
            .where(DeviceToken.token == body.token)
        )
    ).scalar_one_or_none()

    if existing is not None:
        existing.platform = body.platform
        existing.app_version = body.app_version
        existing.last_seen_at = datetime.now(timezone.utc)
        await db.flush()
        await db.refresh(existing)
        return DeviceOut.model_validate(existing)

    device = DeviceToken(
        user_id=user.id,
        token=body.token,
        platform=body.platform,
        app_version=body.app_version,
    )
    db.add(device)
    await db.flush()
    await db.refresh(device)

    # Mirror into the legacy single-column field so older code paths
    # that still read ``user.fcm_token`` keep working.
    user.fcm_token = body.token
    await db.flush()

    logger.info(
        "device_registered",
        user_id=user.id,
        platform=body.platform.value,
    )
    return DeviceOut.model_validate(device)


@router.get("", response_model=list[DeviceOut])
async def list_devices(
    user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db),
):
    rows = (
        await db.execute(
            select(DeviceToken)
            .where(DeviceToken.user_id == user.id)
            .order_by(DeviceToken.last_seen_at.desc())
        )
    ).scalars().all()
    return [DeviceOut.model_validate(r) for r in rows]


@router.delete("/{device_id}", response_model=MessageResponse)
async def delete_device(
    device_id: int,
    user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db),
):
    device = await db.get(DeviceToken, device_id)
    if device is None or device.user_id != user.id:
        raise HTTPException(status_code=404, detail="Device not found")
    await db.delete(device)
    await db.flush()
    logger.info("device_deleted", device_id=device_id, user_id=user.id)
    return MessageResponse(message="Device removed", message_ar="تم حذف الجهاز")


@router.delete("", response_model=MessageResponse)
async def delete_all_devices(
    user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db),
):
    """Sign-out everywhere shortcut – removes every push target."""
    await db.execute(
        delete(DeviceToken).where(DeviceToken.user_id == user.id)
    )
    user.fcm_token = None
    await db.flush()
    logger.info("devices_cleared", user_id=user.id)
    return MessageResponse(
        message="All devices removed", message_ar="تم حذف جميع الأجهزة"
    )
