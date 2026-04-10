"""Auth router – Firebase token → JWT exchange, refresh, /me."""

from __future__ import annotations

import structlog
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.middleware.auth_middleware import (
    create_access_token,
    create_refresh_token,
    decode_token,
    get_current_user,
)
from app.models.user import User
from app.schemas.user import (
    FirebaseTokenRequest,
    RefreshTokenRequest,
    TokenPayload,
    UserOut,
)
from app.services.firebase_service import get_firebase_user, verify_firebase_token

logger = structlog.get_logger(__name__)
router = APIRouter(prefix="/auth", tags=["Auth"])


@router.post("/verify-token", response_model=TokenPayload)
async def verify_token(
    body: FirebaseTokenRequest,
    db: AsyncSession = Depends(get_db),
):
    """Verify a Firebase ID token. Create the user if first login, then return JWT."""
    decoded = await verify_firebase_token(body.firebase_token)
    if decoded is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="رمز Firebase غير صالح / Invalid Firebase token",
        )

    firebase_uid = decoded["uid"]

    # ── Lookup or create user ─────────────────────────────
    result = await db.execute(select(User).where(User.firebase_uid == firebase_uid))
    user = result.scalar_one_or_none()

    if user is None:
        fb_info = await get_firebase_user(firebase_uid) or {}
        user = User(
            firebase_uid=firebase_uid,
            name=fb_info.get("display_name") or decoded.get("name", "User"),
            email=fb_info.get("email") or decoded.get("email"),
            phone=fb_info.get("phone_number") or decoded.get("phone_number"),
            avatar_url=fb_info.get("photo_url"),
            is_verified=decoded.get("email_verified", False),
        )
        db.add(user)
        await db.flush()
        await db.refresh(user)
        logger.info("user_created_from_firebase", user_id=user.id)

    access = create_access_token(user.id, user.role.value)
    refresh = create_refresh_token(user.id)

    return TokenPayload(
        access_token=access,
        refresh_token=refresh,
        user=UserOut.model_validate(user),
    )


@router.post("/refresh", response_model=TokenPayload)
async def refresh_token(
    body: RefreshTokenRequest,
    db: AsyncSession = Depends(get_db),
):
    """Exchange a refresh token for a new access + refresh pair."""
    payload = decode_token(body.refresh_token)
    if payload is None or payload.get("type") != "refresh":
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="رمز التحديث غير صالح / Invalid refresh token",
        )

    user_id = int(payload["sub"])
    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()
    if user is None or not user.is_active:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="User not found")

    access = create_access_token(user.id, user.role.value)
    refresh = create_refresh_token(user.id)

    return TokenPayload(
        access_token=access,
        refresh_token=refresh,
        user=UserOut.model_validate(user),
    )


@router.get("/me", response_model=UserOut)
async def auth_me(user: User = Depends(get_current_user)):
    """Return the currently authenticated user."""
    return UserOut.model_validate(user)
