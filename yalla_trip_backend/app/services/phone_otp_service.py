"""Phone-number OTP challenge orchestration (Wave 23).

This service generates codes, persists hashed records, and exposes
``start`` / ``verify`` helpers.  OTP delivery goes through WhatsApp
Cloud API when credentials are configured; otherwise falls back to
logging so local dev still works without an API key.
"""

from __future__ import annotations

import hashlib
import secrets
import re
from datetime import datetime, timedelta, timezone

import structlog
from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.phone_otp import (
    MAX_VERIFY_ATTEMPTS,
    OTP_TTL_SECONDS,
    PhoneOtp,
)
from app.models.user import User
from app.services import waapi_service

logger = structlog.get_logger(__name__)


# ── public helpers ───────────────────────────────────────────

def normalize_phone(raw: str) -> str:
    """Return an E.164-ish form for Egyptian numbers.

    Accepts:
        +201012345678 → +201012345678
         201012345678 → +201012345678
         01012345678  → +201012345678
        '(010) 1234 5678' → +201012345678

    Rejects anything that doesn't yield exactly 12 digits after the
    country code (Egypt, +20).
    """
    # Keep only digits
    digits = re.sub(r"\D", "", raw)
    if digits.startswith("0020"):
        digits = digits[4:]
    elif digits.startswith("20"):
        digits = digits[2:]
    elif digits.startswith("0"):
        digits = digits[1:]
    if len(digits) != 10:
        raise ValueError("invalid Egyptian mobile number")
    return "+20" + digits


def _hash_code(code: str) -> str:
    return hashlib.sha256(code.encode("utf-8")).hexdigest()


def _generate_code() -> str:
    # 6-digit numeric; the leading digit may be zero.
    return f"{secrets.randbelow(1_000_000):06d}"


# ── OTP delivery ─────────────────────────────────────────────

async def _send_otp(phone: str, code: str) -> None:
    """Deliver OTP via WhatsApp (WAapi), with log fallback for dev."""
    sent = await waapi_service.send_otp(phone, code)
    if not sent:
        logger.info("phone_otp_sent_log_fallback", phone=phone, code=code)


# ── orchestration ────────────────────────────────────────────


class OtpError(Exception):
    """Raised when an OTP cannot be verified (expired, wrong, …)."""


async def start_challenge(
    db: AsyncSession, user: User, phone: str,
) -> PhoneOtp:
    """Create (or replace) an OTP challenge for ``(user, phone)``.

    Any previous pending rows for this user + phone are marked ``used``
    so they can no longer be verified.
    """
    normalized = normalize_phone(phone)

    # Invalidate older pending rows
    await db.execute(
        update(PhoneOtp)
        .where(
            PhoneOtp.user_id == user.id,
            PhoneOtp.phone == normalized,
            PhoneOtp.used.is_(False),
        )
        .values(used=True)
    )

    code = _generate_code()
    row = PhoneOtp(
        user_id=user.id,
        phone=normalized,
        code_hash=_hash_code(code),
        expires_at=datetime.now(timezone.utc)
        + timedelta(seconds=OTP_TTL_SECONDS),
    )
    db.add(row)
    await db.flush()
    await db.refresh(row)

    await _send_otp(normalized, code)
    logger.info(
        "phone_otp_started", user_id=user.id, phone=normalized, otp_id=row.id,
    )
    return row


# ── Pre-auth (login / register) variant ─────────────────────────
# These mirror ``start_challenge`` / ``verify_challenge`` but create
# rows with ``user_id IS NULL``: the caller hasn't logged in yet, so
# there is no User to attach to.  The user row is created by the
# ``/auth/whatsapp/verify-otp`` endpoint *after* the code is matched.

async def start_pre_auth_challenge(
    db: AsyncSession, phone: str,
) -> PhoneOtp:
    """Create (or replace) a pre-auth OTP challenge for ``phone``.

    Mirrors :func:`start_challenge` but skips the ``user_id`` link so
    we can issue codes during login / register where no user row
    exists yet.
    """
    normalized = normalize_phone(phone)

    # Invalidate older pending pre-auth rows for the same phone so
    # only the latest code is ever valid.
    await db.execute(
        update(PhoneOtp)
        .where(
            PhoneOtp.user_id.is_(None),
            PhoneOtp.phone == normalized,
            PhoneOtp.used.is_(False),
        )
        .values(used=True)
    )

    code = _generate_code()
    row = PhoneOtp(
        user_id=None,
        phone=normalized,
        code_hash=_hash_code(code),
        expires_at=datetime.now(timezone.utc)
        + timedelta(seconds=OTP_TTL_SECONDS),
    )
    db.add(row)
    await db.flush()
    await db.refresh(row)

    await _send_otp(normalized, code)
    logger.info(
        "phone_otp_pre_auth_started", phone=normalized, otp_id=row.id,
    )
    return row


async def verify_pre_auth_challenge(
    db: AsyncSession, phone: str, code: str,
) -> None:
    """Validate ``code`` against the active pre-auth challenge.

    Raises :class:`OtpError` on any failure.  Does NOT create or
    mutate any User row — caller is responsible for the lookup-or-
    create after this returns successfully.
    """
    normalized = normalize_phone(phone)
    row = (
        await db.execute(
            select(PhoneOtp)
            .where(
                PhoneOtp.user_id.is_(None),
                PhoneOtp.phone == normalized,
                PhoneOtp.used.is_(False),
            )
            .order_by(PhoneOtp.created_at.desc())
        )
    ).scalar_one_or_none()

    if row is None:
        raise OtpError("no_active_challenge")
    if row.expires_at < datetime.now(timezone.utc):
        raise OtpError("expired")
    if row.attempts >= MAX_VERIFY_ATTEMPTS:
        raise OtpError("exhausted")

    test_code = _settings.OTP_TEST_CODE
    is_test_match = bool(test_code and code == test_code)

    if not is_test_match and row.code_hash != _hash_code(code):
        row.attempts += 1
        if row.attempts >= MAX_VERIFY_ATTEMPTS:
            row.used = True  # burn it
        await db.flush()
        raise OtpError("wrong_code")

    row.used = True
    await db.flush()
    logger.info(
        "phone_otp_pre_auth_verified", phone=normalized, otp_id=row.id,
    )


async def verify_challenge(
    db: AsyncSession, user: User, phone: str, code: str,
) -> None:
    """Validate ``code`` for the active challenge of ``(user, phone)``.

    On success sets ``User.phone`` + ``User.phone_verified`` + marks
    the OTP row as used.  Raises ``OtpError`` on any failure.
    """
    normalized = normalize_phone(phone)
    row = (
        await db.execute(
            select(PhoneOtp)
            .where(
                PhoneOtp.user_id == user.id,
                PhoneOtp.phone == normalized,
                PhoneOtp.used.is_(False),
            )
            .order_by(PhoneOtp.created_at.desc())
        )
    ).scalar_one_or_none()

    if row is None:
        raise OtpError("no_active_challenge")
    if row.expires_at < datetime.now(timezone.utc):
        raise OtpError("expired")
    if row.attempts >= MAX_VERIFY_ATTEMPTS:
        raise OtpError("exhausted")

    # Accept a fixed test code for TestFlight / QA builds.
    test_code = _settings.OTP_TEST_CODE
    is_test_match = bool(test_code and code == test_code)

    if not is_test_match and row.code_hash != _hash_code(code):
        row.attempts += 1
        if row.attempts >= MAX_VERIFY_ATTEMPTS:
            row.used = True  # burn it
        await db.flush()
        raise OtpError("wrong_code")

    # Success
    row.used = True
    user.phone = normalized
    user.phone_verified = True
    user.phone_verified_at = datetime.now(timezone.utc)
    await db.flush()
    logger.info(
        "phone_otp_verified", user_id=user.id, phone=normalized, otp_id=row.id,
    )
