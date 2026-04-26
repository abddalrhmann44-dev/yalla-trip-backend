"""Security-headers middleware tests.

Asserts the baseline hardened response headers are attached to every
response, and that the production-only safety gate in ``app.config``
rejects insecure defaults.
"""

from __future__ import annotations

import os

import pytest
from httpx import AsyncClient

from app.config import Settings


# ── Response headers ───────────────────────────────────────


@pytest.mark.asyncio
async def test_security_headers_present_on_every_response(
    guest_client: AsyncClient,
):
    resp = await guest_client.get("/health")
    assert resp.status_code == 200

    # Core set — always on regardless of APP_ENV.
    assert resp.headers.get("x-content-type-options") == "nosniff"
    assert resp.headers.get("x-frame-options") == "DENY"
    assert resp.headers.get("referrer-policy") == (
        "strict-origin-when-cross-origin"
    )
    assert "camera=()" in (resp.headers.get("permissions-policy") or "")
    assert resp.headers.get("x-permitted-cross-domain-policies") == "none"


@pytest.mark.asyncio
async def test_hsts_only_in_production(guest_client: AsyncClient):
    """In tests ``APP_ENV`` defaults to ``development`` so HSTS stays off."""
    resp = await guest_client.get("/health")
    assert "strict-transport-security" not in {
        k.lower() for k in resp.headers.keys()
    }


# ── Production-safety gate ─────────────────────────────────


def _prod_env(**overrides: str) -> dict[str, str]:
    base = {
        "APP_ENV": "production",
        "DEBUG": "false",
        "SECRET_KEY": "a" * 48,
        "ALLOWED_ORIGINS": '["https://talaa.app"]',
        "ALLOW_UNVERIFIED_WALLET_TOPUP": "false",
    }
    base.update(overrides)
    return base


def _build_settings(env: dict[str, str]) -> None:
    """Instantiate Settings with the given env vars patched in."""
    original = {k: os.environ.get(k) for k in env}
    try:
        for k, v in env.items():
            os.environ[k] = v
        Settings()  # construction itself raises
    finally:
        for k, v in original.items():
            if v is None:
                os.environ.pop(k, None)
            else:
                os.environ[k] = v


def test_production_rejects_default_secret_key():
    env = _prod_env(SECRET_KEY="change-me")
    with pytest.raises(ValueError, match="SECRET_KEY"):
        _build_settings(env)


def test_production_rejects_short_secret_key():
    env = _prod_env(SECRET_KEY="short")
    with pytest.raises(ValueError, match="SECRET_KEY"):
        _build_settings(env)


def test_production_rejects_wildcard_cors():
    env = _prod_env(ALLOWED_ORIGINS='["*"]')
    with pytest.raises(ValueError, match="ALLOWED_ORIGINS"):
        _build_settings(env)


def test_production_rejects_debug_true():
    env = _prod_env(DEBUG="true")
    with pytest.raises(ValueError, match="DEBUG"):
        _build_settings(env)


def test_production_rejects_unverified_wallet_topup():
    env = _prod_env(ALLOW_UNVERIFIED_WALLET_TOPUP="true")
    with pytest.raises(ValueError, match="ALLOW_UNVERIFIED_WALLET_TOPUP"):
        _build_settings(env)


def test_production_accepts_proper_config():
    # Should not raise.
    _build_settings(_prod_env())
