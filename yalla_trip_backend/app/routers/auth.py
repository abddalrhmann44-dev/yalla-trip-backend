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
from pydantic import BaseModel, Field

from app.services import brute_force_guard, phone_otp_service
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
#  WhatsApp OTP login / register
#  --------------------------------------------------------------
#  Replaces Firebase Phone Auth for the public sign-in flow.  The
#  user types their Egyptian mobile number, we deliver a 6-digit
#  code over WhatsApp via WaAPI, and on verify-otp we either look
#  up the existing User row by phone or create a new one (with a
#  synthetic ``firebase_uid`` of the form ``wa:+20…`` so the column
#  uniqueness constraint is preserved).
# ══════════════════════════════════════════════════════════════
_WHATSAPP_AUTH_SCOPE = "wa_auth"


class WhatsappStartOtpBody(BaseModel):
    phone: str = Field(..., min_length=6, max_length=30)


class WhatsappVerifyOtpBody(BaseModel):
    phone: str = Field(..., min_length=6, max_length=30)
    code: str = Field(..., min_length=4, max_length=8, pattern=r"^\d+$")
    name: str = Field("", max_length=120)
    referral_code: str | None = Field(None, max_length=32)


class WhatsappOtpStartedOut(BaseModel):
    phone: str
    expires_in: int


@router.post("/whatsapp/start-otp", response_model=WhatsappOtpStartedOut)
async def whatsapp_start_otp(
    body: WhatsappStartOtpBody,
    db: AsyncSession = Depends(get_db),
):
    """Send a 6-digit WhatsApp OTP to ``phone`` for login / register.

    No authentication required — this is the very first call in the
    sign-in funnel.  Brute-force protection is keyed on the phone so
    spamming a victim's number locks the *attempts*, not the victim.
    """
    await brute_force_guard.assert_not_locked(_WHATSAPP_AUTH_SCOPE, body.phone)

    try:
        row = await phone_otp_service.start_pre_auth_challenge(db, body.phone)
    except ValueError:
        raise HTTPException(
            status_code=422,
            detail="رقم الموبايل غير صالح / Invalid phone number",
        )

    return WhatsappOtpStartedOut(
        phone=row.phone,
        expires_in=phone_otp_service.OTP_TTL_SECONDS,
    )


@router.post("/whatsapp/verify-otp", response_model=TokenPayload)
async def whatsapp_verify_otp(
    body: WhatsappVerifyOtpBody,
    request: Request,
    db: AsyncSession = Depends(get_db),
):
    """Verify the WhatsApp OTP and issue a backend JWT.

    On the first successful verify for a phone we create a brand-new
    [`User`] row (role=guest, phone_verified=True, ``firebase_uid``
    set to ``wa:<phone>`` so the column's NOT NULL + unique constraint
    is satisfied).  Repeat sign-ins reuse the existing row.
    """
    await brute_force_guard.assert_not_locked(_WHATSAPP_AUTH_SCOPE, body.phone)

    try:
        await phone_otp_service.verify_pre_auth_challenge(
            db, body.phone, body.code,
        )
    except ValueError:
        raise HTTPException(
            status_code=422,
            detail="رقم الموبايل غير صالح / Invalid phone number",
        )
    except phone_otp_service.OtpError as exc:
        code = str(exc)
        if code in {"wrong_code", "exhausted", "expired"}:
            await brute_force_guard.record_failure(
                _WHATSAPP_AUTH_SCOPE, body.phone,
            )
        messages = {
            "no_active_challenge": "لا يوجد طلب تحقق نشط / No active OTP challenge",
            "expired": "انتهى وقت الكود / OTP has expired",
            "exhausted": "تم تجاوز عدد المحاولات / Too many wrong attempts",
            "wrong_code": "الكود غير صحيح / Wrong code",
        }
        raise HTTPException(status_code=400, detail=messages.get(code, code))

    await brute_force_guard.clear_failures(_WHATSAPP_AUTH_SCOPE, body.phone)

    # ── Lookup-or-create the user keyed by phone ──────────────
    normalized_phone = phone_otp_service.normalize_phone(body.phone)
    result = await db.execute(
        select(User).where(User.phone == normalized_phone)
    )
    user = result.scalar_one_or_none()

    if user is None:
        synthetic_uid = f"wa:{normalized_phone}"
        display_name = (body.name.strip() or "User")[:120]
        user = User(
            firebase_uid=synthetic_uid,
            name=display_name,
            phone=normalized_phone,
            phone_verified=True,
            phone_verified_at=datetime.now(timezone.utc),
            role=UserRole.guest,
        )
        db.add(user)
        await db.flush()
        await db.refresh(user)
        logger.info(
            "user_created_from_whatsapp_otp",
            user_id=user.id,
            phone=normalized_phone,
        )

        # Wave 11 referral link, mirrors the Firebase verify-token path.
        if body.referral_code:
            try:
                await attach_referral_on_signup(db, user, body.referral_code)
            except Exception as exc:  # pragma: no cover
                logger.error("attach_referral_failed", err=str(exc))
    else:
        # Existing user — keep the verified phone state up to date so
        # the host-onboarding screens don't re-prompt.  Also update
        # the display name when the caller supplies one and the
        # current value is the placeholder default.
        assert user is not None
        if not user.phone_verified:
            user.phone_verified = True
            user.phone_verified_at = datetime.now(timezone.utc)
        if body.name.strip() and user.name in {"", "User"}:
            user.name = body.name.strip()[:120]
        await db.flush()
        logger.info(
            "user_login_via_whatsapp_otp",
            user_id=user.id,
            phone=normalized_phone,
        )

    return await _issue_pair(db, user, request, family_id=None)


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
