"""Generic brute-force / credential-stuffing guard.

Keyed by *identity* (e.g. phone number, email) rather than by IP, so
an attacker can't just rotate through proxies.  Uses Redis with a
rolling counter; falls back to an in-memory dict so the app still
protects itself when Redis is down.

Typical use — phone OTP verification:

```python
await assert_not_locked("otp", phone)     # raises HTTPException(429)
try:
    ...verify OTP...
except OtpError:
    await record_failure("otp", phone)
    raise
else:
    await clear_failures("otp", phone)
```

Design notes
------------
* **Scopes** partition counters so a phone's OTP failures don't
  lock their password-reset flow, etc.
* **Two Redis keys** per (scope, identity):
    - ``bfg:<scope>:<id>:fails``  → monotonic counter
    - ``bfg:<scope>:<id>:lock``   → "1" while locked; TTL = cool-down
* When ``fails`` hits ``MAX_FAILURES``, the guard sets ``lock`` with
  the configured cool-down and resets the counter.  Subsequent
  attempts hit the lock and receive ``Retry-After``.
* The failure counter auto-expires after ``WINDOW_SECONDS`` so a
  legitimate user mistyping twice over a day is never locked.
"""

from __future__ import annotations

import hashlib
import time
from dataclasses import dataclass
from typing import Final

import structlog
from fastapi import HTTPException, status

from app.cache.redis_client import redis_client

logger = structlog.get_logger(__name__)


# ── Tunables — small enough that a legit fat-finger user won't
#     notice, large enough to make online brute-force infeasible.
MAX_FAILURES: Final[int] = 5        # fails before lockout
WINDOW_SECONDS: Final[int] = 15 * 60  # counter TTL (15 min)
LOCK_SECONDS: Final[int] = 30 * 60  # how long the lock lasts (30 min)


# ── In-memory fallback when Redis is unreachable.
#     Maps (scope, id) → (fails, lock_until_epoch).
_mem: dict[tuple[str, str], tuple[int, float]] = {}


@dataclass(frozen=True)
class Lockout:
    """Describes an active lockout; used by the router layer."""

    retry_after: int  # seconds until the lock expires


def _hash_id(identity: str) -> str:
    """Hash the identity so Redis keys never contain raw phone numbers
    or emails — useful when Redis has replication to shared infra."""
    return hashlib.sha256(identity.encode("utf-8")).hexdigest()[:20]


def _keys(scope: str, identity: str) -> tuple[str, str]:
    h = _hash_id(identity.strip().lower())
    return f"bfg:{scope}:{h}:fails", f"bfg:{scope}:{h}:lock"


# ── Public API ────────────────────────────────────────────

async def check_locked(scope: str, identity: str) -> Lockout | None:
    """Return the active lockout for ``(scope, identity)`` or ``None``."""
    _, lock_key = _keys(scope, identity)

    # Try Redis first.
    try:
        ttl = await redis_client.ttl(lock_key)
        if ttl and ttl > 0:
            return Lockout(retry_after=int(ttl))
        if ttl == -1:  # key exists without TTL — repair it
            await redis_client.expire(lock_key, LOCK_SECONDS)
            return Lockout(retry_after=LOCK_SECONDS)
        return None
    except Exception as exc:  # noqa: BLE001
        logger.warning("bfg_redis_check_failed", error=str(exc))

    # Fallback to in-memory store.
    entry = _mem.get((scope, identity))
    if not entry:
        return None
    _, lock_until = entry
    if lock_until > time.time():
        return Lockout(retry_after=int(lock_until - time.time()))
    return None


async def assert_not_locked(scope: str, identity: str) -> None:
    """FastAPI-friendly guard — raises 429 with ``Retry-After`` header
    if the identity is currently locked out."""
    lock = await check_locked(scope, identity)
    if lock is None:
        return
    logger.info(
        "bfg_lockout_hit",
        scope=scope,
        retry_after=lock.retry_after,
    )
    raise HTTPException(
        status_code=status.HTTP_429_TOO_MANY_REQUESTS,
        detail=(
            "تم قفل المحاولات مؤقتاً بسبب محاولات غلط كثيرة — "
            f"حاول بعد {lock.retry_after // 60} دقيقة. / "
            "Too many failed attempts — try again later."
        ),
        headers={"Retry-After": str(lock.retry_after)},
    )


async def record_failure(scope: str, identity: str) -> int:
    """Increment the failure counter.  Returns the new count.  When
    the count reaches ``MAX_FAILURES`` the identity is locked out."""
    fails_key, lock_key = _keys(scope, identity)

    try:
        pipe = redis_client.pipeline()
        pipe.incr(fails_key)
        pipe.expire(fails_key, WINDOW_SECONDS)
        count, _ = await pipe.execute()
        count = int(count)
        if count >= MAX_FAILURES:
            await redis_client.set(lock_key, "1", ex=LOCK_SECONDS)
            await redis_client.delete(fails_key)
            logger.warning("bfg_locked_out", scope=scope, count=count)
        return count
    except Exception as exc:  # noqa: BLE001
        logger.warning("bfg_redis_record_failed", error=str(exc))

    # In-memory fallback.
    now = time.time()
    fails, lock_until = _mem.get((scope, identity), (0, 0.0))
    # Reset counter when the window has rolled over.
    fails = fails + 1 if (now - lock_until < WINDOW_SECONDS) else 1
    if fails >= MAX_FAILURES:
        _mem[(scope, identity)] = (0, now + LOCK_SECONDS)
        logger.warning("bfg_locked_out_mem", scope=scope)
    else:
        _mem[(scope, identity)] = (fails, now)
    return fails


async def clear_failures(scope: str, identity: str) -> None:
    """Call on a successful attempt — wipes the counter and the lock."""
    fails_key, lock_key = _keys(scope, identity)
    try:
        await redis_client.delete(fails_key, lock_key)
    except Exception as exc:  # noqa: BLE001
        logger.warning("bfg_redis_clear_failed", error=str(exc))
    _mem.pop((scope, identity), None)
