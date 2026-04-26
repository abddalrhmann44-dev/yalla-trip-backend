"""Redact sensitive values from log entries.

Installed as a structlog processor so every log line — whether it
comes from our own code, from a 3rd-party library using the stdlib
``logging`` module bridged into structlog, or from Sentry's
breadcrumbs — runs through the same scrub.

What we mask
------------
* JWT-shaped strings anywhere in the payload (``eyJ…`` three-segment
  base64url tokens).
* Any key whose **name** looks sensitive — ``authorization``,
  ``password``, ``token``, ``secret``, ``api_key``, ``cookie``,
  ``refresh_token``, ``access_token``, ``id_token``, ``fcm_token``,
  ``firebase_credentials_json``, ``card_number``, ``cvv``, ``pan``.

For dict / list values we recurse up to a reasonable depth so nested
structures like ``request={"headers": {"authorization": "Bearer …"}}``
get cleaned.

The masker is *cheap* — a tight regex on strings + a set membership
check on keys — so it's safe to run on every log entry.
"""

from __future__ import annotations

import re
from typing import Any

# ── Sensitive key names (case-insensitive match).
_SENSITIVE_KEYS: frozenset[str] = frozenset(
    {
        "authorization",
        "cookie",
        "password",
        "passwd",
        "pwd",
        "token",
        "access_token",
        "refresh_token",
        "id_token",
        "fcm_token",
        "auth_token",
        "secret",
        "secret_key",
        "api_key",
        "apikey",
        "firebase_credentials_json",
        "fb_token",
        "firebase_token",
        # PCI.
        "card_number",
        "cc",
        "pan",
        "cvv",
        "cvc",
        "cvv2",
        "security_code",
    }
)

# ── JWT-shaped pattern: three base64url-safe segments separated by
#     dots.  Length bounds keep false positives down (a random CUID
#     like "abc.def.ghi" won't match).
_JWT_RE = re.compile(r"\beyJ[a-zA-Z0-9_-]{8,}\.[a-zA-Z0-9_-]{8,}\.[a-zA-Z0-9_-]{8,}\b")

# ── Bearer-token pattern: "Bearer <anything non-whitespace>".
_BEARER_RE = re.compile(r"(?i)(bearer\s+)\S+")

_REDACTED = "«redacted»"
_MAX_DEPTH = 6


def _scrub_value(value: Any, depth: int = 0) -> Any:
    if depth > _MAX_DEPTH:
        return value
    if isinstance(value, str):
        s = _JWT_RE.sub(_REDACTED, value)
        s = _BEARER_RE.sub(r"\1" + _REDACTED, s)
        return s
    if isinstance(value, dict):
        return {k: _scrub_pair(k, v, depth + 1) for k, v in value.items()}
    if isinstance(value, (list, tuple)):
        cleaned = [_scrub_value(v, depth + 1) for v in value]
        return type(value)(cleaned)
    return value


def _scrub_pair(key: Any, value: Any, depth: int) -> Any:
    if isinstance(key, str) and key.lower() in _SENSITIVE_KEYS:
        return _REDACTED
    return _scrub_value(value, depth)


def redact_processor(_, __, event_dict: dict) -> dict:
    """structlog processor — scrubs the whole event dict in place."""
    return {k: _scrub_pair(k, v, 0) for k, v in event_dict.items()}
