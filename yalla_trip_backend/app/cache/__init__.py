"""Cache layer — Redis client & helpers."""

from app.cache.redis_client import redis_client, redis_available

__all__ = ["redis_client", "redis_available"]
