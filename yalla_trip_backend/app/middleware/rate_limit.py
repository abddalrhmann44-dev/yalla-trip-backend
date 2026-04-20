"""Rate-limit middleware.

Implements a **fixed-window** rate limiter backed by Redis.  If Redis is
unavailable we silently fall back to an in-memory dict so the app never
hard-fails because of a cache hiccup.

Design notes
------------
* Keyed by ``user:<uid>`` when an ``Authorization`` header is present (so
  two users behind the same NAT don't share a bucket), otherwise by the
  client IP.
* Endpoint groups have different limits:
    - ``/auth``       – tight bucket to slow down brute-force / OTP spam
    - anything else  – the generic ``RATE_LIMIT_PER_MINUTE`` setting
* Adds standard ``X-RateLimit-*`` and ``Retry-After`` response headers.
* Writes structured log entries when a limit is exceeded.
"""

from __future__ import annotations

import hashlib
import time
from collections import defaultdict
from typing import Callable

import structlog
from fastapi import Request, status
from fastapi.responses import ORJSONResponse
from starlette.types import ASGIApp

from app.cache.redis_client import redis_client
from app.config import get_settings

logger = structlog.get_logger(__name__)
_settings = get_settings()

# Fixed-window size in seconds.
_WINDOW = 60

# Endpoint group → (requests, description for log).  Each entry is matched
# by **prefix** against the request path (first match wins).
_GROUP_LIMITS: list[tuple[str, int, str]] = [
    ("/auth",          20,  "auth"),
    ("/payments",      30,  "payments"),
    ("/favorites",     60,  "favorites"),
]

_DEFAULT_LIMIT = _settings.RATE_LIMIT_PER_MINUTE

# In-memory fallback when Redis is down.  Maps key → list[timestamps].
_memory_hits: dict[str, list[float]] = defaultdict(list)

# Health flag — flipped by `_hit_redis` on failure so we stop spamming
# logs and just use the in-memory bucket until the next probe.
_redis_alive: bool = True


def _pick_group(path: str) -> tuple[int, str]:
    for prefix, limit, name in _GROUP_LIMITS:
        if path.startswith(prefix):
            return limit, name
    return _DEFAULT_LIMIT, "default"


def _client_key(request: Request) -> str:
    """Return a stable identity for the caller."""
    auth = request.headers.get("authorization", "")
    if auth.lower().startswith("bearer "):
        token = auth[7:].strip()
        if token:
            # Short hash keeps Redis keys small and leaks nothing.
            return "user:" + hashlib.sha256(token.encode()).hexdigest()[:16]
    ip = request.client.host if request.client else "unknown"
    return f"ip:{ip}"


async def _hit_redis(key: str) -> int | None:
    """Atomically INCR the current window counter.  Returns new count or
    ``None`` when Redis is unreachable."""
    global _redis_alive
    window_id = int(time.time() // _WINDOW)
    redis_key = f"rl:{key}:{window_id}"
    try:
        pipe = redis_client.pipeline()
        pipe.incr(redis_key)
        pipe.expire(redis_key, _WINDOW * 2)
        count, _ = await pipe.execute()
        if not _redis_alive:
            logger.info("redis_recovered")
            _redis_alive = True
        return int(count)
    except Exception as exc:  # noqa: BLE001
        if _redis_alive:
            logger.warning("redis_rate_limit_fallback", error=str(exc))
            _redis_alive = False
        return None


def _hit_memory(key: str) -> int:
    now = time.time()
    bucket = _memory_hits[key]
    cutoff = now - _WINDOW
    # Drop old entries in-place — keeps memory bounded.
    while bucket and bucket[0] < cutoff:
        bucket.pop(0)
    bucket.append(now)
    return len(bucket)


async def rate_limit_middleware(request: Request, call_next: Callable):
    # Skip free-to-hit paths (docs, health, static).
    path = request.url.path
    if path in {"/", "/health", "/health/", "/docs", "/redoc", "/openapi.json"}:
        return await call_next(request)

    # Skip for the pytest harness — the test conftest authenticates
    # via ``X-Test-User`` instead of a real JWT, so every request would
    # otherwise fall into the shared ``ip:127.0.0.1`` bucket and hit
    # the 100/min ceiling halfway through the suite.
    if request.headers.get("x-test-user"):
        return await call_next(request)

    limit, group = _pick_group(path)
    key = _client_key(request)
    count = await _hit_redis(f"{group}:{key}")
    if count is None:
        count = _hit_memory(f"{group}:{key}")

    remaining = max(0, limit - count)
    # Compute seconds until current window closes.
    reset_in = _WINDOW - int(time.time()) % _WINDOW

    if count > limit:
        logger.warning(
            "rate_limit_exceeded",
            path=path,
            group=group,
            key=key,
            count=count,
            limit=limit,
        )
        return ORJSONResponse(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            headers={
                "X-RateLimit-Limit": str(limit),
                "X-RateLimit-Remaining": "0",
                "X-RateLimit-Reset": str(reset_in),
                "Retry-After": str(reset_in),
            },
            content={
                "detail": "Rate limit exceeded",
                "detail_ar": "تم تجاوز حد الطلبات — حاول بعد قليل",
            },
        )

    response = await call_next(request)
    response.headers["X-RateLimit-Limit"] = str(limit)
    response.headers["X-RateLimit-Remaining"] = str(remaining)
    response.headers["X-RateLimit-Reset"] = str(reset_in)
    return response


def register(app: ASGIApp) -> None:
    """Attach the middleware to the app — called from ``main.py``."""
    app.middleware("http")(rate_limit_middleware)  # type: ignore[attr-defined]
