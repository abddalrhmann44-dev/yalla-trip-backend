"""Auth router – Firebase token → JWT exchange, refresh, /me."""

from __future__ import annotations

from datetime import datetime, timezone

import structlog
from fastapi import APIRouter, Depends, HTTPException, Request, status
from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import get_settings
from app.database import get_db
from app.middleware.auth_middleware import (
    create_access_token,
    create_refresh_token,
    decode_token,
    get_current_active_user,
    get_current_user,
)
from app.models.refresh_token import RefreshToken
from app.models.user import User, UserRole
from app.schemas.user import (
    FirebaseTokenRequest,
    RefreshTokenRequest,
    TokenPayload,
    UserOut,
)
from app.services.firebase_service import get_firebase_user, verify_firebase_token
from app.services.wallet_service import attach_referral_on_signup

_settings = get_settings()

logger = structlog.get_logger(__name__)
router = APIRouter(prefix="/auth", tags=["Auth"])


# ── Helpers ───────────────────────────────────────────────
def _clip(s: str | None, max_len: int) -> str | None:
    if s is None:
        return None
    if len(s) <= max_len:
        return s
    return s[:max_len]


def _client_meta(request: Request) -> tuple[str | None, str | None]:
    """Extract a (user_agent, ip) pair from the incoming request.

    These are purely informational – shown in the sessions list – and
    never used for auth decisions.
    """
    ua = request.headers.get("user-agent")
    if ua and len(ua) > 256:
        ua = ua[:256]
    # Respect a proxy chain but never trust more than the first hop.
    fwd = request.headers.get("x-forwarded-for")
    ip = fwd.split(",")[0].strip() if fwd else (
        request.client.host if request.client else None
    )
    return ua, ip


async def _issue_pair(
    db: AsyncSession,
    user: User,
    request: Request,
    *,
    family_id: str | None = None,
) -> TokenPayload:
    """Create an access+refresh pair and persist the refresh row."""
    access = create_access_token(user.id, user.role.value)
    refresh, jti, fam, expires = create_refresh_token(
        user.id, family_id=family_id
    )
    ua, ip = _client_meta(request)
    db.add(RefreshToken(
        user_id=user.id,
        jti=jti,
        family_id=fam,
        expires_at=expires,
        user_agent=ua,
        ip_address=ip,
    ))
    await db.flush()
    return TokenPayload(
        access_token=access,
        refresh_token=refresh,
        user=UserOut.model_validate(user),
    )


@router.post("/verify-token", response_model=TokenPayload)
async def verify_token(
    body: FirebaseTokenRequest,
    request: Request,
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

    try:
        # ── Lookup or create user ─────────────────────────────
        result = await db.execute(select(User).where(User.firebase_uid == firebase_uid))
        user = result.scalar_one_or_none()

        if user is None:
            fb_info = await get_firebase_user(firebase_uid) or {}
            email = fb_info.get("email") or decoded.get("email")

            # Auto-promote bootstrap admin emails (configured via ADMIN_EMAILS env)
            initial_role = UserRole.guest
            if email and email.lower() in _settings.admin_emails_set:
                initial_role = UserRole.admin
                logger.info("user_bootstrapped_as_admin", email=email)

            display = fb_info.get("display_name") or decoded.get("name") or "User"
            user = User(
                firebase_uid=firebase_uid,
                name=_clip(display, 120) or "User",
                email=email,
                phone=fb_info.get("phone_number") or decoded.get("phone_number"),
                avatar_url=_clip(fb_info.get("photo_url"), 512),
                is_verified=decoded.get("email_verified", False),
                role=initial_role,
            )
            db.add(user)
            await db.flush()
            await db.refresh(user)
            logger.info(
                "user_created_from_firebase", user_id=user.id, role=user.role.value
            )

            # Wave 11: link referrer on first login if a valid ref code was
            # passed in the verify-token payload.
            if body.referral_code:
                try:
                    await attach_referral_on_signup(db, user, body.referral_code)
                except Exception as exc:      # pragma: no cover
                    logger.error("attach_referral_failed", err=str(exc))
        else:
            # Existing user — if their email is now in ADMIN_EMAILS and they
            # aren't admin yet, promote them (one-way: never auto-demote).
            if (
                user.email
                and user.email.lower() in _settings.admin_emails_set
                and user.role != UserRole.admin
            ):
                user.role = UserRole.admin
                await db.flush()
                await db.refresh(user)
                logger.info("user_promoted_to_admin", user_id=user.id)

        # Fresh login starts a brand-new refresh-token family.
        return await _issue_pair(db, user, request, family_id=None)
    except HTTPException:
        raise
    except Exception as exc:
        logger.error(
            "verify_token_failed",
            firebase_uid=firebase_uid,
            error=repr(exc),
            error_type=type(exc).__name__,
        )
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Login failed: {type(exc).__name__}: {exc}",
        )


@router.post("/refresh", response_model=TokenPayload)
async def refresh_token(
    body: RefreshTokenRequest,
    request: Request,
    db: AsyncSession = Depends(get_db),
):
    """Rotate a refresh token.

    On success the presented token is stamped as *used* and a brand
    new pair is issued in the same family.  If a token that's already
    been used – i.e. a potential replay / theft – is presented again,
    the entire family is revoked and the caller must log in again.
    """
    payload = decode_token(body.refresh_token)
    if payload is None or payload.get("type") != "refresh":
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="رمز التحديث غير صالح / Invalid refresh token",
        )

    jti = payload.get("jti")
    family_id = payload.get("fam")
    user_id = int(payload["sub"])

    # Legacy refresh tokens (issued before rotation was added) lack a
    # ``jti`` – accept them once and immediately upgrade the caller
    # onto the rotation scheme so nobody gets logged out on deploy.
    if not jti or not family_id:
        result = await db.execute(select(User).where(User.id == user_id))
        user = result.scalar_one_or_none()
        if user is None or not user.is_active:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="User not found",
            )
        logger.info("refresh_legacy_upgrade", user_id=user.id)
        return await _issue_pair(db, user, request, family_id=None)

    # ── Lookup the stored row ─────────────────────────────
    row = (
        await db.execute(
            select(RefreshToken).where(RefreshToken.jti == jti)
        )
    ).scalar_one_or_none()

    if row is None or row.revoked:
        # Unknown jti (or already-killed row) → reject; revoke family
        # defensively just in case someone guessed a jti in a live fam.
        if family_id:
            await db.execute(
                update(RefreshToken)
                .where(RefreshToken.family_id == family_id)
                .values(revoked=True, revoked_reason="reuse_detected")
            )
            await db.commit()
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Refresh token invalid or revoked",
        )

    now = datetime.now(timezone.utc)

    if row.expires_at < now:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Refresh token expired",
        )

    if row.used_at is not None:
        # Classic refresh-token reuse → suspicious.  Kill the family.
        logger.warning(
            "refresh_reuse_detected",
            user_id=row.user_id,
            family=row.family_id,
        )
        await db.execute(
            update(RefreshToken)
            .where(RefreshToken.family_id == row.family_id)
            .values(revoked=True, revoked_reason="reuse_detected")
        )
        # Commit the revocation BEFORE raising – HTTPException rolls
        # back the implicit transaction otherwise, defeating the
        # whole point of the reuse detection.
        await db.commit()
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Session compromised — please sign in again",
        )

    # ── Happy path: stamp this token as used, issue the next one. ─
    row.used_at = now

    result = await db.execute(select(User).where(User.id == row.user_id))
    user = result.scalar_one_or_none()
    if user is None or not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="User not found",
        )

    return await _issue_pair(db, user, request, family_id=row.family_id)


@router.get("/me", response_model=UserOut)
async def auth_me(user: User = Depends(get_current_user)):
    """Return the currently authenticated user."""
    return UserOut.model_validate(user)


# ══════════════════════════════════════════════════════════════
#  Session management
# ══════════════════════════════════════════════════════════════
@router.get("/sessions")
async def list_sessions(
    user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db),
):
    """Return the list of active refresh-token families for the user.

    Each entry represents one logged-in device.  The caller can revoke
    any of them from another device via ``DELETE /auth/sessions/{id}``.
    """
    # Latest row per family – that's the one currently in circulation.
    rows = (
        await db.execute(
            select(RefreshToken)
            .where(
                RefreshToken.user_id == user.id,
                RefreshToken.revoked.is_(False),
                RefreshToken.used_at.is_(None),
            )
            .order_by(RefreshToken.created_at.desc())
        )
    ).scalars().all()

    now = datetime.now(timezone.utc)
    return [
        {
            "id": r.id,
            "family_id": r.family_id,
            "user_agent": r.user_agent,
            "ip_address": r.ip_address,
            "created_at": r.created_at.isoformat(),
            "expires_at": r.expires_at.isoformat(),
            "expired": r.expires_at < now,
        }
        for r in rows
    ]


@router.delete("/sessions/{session_id}")
async def revoke_session(
    session_id: int,
    user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db),
):
    """Revoke a specific session (all tokens in its family)."""
    row = (
        await db.execute(
            select(RefreshToken)
            .where(RefreshToken.id == session_id, RefreshToken.user_id == user.id)
        )
    ).scalar_one_or_none()
    if row is None:
        raise HTTPException(status_code=404, detail="Session not found")
    await db.execute(
        update(RefreshToken)
        .where(RefreshToken.family_id == row.family_id)
        .values(revoked=True, revoked_reason="user_revoked")
    )
    return {"ok": True, "family_id": row.family_id}


@router.post("/sessions/revoke-all")
async def revoke_all_sessions(
    user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db),
):
    """Revoke every session belonging to the caller (panic button)."""
    result = await db.execute(
        update(RefreshToken)
        .where(
            RefreshToken.user_id == user.id,
            RefreshToken.revoked.is_(False),
        )
        .values(revoked=True, revoked_reason="user_revoked_all")
    )
    return {"ok": True, "revoked": result.rowcount or 0}


@router.post("/logout")
async def logout(
    body: RefreshTokenRequest,
    user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db),
):
    """Revoke the caller's current session based on the refresh token.

    The access token is short-lived so we don't need a blacklist; we
    just kill the refresh-token family so the next rotation fails.
    """
    payload = decode_token(body.refresh_token)
    family_id = (payload or {}).get("fam") if payload else None
    if not family_id:
        # Nothing to revoke – legacy token or garbage.  Treat as success.
        return {"ok": True, "revoked": 0}
    result = await db.execute(
        update(RefreshToken)
        .where(
            RefreshToken.family_id == family_id,
            RefreshToken.user_id == user.id,
        )
        .values(revoked=True, revoked_reason="logout")
    )
    return {"ok": True, "revoked": result.rowcount or 0}
