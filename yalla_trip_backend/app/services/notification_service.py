"""FCM push notification + in-app notification persistence."""

from __future__ import annotations

from typing import Optional

import httpx
import structlog
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import get_settings
from app.models.notification import Notification, NotificationType

logger = structlog.get_logger(__name__)
settings = get_settings()


async def send_push(
    fcm_token: str,
    title: str,
    body: str,
    data: Optional[dict] = None,
) -> bool:
    """Send an FCM push notification via the legacy HTTP API."""
    if not settings.FCM_SERVER_KEY:
        logger.warning("fcm_skipped_no_key")
        return False

    payload = {
        "to": fcm_token,
        "notification": {"title": title, "body": body},
        "data": data or {},
    }
    headers = {
        "Authorization": f"key={settings.FCM_SERVER_KEY}",
        "Content-Type": "application/json",
    }
    try:
        async with httpx.AsyncClient(timeout=10) as client:
            resp = await client.post(
                "https://fcm.googleapis.com/fcm/send",
                json=payload,
                headers=headers,
            )
            logger.info("fcm_sent", status=resp.status_code)
            return resp.status_code == 200
    except Exception as exc:
        logger.error("fcm_error", error=str(exc))
        return False


async def create_notification(
    db: AsyncSession,
    user_id: int,
    title: str,
    body: str,
    notif_type: NotificationType = NotificationType.system,
) -> Notification:
    """Persist an in-app notification row."""
    notif = Notification(
        user_id=user_id,
        title=title,
        body=body,
        type=notif_type,
    )
    db.add(notif)
    await db.flush()
    logger.info("notification_created", user_id=user_id, type=notif_type.value)
    return notif
