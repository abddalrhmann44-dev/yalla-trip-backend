"""Health / readiness / liveness endpoints.

* ``/health``       – the classic single-shot check used by Docker, K8s
                      readiness probes, load balancers, etc.  Returns
                      HTTP 200 when every dependency is up, 503 when
                      any critical one (DB) is down.
* ``/health/live``  – liveness probe: only reports the process itself.
* ``/health/ready`` – alias of ``/health`` for K8s conventions.
"""

from __future__ import annotations

import time
from typing import Any

import structlog
from fastapi import APIRouter, Response, status
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from app.cache.redis_client import redis_client
from app.config import get_settings
from app.database import get_db
from fastapi import Depends

logger = structlog.get_logger(__name__)
router = APIRouter(tags=["Health"])
_settings = get_settings()

_APP_STARTED_AT = time.time()


async def _check_db(db: AsyncSession) -> dict[str, Any]:
    start = time.perf_counter()
    try:
        await db.execute(text("SELECT 1"))
        return {"ok": True, "latency_ms": _ms(start)}
    except Exception as exc:  # noqa: BLE001
        logger.warning("health_db_fail", error=str(exc))
        return {"ok": False, "error": str(exc)[:200]}


async def _check_redis() -> dict[str, Any]:
    start = time.perf_counter()
    try:
        pong = await redis_client.ping()
        return {"ok": bool(pong), "latency_ms": _ms(start)}
    except Exception as exc:  # noqa: BLE001
        return {"ok": False, "error": str(exc)[:200]}


def _check_s3() -> dict[str, Any]:
    """Verify S3 credentials look reasonable.  We don't actually touch
    the bucket here (that'd be slow + costs money); a real 'list' happens
    lazily on the first upload."""
    has_key = bool(_settings.AWS_ACCESS_KEY)
    has_secret = bool(_settings.AWS_SECRET_KEY)
    has_bucket = bool(_settings.AWS_BUCKET_NAME)
    return {
        "ok": has_key and has_secret and has_bucket,
        "bucket": _settings.AWS_BUCKET_NAME or None,
        "region": _settings.AWS_REGION or None,
    }


def _ms(start: float) -> float:
    return round((time.perf_counter() - start) * 1000, 2)


@router.get("/health")
@router.get("/health/ready")
async def health_check(response: Response, db: AsyncSession = Depends(get_db)):
    db_status = await _check_db(db)
    redis_status = await _check_redis()
    s3_status = _check_s3()

    critical_ok = db_status["ok"]  # DB is the only hard-fail dependency
    overall = "healthy" if critical_ok else "unhealthy"
    if not critical_ok:
        response.status_code = status.HTTP_503_SERVICE_UNAVAILABLE

    return {
        "status": overall,
        "service": "Talaa API",
        "version": "1.0.0",
        "env": _settings.APP_ENV,
        "environment": _settings.APP_ENV,
        "uptime_seconds": round(time.time() - _APP_STARTED_AT, 1),
        "dependencies": {
            "database": db_status,
            "redis": redis_status,
            "s3": s3_status,
        },
    }


@router.get("/health/live")
async def liveness():
    """Liveness only — the process is running and can answer HTTP."""
    return {"status": "alive", "uptime_seconds": round(time.time() - _APP_STARTED_AT, 1)}
