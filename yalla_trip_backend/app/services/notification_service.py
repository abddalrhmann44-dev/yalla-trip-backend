"""Notification persistence + FCM push fan-out.

``create_notification`` is the single entry point every router uses to
alert a user:
    1. Writes a row in ``notifications`` (the in-app inbox).
    2. Fires a push to every registered device for the user (via
       ``app.services.push_service``).

The push step is fire-and-forget – failures never propagate to the
caller.  When Firebase isn't configured it simply no-ops.
"""

from __future__ import annotations

from typing import Any, Optional

import structlog
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.notification import Notification, NotificationType
from app.services.push_service import push_to_user

logger = structlog.get_logger(__name__)


async def create_notification(
    db: AsyncSession,
    user_id: int,
    title: str,
    body: str,
    notif_type: NotificationType = NotificationType.system,
    *,
    data: Optional[dict[str, Any]] = None,
    push: bool = True,
) -> Notification:
    """Persist an in-app notification row and (optionally) push it.

    Parameters
    ----------
    data
        Extra key-value pairs sent alongside the push so the Flutter
        client can deep-link to the right screen (booking id, chat id,
        etc.).  Always serialised to strings – FCM doesn't accept
        nested structures.
    push
        Opt-out knob for callers that only want the DB row (e.g.
        backend-triggered reconciliation jobs).
    """
    notif = Notification(
        user_id=user_id,
        title=title,
        body=body,
        type=notif_type,
    )
    db.add(notif)
    await db.flush()
    logger.info("notification_created", user_id=user_id, type=notif_type.value)

    if push:
        payload: dict[str, Any] = {"type": notif_type.value, "notif_id": notif.id}
        if data:
            payload.update(data)
        try:
            await push_to_user(
                db, user_id, title=title, body=body, data=payload
            )
        except Exception as exc:  # last-ditch safety net
            logger.warning("push_fallthrough_error", error=str(exc))

    return notif
