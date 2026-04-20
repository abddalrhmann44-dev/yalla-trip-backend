"""Async Redis client — singleton with graceful degradation.

Never crash the app if Redis is unreachable — fall back to in-memory
behaviour in the callers.
"""

from __future__ import annotations

import structlog
from redis.asyncio import Redis, from_url

from app.config import get_settings

logger = structlog.get_logger(__name__)
_settings = get_settings()

# Singleton client. Decode responses so we always get `str` back.
redis_client: Redis = from_url(
    _settings.REDIS_URL,
    encoding="utf-8",
    decode_responses=True,
    health_check_interval=30,
    socket_connect_timeout=2,
    socket_timeout=2,
    retry_on_timeout=True,
)


async def redis_available() -> bool:
    """Cheap PING — returns False if Redis is down (never raises)."""
    try:
        return bool(await redis_client.ping())
    except Exception as exc:  # noqa: BLE001
        logger.warning("redis_unavailable", error=str(exc))
        return False
