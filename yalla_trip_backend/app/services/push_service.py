"""FCM push notifications using Firebase Admin SDK.

The legacy FCM HTTP API is deprecated since June 2024.  We use the
HTTP v1 API through ``firebase_admin.messaging`` which is already
initialised in :pymod:`app.services.firebase_service`.

Flow
----
1. Caller provides a ``user_id`` and a payload.
2. We load all of the user's registered ``DeviceToken`` rows.
3. ``messaging.send_each_for_multicast`` sends one message to every
   device in a single HTTP call.
4. Invalid / unregistered tokens are pruned from the DB so we don't
   keep hitting them forever.
"""

from __future__ import annotations

from typing import Any, Iterable

import structlog
from sqlalchemy import delete, select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.device_token import DeviceToken
from app.services.firebase_service import ensure_initialized

logger = structlog.get_logger(__name__)


async def push_to_user(
    db: AsyncSession,
    user_id: int,
    *,
    title: str,
    body: str,
    data: dict[str, Any] | None = None,
) -> int:
    """Send a push to every registered device for ``user_id``.

    Returns the number of successful deliveries (0 if Firebase is not
    configured or the user has no devices).  Never raises – push is
    best-effort, the caller shouldn't care.
    """
    tokens = (
        await db.execute(
            select(DeviceToken.id, DeviceToken.token).where(
                DeviceToken.user_id == user_id
            )
        )
    ).all()
    if not tokens:
        return 0

    if not ensure_initialized():
        logger.debug("fcm_skipped_no_firebase")
        return 0

    from firebase_admin import messaging  # lazy import, optional dep

    # Only strings are allowed in the data payload.
    payload = {
        str(k): str(v)
        for k, v in (data or {}).items()
        if v is not None
    }

    token_values = [t for _, t in tokens]
    message = messaging.MulticastMessage(
        tokens=token_values,
        notification=messaging.Notification(title=title, body=body),
        data=payload,
        android=messaging.AndroidConfig(
            priority="high",
            notification=messaging.AndroidNotification(
                sound="default",
                # Matches ``_androidChannel.id`` in lib/services/notification_service.dart
                channel_id="talaa_channel",
            ),
        ),
        apns=messaging.APNSConfig(
            payload=messaging.APNSPayload(
                aps=messaging.Aps(sound="default", badge=1),
            ),
        ),
    )

    try:
        response = messaging.send_each_for_multicast(message)
    except Exception as exc:  # network or credential error
        logger.warning("fcm_multicast_error", error=str(exc))
        return 0

    # Clean up tokens the server rejected so we don't keep spamming
    # them.  ``InvalidRegistration`` / ``Unregistered`` are the common
    # terminal errors.
    stale_ids: list[int] = []
    success = 0
    for (row_id, _), resp in zip(tokens, response.responses):
        if resp.success:
            success += 1
        elif resp.exception is not None:
            code = getattr(resp.exception, "code", "")
            if code in {"UNREGISTERED", "INVALID_ARGUMENT", "SENDER_ID_MISMATCH"}:
                stale_ids.append(row_id)

    if stale_ids:
        await db.execute(
            delete(DeviceToken).where(DeviceToken.id.in_(stale_ids))
        )
        logger.info("fcm_pruned_stale_tokens", count=len(stale_ids))

    # Bump ``last_seen_at`` for successful devices so we can later
    # drop truly dead ones (e.g. not seen for > 6 months).
    if success:
        successful_ids = [
            row_id
            for (row_id, _), resp in zip(tokens, response.responses)
            if resp.success
        ]
        await db.execute(
            update(DeviceToken)
            .where(DeviceToken.id.in_(successful_ids))
            .values(last_seen_at=__import__("datetime").datetime.now(
                __import__("datetime").timezone.utc
            ))
        )

    logger.info(
        "fcm_multicast_sent",
        user_id=user_id,
        success=success,
        failed=len(tokens) - success,
    )
    return success


async def push_to_users(
    db: AsyncSession,
    user_ids: Iterable[int],
    *,
    title: str,
    body: str,
    data: dict[str, Any] | None = None,
) -> int:
    """Convenience wrapper – send the same message to several users."""
    total = 0
    for uid in user_ids:
        total += await push_to_user(
            db, uid, title=title, body=body, data=data
        )
    return total
