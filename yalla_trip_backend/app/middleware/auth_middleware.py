"""JWT creation / verification and FastAPI dependency for current user."""

from __future__ import annotations

import secrets
from datetime import datetime, timedelta, timezone
from typing import Optional

import structlog
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from jose import JWTError, jwt
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import get_settings
from app.database import get_db
from app.models.user import User, UserRole

logger = structlog.get_logger(__name__)
settings = get_settings()

_bearer = HTTPBearer(auto_error=False)


# ── Token helpers ─────────────────────────────────────────
def create_access_token(user_id: int, role: str) -> str:
    expire = datetime.now(timezone.utc) + timedelta(minutes=settings.JWT_EXPIRE_MINUTES)
    return jwt.encode(
        {"sub": str(user_id), "role": role, "exp": expire},
        settings.SECRET_KEY,
        algorithm=settings.JWT_ALGORITHM,
    )


def create_refresh_token(
    user_id: int,
    *,
    jti: str | None = None,
    family_id: str | None = None,
) -> tuple[str, str, str, datetime]:
    """Issue a refresh token with a tracked ``jti`` and ``family_id``.

    Returns a tuple ``(token, jti, family_id, expires_at)`` so the
    caller can persist the row for rotation-tracking.  ``family_id``
    propagates across the chain of rotations; pass it through from
    the previous token, or leave ``None`` to start a new family (i.e.
    a brand-new login session).
    """
    jti = jti or secrets.token_urlsafe(32)
    family_id = family_id or secrets.token_urlsafe(32)
    expire = datetime.now(timezone.utc) + timedelta(
        days=settings.JWT_REFRESH_EXPIRE_DAYS
    )
    token = jwt.encode(
        {
            "sub": str(user_id),
            "type": "refresh",
            "jti": jti,
            "fam": family_id,
            "exp": expire,
        },
        settings.SECRET_KEY,
        algorithm=settings.JWT_ALGORITHM,
    )
    return token, jti, family_id, expire


def decode_token(token: str) -> dict | None:
    try:
        return jwt.decode(token, settings.SECRET_KEY, algorithms=[settings.JWT_ALGORITHM])
    except JWTError:
        return None


# ── FastAPI dependencies ──────────────────────────────────
async def get_current_user(
    creds: Optional[HTTPAuthorizationCredentials] = Depends(_bearer),
    db: AsyncSession = Depends(get_db),
) -> User:
    """Extract and validate the JWT, return the User row."""
    if creds is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="يجب تسجيل الدخول / Authentication required",
        )
    payload = decode_token(creds.credentials)
    if payload is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="رمز غير صالح / Invalid token",
        )
    user_id = int(payload["sub"])
    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()
    if user is None or not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="المستخدم غير موجود أو معطل / User not found or disabled",
        )
    return user


async def get_current_active_user(
    user: User = Depends(get_current_user),
) -> User:
    if not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="الحساب معطل / Account disabled",
        )
    # Tag the Sentry scope with the authenticated user so exceptions
    # captured later in the request can be attributed to them.
    try:
        from app.services.sentry_service import set_user_tag
        set_user_tag(user.id, user.role.value if user.role else None)
    except Exception:
        pass
    return user


def require_role(*roles: UserRole):
    """Return a dependency that enforces one of the given roles."""

    async def _check(user: User = Depends(get_current_active_user)) -> User:
        if user.role not in roles:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="ليس لديك صلاحية / Insufficient permissions",
            )
        return user

    return _check
