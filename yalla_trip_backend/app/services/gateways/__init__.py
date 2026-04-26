"""Pluggable payment-gateway implementations."""

from app.services.gateways.base import (
    GatewayError,
    InitiateResult,
    PaymentGateway,
    WebhookResult,
)
from app.services.gateways.fawry import FawryGateway
from app.services.gateways.paymob import PaymobGateway
from app.services.gateways.cod import CODGateway
from app.services.gateways.mock import MockGateway
from app.services.gateways.registry import get_gateway

__all__ = [
    "GatewayError",
    "InitiateResult",
    "PaymentGateway",
    "WebhookResult",
    "FawryGateway",
    "PaymobGateway",
    "CODGateway",
    "MockGateway",
    "get_gateway",
]
