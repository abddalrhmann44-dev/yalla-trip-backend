"""Resolve provider string → concrete gateway singleton."""

from __future__ import annotations

from functools import lru_cache

from app.models.payment import PaymentProvider
from app.services.gateways.base import PaymentGateway
from app.services.gateways.cod import CODGateway
from app.services.gateways.fawry import FawryGateway
from app.services.gateways.paymob import PaymobGateway


@lru_cache(maxsize=None)
def _instances() -> dict[PaymentProvider, PaymentGateway]:
    return {
        PaymentProvider.fawry: FawryGateway(),
        PaymentProvider.paymob: PaymobGateway(),
        PaymentProvider.cod: CODGateway(),
    }


def get_gateway(provider: PaymentProvider) -> PaymentGateway:
    return _instances()[provider]
