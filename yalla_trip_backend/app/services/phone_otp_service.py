"""Phone-number OTP challenge orchestration (Wave 23).

This service is transport-agnostic: it generates codes, persists
hashed records, and exposes ``start`` / ``verify`` helpers.  The SMS
delivery layer is stubbed to logging — wire Twilio / Vonage / a local
Egyptian aggregator behind ``_send_sms`` when the business is ready.
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


async def _send_sms(phone: str, code: str) -> None:
    """Placeholder SMS delivery.

    Replace with a real provider in production.  Kept as a coroutine
    so real implementations can use async httpx without refactor.
    """
    # IMPORTANT:  never log the real code in production – this is a
    # developer convenience.  We use INFO so the code is visible in
    # ``docker compose logs api`` during manual testing.
    logger.info("phone_otp_sent", phone=phone, code=code)


# ── orchestration ────────────────────────────────────────────

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

    await _send_sms(normalized, code)
    logger.info(
        "phone_otp_started", user_id=user.id, phone=normalized, otp_id=row.id,
    )
    return row


class OtpError(Exception):
    """Raised when an OTP cannot be verified (expired, wrong, …)."""


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

    if row.code_hash != _hash_code(code):
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
