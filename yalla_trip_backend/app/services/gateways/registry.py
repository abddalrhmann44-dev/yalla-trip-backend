"""Resolve provider string → concrete gateway singleton.

When ``PAYMENTS_MOCK_MODE`` is on (no real gateway contract yet) every
provider transparently swaps to :class:`MockGateway` so the rest of
the system — router, webhook handler, escrow ledger, status polling,
Flutter UI — exercises the real code paths against fake money.
Toggling the flag back to off is a one-line ops change; no Flutter
release is required.
"""

from __future__ import annotations

from functools import lru_cache

from app.config import get_settings
from app.models.payment import PaymentProvider
from app.services.gateways.base import PaymentGateway
from app.services.gateways.cod import CODGateway
from app.services.gateways.fawry import FawryGateway
from app.services.gateways.mock import MockGateway
from app.services.gateways.paymob import PaymobGateway


@lru_cache(maxsize=None)
def _real_instances() -> dict[PaymentProvider, PaymentGateway]:
    return {
        PaymentProvider.fawry: FawryGateway(),
        PaymentProvider.paymob: PaymobGateway(),
        PaymentProvider.cod: CODGateway(),
    }


@lru_cache(maxsize=1)
def _mock_instance() -> MockGateway:
    return MockGateway()


def get_gateway(provider: PaymentProvider) -> PaymentGateway:
    if get_settings().PAYMENTS_MOCK_MODE and provider != PaymentProvider.cod:
        # COD is already a no-op gateway with no external dependency,
        # so we leave it alone — there's nothing to mock.
        return _mock_instance()
    return _real_instances()[provider]
