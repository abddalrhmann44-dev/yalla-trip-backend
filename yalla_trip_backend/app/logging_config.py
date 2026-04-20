"""Centralised structlog configuration.

Production emits **one-line JSON** per log entry so any log aggregator
(Loki, CloudWatch, Datadog, Sentry breadcrumbs, etc.) can parse it
without regex gymnastics.  Development keeps the pretty console output
so humans can still read the stream in `docker compose logs`.

Every log line automatically gets the fields bound by the
``RequestIDMiddleware`` (see ``app.middleware.request_id``) thanks to
``structlog.contextvars.merge_contextvars``.
"""

from __future__ import annotations

import logging
import sys

import structlog

from app.config import get_settings

_settings = get_settings()


def configure_logging() -> None:
    """Configure the root logger + structlog.

    Idempotent — safe to call multiple times (e.g. under uvicorn
    reload).  Removes any previously-installed handlers so we never end
    up with duplicated lines.
    """

    is_prod = _settings.APP_ENV != "development"
    level = logging.INFO if is_prod else logging.DEBUG

    # ── Base stdlib logging ────────────────────────────────
    root = logging.getLogger()
    root.handlers.clear()
    handler = logging.StreamHandler(sys.stdout)
    handler.setFormatter(logging.Formatter("%(message)s"))
    root.addHandler(handler)
    root.setLevel(level)

    # Tone down noisy libraries.
    for noisy in ("uvicorn.access", "botocore", "urllib3"):
        logging.getLogger(noisy).setLevel(logging.WARNING)

    # ── structlog processor chain ─────────────────────────
    shared_processors: list = [
        structlog.contextvars.merge_contextvars,
        structlog.processors.add_log_level,
        structlog.processors.TimeStamper(fmt="iso", utc=True),
        structlog.processors.StackInfoRenderer(),
    ]

    if is_prod:
        renderer = structlog.processors.JSONRenderer()
    else:
        renderer = structlog.dev.ConsoleRenderer(colors=True)

    structlog.configure(
        processors=[
            *shared_processors,
            structlog.processors.format_exc_info,
            renderer,
        ],
        wrapper_class=structlog.make_filtering_bound_logger(level),
        context_class=dict,
        logger_factory=structlog.stdlib.LoggerFactory(),
        cache_logger_on_first_use=True,
    )
