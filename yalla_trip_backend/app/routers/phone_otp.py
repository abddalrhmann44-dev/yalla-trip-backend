"""Phone OTP endpoints (Wave 23).

POST /me/phone/start-otp   – request a 6-digit SMS code
POST /me/phone/verify-otp  – confirm the code (flips ``phone_verified``)
"""

from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, Field
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.middleware.auth_middleware import get_current_active_user
from app.models.user import User
from app.services import brute_force_guard, phone_otp_service

router = APIRouter(tags=["PhoneOtp"])

# Scope for brute-force guard counters.  Kept distinct from any
# future auth scopes so a locked OTP never blocks, say, password reset.
_OTP_SCOPE = "otp"


class StartOtpBody(BaseModel):
    phone: str = Field(..., min_length=6, max_length=30)


class VerifyOtpBody(BaseModel):
    phone: str = Field(..., min_length=6, max_length=30)
    code: str = Field(..., min_length=4, max_length=8, pattern=r"^\d+$")


class OtpStartedOut(BaseModel):
    phone: str
    expires_in: int  # seconds


class OtpVerifiedOut(BaseModel):
    phone_verified: bool = True
    phone: str


@router.post(
    "/me/phone/start-otp",
    response_model=OtpStartedOut,
    status_code=status.HTTP_200_OK,
)
async def start_otp(
    body: StartOtpBody,
    user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db),
):
    # Refuse to hand out fresh codes while the phone is locked — stops
    # the "request new challenge after each wrong guess" attack.
    await brute_force_guard.assert_not_locked(_OTP_SCOPE, body.phone)

    try:
        row = await phone_otp_service.start_challenge(db, user, body.phone)
    except ValueError:
        raise HTTPException(
            status_code=422,
            detail="رقم الموبايل غير صالح / Invalid phone number",
        )
    return OtpStartedOut(
        phone=row.phone,
        expires_in=phone_otp_service.OTP_TTL_SECONDS,
    )


@router.post(
    "/me/phone/verify-otp",
    response_model=OtpVerifiedOut,
    status_code=status.HTTP_200_OK,
)
async def verify_otp(
    body: VerifyOtpBody,
    user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db),
):
    await brute_force_guard.assert_not_locked(_OTP_SCOPE, body.phone)

    try:
        await phone_otp_service.verify_challenge(
            db, user, body.phone, body.code,
        )
    except ValueError:
        raise HTTPException(
            status_code=422,
            detail="رقم الموبايل غير صالح / Invalid phone number",
        )
    except phone_otp_service.OtpError as exc:
        code = str(exc)
        # Record a failure for the codes that represent an actual
        # attack signal.  ``no_active_challenge`` is NOT counted —
        # that fires for legit users whose code expired server-side.
        if code in {"wrong_code", "exhausted", "expired"}:
            await brute_force_guard.record_failure(_OTP_SCOPE, body.phone)
        messages = {
            "no_active_challenge": "لا يوجد طلب تحقق نشط / No active OTP challenge",
            "expired": "انتهى وقت الكود / OTP has expired",
            "exhausted": "تم تجاوز عدد المحاولات / Too many wrong attempts",
            "wrong_code": "الكود غير صحيح / Wrong code",
        }
        raise HTTPException(status_code=400, detail=messages.get(code, code))

    # Success — wipe the counter so future mistakes start fresh.
    await brute_force_guard.clear_failures(_OTP_SCOPE, body.phone)

    assert user.phone is not None
    return OtpVerifiedOut(phone_verified=True, phone=user.phone)
