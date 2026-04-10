"""Users router – profile CRUD + avatar upload."""

from __future__ import annotations

import structlog
from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.middleware.auth_middleware import get_current_active_user
from app.models.user import User
from app.schemas.common import MessageResponse
from app.schemas.user import UserOut, UserUpdate
from app.services.s3_service import upload_image

logger = structlog.get_logger(__name__)
router = APIRouter(prefix="/users", tags=["Users"])


@router.get("/me", response_model=UserOut)
async def get_profile(user: User = Depends(get_current_active_user)):
    return UserOut.model_validate(user)


@router.put("/me", response_model=UserOut)
async def update_profile(
    body: UserUpdate,
    user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db),
):
    update_data = body.model_dump(exclude_unset=True)
    for key, value in update_data.items():
        setattr(user, key, value)
    await db.flush()
    await db.refresh(user)
    return UserOut.model_validate(user)


@router.post("/me/avatar", response_model=UserOut)
async def upload_avatar(
    file: UploadFile = File(...),
    user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db),
):
    if file.content_type not in ("image/jpeg", "image/png", "image/webp"):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="صيغة الصورة غير مدعومة / Unsupported image format",
        )
    url = await upload_image(file.file, folder="avatars", content_type=file.content_type)
    user.avatar_url = url
    await db.flush()
    await db.refresh(user)
    return UserOut.model_validate(user)


@router.delete("/me", response_model=MessageResponse)
async def delete_account(
    user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db),
):
    user.is_active = False
    await db.flush()
    logger.info("user_deactivated", user_id=user.id)
    return MessageResponse(
        message="Account deactivated successfully",
        message_ar="تم تعطيل الحساب بنجاح",
    )
