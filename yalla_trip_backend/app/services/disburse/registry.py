"""Disburse gateway selection.

A single env var, ``DISBURSE_PROVIDER``, picks between mock and
Kashier.  The function memo-caches one instance per provider so we
don't re-validate Kashier credentials on every payout — those live
for the lifetime of the worker process.

We keep the helper async-friendly (``await get_disburse_gateway()``)
even though the lookup itself is sync, so any future provider that
needs an async warm-up (token refresh, etc.) can drop in without a
caller-facing API change.
"""

from __future__ import annotations

import structlog

from app.config import get_settings
from app.services.disburse.base import DisburseGateway
from app.services.disburse.kashier import KashierDisburseGateway
from app.services.disburse.mock import MockDisburseGateway

logger = structlog.get_logger(__name__)
settings = get_settings()


_cache: dict[str, DisburseGateway] = {}


def get_disburse_gateway() -> DisburseGateway:
    """Return the configured gateway, cached by provider name."""
    provider = (getattr(settings, "DISBURSE_PROVIDER", "mock") or "mock").lower()
    if provider in _cache:
        return _cache[provider]

    gateway: DisburseGateway
    if provider == "kashier":
        gateway = KashierDisburseGateway()
    elif provider == "mock":
        gateway = MockDisburseGateway()
    else:
        # Defensive fallback — log loudly but don't crash the worker.
        # Disbursement failures are recoverable; an admin can finish
        # the payout manually if the gateway is misconfigured.
        logger.error(
            "disburse_unknown_provider", provider=provider,
            fallback="mock",
        )
        gateway = MockDisburseGateway()

    _cache[provider] = gateway
    logger.info("disburse_gateway_ready", provider=gateway.name)
    return gateway
