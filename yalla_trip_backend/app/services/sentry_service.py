"""Sentry error-reporting integration.

When ``SENTRY_DSN`` is empty (dev / CI / tests) this module is a
silent no-op.  When set, unhandled exceptions reach Sentry tagged with
the request path, method and – if available – the authenticated
``user_id`` so we can slice by host in production.
"""

from __future__ import annotations

from typing import Any

import structlog

from app.config import get_settings

logger = structlog.get_logger(__name__)
settings = get_settings()

_initialized = False


def init_sentry() -> bool:
    """Initialise the Sentry SDK on first call.

    Returns ``True`` if Sentry was enabled, ``False`` otherwise.  The
    FastAPI/Starlette integrations are installed so we automatically
    capture request context (but never request bodies, to keep PII
    out of reports).
    """
    global _initialized
    if _initialized:
        return True
    if not settings.SENTRY_DSN:
        logger.debug("sentry_skipped_no_dsn")
        return False

    try:
        import sentry_sdk
        from sentry_sdk.integrations.asyncio import AsyncioIntegration
        from sentry_sdk.integrations.fastapi import FastApiIntegration
        from sentry_sdk.integrations.sqlalchemy import SqlalchemyIntegration
        from sentry_sdk.integrations.starlette import StarletteIntegration
    except ImportError as exc:
        logger.warning("sentry_import_error", error=str(exc))
        return False

    sentry_sdk.init(
        dsn=settings.SENTRY_DSN,
        environment=settings.APP_ENV,
        release=settings.SENTRY_RELEASE or None,
        traces_sample_rate=settings.SENTRY_TRACES_SAMPLE_RATE,
        # We deliberately don't send request bodies – bookings / chat
        # messages may contain personal data.  Request metadata
        # (path, method, query string minus secrets) is still captured.
        send_default_pii=False,
        max_breadcrumbs=50,
        integrations=[
            FastApiIntegration(transaction_style="endpoint"),
            StarletteIntegration(transaction_style="endpoint"),
            SqlalchemyIntegration(),
            AsyncioIntegration(),
        ],
        before_send=_scrub_sensitive,
    )
    _initialized = True
    logger.info("sentry_initialized", env=settings.APP_ENV)
    return True


# ══════════════════════════════════════════════════════════════
#  Helpers
# ══════════════════════════════════════════════════════════════
_SENSITIVE_KEYS = {
    "authorization", "cookie", "set-cookie", "password",
    "token", "fcm_token", "secret", "api_key",
    "id_token", "refresh_token",
}


def _scrub_sensitive(event: dict[str, Any], hint: dict[str, Any]):
    """Strip credentials from the outgoing Sentry payload.

    ``sentry_sdk`` already redacts common headers when ``send_default_pii``
    is off, but we defence-in-depth the request body / extras too.
    """
    try:
        request = event.get("request") or {}
        for key in ("headers", "cookies"):
            bag = request.get(key)
            if isinstance(bag, dict):
                for k in list(bag.keys()):
                    if k.lower() in _SENSITIVE_KEYS:
                        bag[k] = "[REDACTED]"
        # Strip sensitive fields from arbitrary extras too.
        for section in ("extra", "contexts"):
            data = event.get(section) or {}
            _scrub_dict(data)
    except Exception:
        # Scrubbing must never itself raise – we'd rather over-send than
        # drop the whole event.
        pass
    return event


def _scrub_dict(d: Any) -> None:
    if isinstance(d, dict):
        for k in list(d.keys()):
            if isinstance(k, str) and k.lower() in _SENSITIVE_KEYS:
                d[k] = "[REDACTED]"
            else:
                _scrub_dict(d[k])
    elif isinstance(d, list):
        for item in d:
            _scrub_dict(item)


def set_user_tag(user_id: int | None, role: str | None = None) -> None:
    """Attach the authenticated user to the current Sentry scope."""
    if not _initialized:
        return
    try:
        import sentry_sdk
        sentry_sdk.set_user(
            {"id": str(user_id) if user_id else None}
        )
        if role:
            sentry_sdk.set_tag("user.role", role)
    except Exception:
        pass


def capture_exception(exc: BaseException, **tags: Any) -> None:
    """Manually report an exception with extra tags.

    Handy for swallowed errors in background tasks where the automatic
    middleware capture doesn't reach.
    """
    if not _initialized:
        return
    try:
        import sentry_sdk
        with sentry_sdk.push_scope() as scope:
            for k, v in tags.items():
                scope.set_tag(k, v)
            sentry_sdk.capture_exception(exc)
    except Exception:
        pass
