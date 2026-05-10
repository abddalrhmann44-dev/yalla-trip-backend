"""WAapi (waapi.app) WhatsApp messaging service.

Sends messages through a connected WAapi instance.  Configure via:
  WAAPI_TOKEN       – Bearer token from the waapi.app dashboard
  WAAPI_INSTANCE_ID – Instance ID shown next to the QR code screen

When either variable is missing the call returns False and the caller
is responsible for a fallback (e.g. logging the message for dev).
"""

from __future__ import annotations

import httpx
import structlog

from app.config import get_settings

logger = structlog.get_logger(__name__)

_BASE_URL = "https://waapi.app/api/v1"


def _chat_id(phone: str) -> str:
    """Convert E.164 phone (+201012345678) to WAapi chatId (201012345678@c.us)."""
    return phone.lstrip("+") + "@c.us"


async def send_message(phone: str, message: str) -> bool:
    """Send a WhatsApp message to *phone* via WAapi.  Returns True on success."""
    settings = get_settings()
    token = settings.WAAPI_TOKEN
    instance = settings.WAAPI_INSTANCE_ID

    if not token or not instance:
        logger.warning("waapi_not_configured", phone=phone)
        return False

    url = f"{_BASE_URL}/instances/{instance}/client/action/send-message"
    payload = {
        "chatId": _chat_id(phone),
        "message": message,
    }

    try:
        async with httpx.AsyncClient(timeout=15) as client:
            resp = await client.post(
                url,
                json=payload,
                headers={
                    "Authorization": f"Bearer {token}",
                    "Accept": "application/json",
                    "Content-Type": "application/json",
                },
            )
        if resp.status_code < 300:
            logger.info("waapi_message_sent", phone=phone, instance=instance)
            return True
        logger.error(
            "waapi_send_failed",
            phone=phone,
            status=resp.status_code,
            body=resp.text[:500],
        )
        return False
    except Exception as exc:
        logger.error("waapi_send_error", phone=phone, error=str(exc))
        return False


async def send_otp(phone: str, code: str) -> bool:
    """Send a 6-digit OTP over WhatsApp.  Returns True if the message was delivered."""
    message = (
        f"كود التحقق الخاص بك في طلعة: *{code}*\n"
        "لا تشارك هذا الكود مع أي شخص.\n\n"
        f"Your Talaa verification code: *{code}*\n"
        "Do not share this code with anyone."
    )
    return await send_message(phone, message)
