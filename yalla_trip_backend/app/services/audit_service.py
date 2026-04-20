"""Audit-log helpers.

Usage inside a route::

    from app.services.audit_service import log_action

    @router.post(...)
    async def admin_suspend_user(
        user_id: int,
        request: Request,
        admin: User = Depends(require_role(UserRole.admin)),
        db: AsyncSession = Depends(get_db),
    ):
        target = await db.get(User, user_id)
        before = {"is_active": target.is_active}
        target.is_active = False
        await log_action(
            db, request=request, actor=admin,
            action="user.suspend",
            target_type="user", target_id=user_id,
            before=before, after={"is_active": False},
        )
"""

from __future__ import annotations

from typing import Any

import structlog
from fastapi import Request
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.audit_log import AuditLogEntry
from app.models.user import User

logger = structlog.get_logger(__name__)


_SENSITIVE_KEYS = {
    "password", "password_hash", "token", "refresh_token",
    "firebase_uid", "fcm_token", "secret", "api_key",
    "authorization", "access_token",
}


def _scrub(value: Any) -> Any:
    """Recursively remove secrets from a value before persisting.

    We keep the shape so the diff still reads naturally, but any
    ``secret`` fields get replaced with ``"***"``.
    """
    if isinstance(value, dict):
        return {
            k: ("***" if k.lower() in _SENSITIVE_KEYS else _scrub(v))
            for k, v in value.items()
        }
    if isinstance(value, (list, tuple)):
        return [_scrub(v) for v in value]
    return value


async def log_action(
    db: AsyncSession,
    *,
    request: Request | None,
    actor: User | None,
    action: str,
    target_type: str | None = None,
    target_id: int | None = None,
    before: dict | None = None,
    after: dict | None = None,
) -> AuditLogEntry:
    """Persist one audit entry.

    * ``actor`` may be ``None`` for system-triggered actions (cron /
      webhook handlers).  In that case we log ``actor_email='system'``.
    * The DB write is flushed but **not** committed – it rides inside
      the caller's transaction so the action + its audit row either
      both succeed or both roll back.
    """
    ip = None
    ua = None
    rid = None
    if request is not None:
        client = request.client
        ip = (
            request.headers.get("x-forwarded-for", "").split(",")[0].strip()
            or (client.host if client else None)
        )
        ua = request.headers.get("user-agent")
        rid = request.headers.get("x-request-id") or getattr(
            request.state, "request_id", None
        )

    entry = AuditLogEntry(
        actor_id=actor.id if actor else None,
        actor_email=(actor.email if actor else "system"),
        actor_role=(actor.role.value if actor and actor.role else None),
        action=action,
        target_type=target_type,
        target_id=target_id,
        before=_scrub(before) if before is not None else None,
        after=_scrub(after) if after is not None else None,
        ip_address=ip,
        user_agent=ua[:500] if ua else None,
        request_id=rid,
    )
    db.add(entry)
    try:
        await db.flush()
    except Exception as exc:      # pragma: no cover – audit must never
        # A broken audit write must not take down the actual action –
        # the logger output still provides an out-of-band breadcrumb.
        logger.error(
            "audit_log_write_failed",
            action=action, target_type=target_type,
            target_id=target_id, error=str(exc),
        )
        return entry

    logger.info(
        "audit",
        action=action,
        actor=entry.actor_email,
        target_type=target_type,
        target_id=target_id,
    )
    return entry
