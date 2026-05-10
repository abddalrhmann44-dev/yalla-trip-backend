"""Helpers around partner ``ApiKey`` rows.

Centralises the crypto so the admin router and any future
authentication middleware speak the same language about how keys
are minted, hashed, and looked up.

Threat model:

- Plaintext is shown to the admin **once** at creation time.  We
  never persist it.  The DB only has the SHA-256 hash plus the
  first 8 characters (prefix) for human identification.
- Lookups are O(1) because we hash the incoming header value and
  compare it to ``key_hash``.  No row enumeration.
- Rotation is "create new + revoke old" — we do not provide an
  in-place rotate to keep the audit trail clean.
"""

from __future__ import annotations

import hashlib
import secrets
from typing import Final

# Canonical scopes a key can request.  Keep this list small and
# explicit — the admin UI exposes them as checkboxes.
ALLOWED_SCOPES: Final[tuple[str, ...]] = (
    "properties.read",
    "properties.write",
    "bookings.read",
    "bookings.write",
    "users.read",
    "analytics.read",
    "webhooks.send",
)

# Plaintext keys carry a short prefix so the admin can tell them
# apart at a glance (e.g. ``ttk_live_…`` vs ``ttk_test_…`` for a
# future test mode).
_PLAINTEXT_PREFIX = "ttk_live_"
# 32 random URL-safe bytes ~= 43 base64 chars; combined with the
# fixed prefix that keeps the displayed key under 60 chars.
_RANDOM_BYTES = 32


def _hash(plaintext: str) -> str:
    """Return the canonical SHA-256 hex digest of a plaintext key."""
    return hashlib.sha256(plaintext.encode("utf-8")).hexdigest()


def mint_new_key() -> tuple[str, str, str]:
    """Generate a fresh plaintext key.

    Returns a tuple of ``(plaintext, key_prefix, key_hash)``.  Only
    the plaintext should ever leave the server (and only once, in
    the response of the create endpoint).
    """
    plaintext = _PLAINTEXT_PREFIX + secrets.token_urlsafe(_RANDOM_BYTES)
    # First 12 chars = "ttk_live_" + 3 random.  Long enough to be
    # human-readable, short enough that it can never disambiguate
    # two distinct full keys in practice.
    prefix = plaintext[:12]
    return plaintext, prefix, _hash(plaintext)


def hash_for_lookup(plaintext: str) -> str:
    """Hash an incoming plaintext for constant-time DB comparison."""
    return _hash(plaintext)


def validate_scopes(scopes: list[str]) -> list[str]:
    """Filter to only the canonical scopes; drop unknown values."""
    return [s for s in scopes if s in ALLOWED_SCOPES]
