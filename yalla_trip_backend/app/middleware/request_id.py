"""Request-ID + access-log middleware.

Generates / propagates ``X-Request-ID`` and binds structlog context so
every log line emitted during the request automatically carries the
same request id.  Also produces one structured access log per request
with method, path, status, latency, and client info.
"""

from __future__ import annotations

import time
import uuid
from typing import Callable

import structlog
from fastapi import Request
from starlette.types import ASGIApp

logger = structlog.get_logger("http")

_HEADER = "x-request-id"


async def request_id_middleware(request: Request, call_next: Callable):
    request_id = request.headers.get(_HEADER) or uuid.uuid4().hex
    structlog.contextvars.clear_contextvars()
    structlog.contextvars.bind_contextvars(
        request_id=request_id,
        method=request.method,
        path=request.url.path,
        client=request.client.host if request.client else "unknown",
    )
    start = time.perf_counter()
    status_code = 500
    try:
        response = await call_next(request)
        status_code = response.status_code
        response.headers[_HEADER] = request_id
        return response
    finally:
        duration_ms = round((time.perf_counter() - start) * 1000, 2)
        # Success is logged at info; 4xx at warning; 5xx at error.
        if status_code >= 500:
            log = logger.error
        elif status_code >= 400:
            log = logger.warning
        else:
            log = logger.info
        log(
            "http_request",
            status=status_code,
            duration_ms=duration_ms,
        )
        structlog.contextvars.clear_contextvars()


def register(app: ASGIApp) -> None:
    app.middleware("http")(request_id_middleware)  # type: ignore[attr-defined]
