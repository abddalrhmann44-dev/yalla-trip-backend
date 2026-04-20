"""Base contract every payment gateway implements.

Keeping this abstract makes it trivial to add a new provider later —
the router code doesn't know about Fawry vs Paymob vs anything else.
"""

from __future__ import annotations

from abc import ABC, abstractmethod
from dataclasses import dataclass
from typing import Any

from app.models.payment import PaymentMethod, PaymentState


class GatewayError(Exception):
    """Raised when a gateway call fails for any reason."""

    def __init__(self, message: str, provider: str, raw: Any | None = None):
        super().__init__(message)
        self.provider = provider
        self.raw = raw


@dataclass
class InitiateResult:
    """What we hand back to the client to actually complete the payment.

    * ``checkout_url`` – URL the Flutter client opens in a web view.
    * ``provider_ref`` – the gateway's own identifier (order id, txn id).
    * ``extra`` – method-specific metadata (Fawry reference number,
      Paymob iframe id, etc.) surfaced to the client as-is.
    * ``raw`` – untouched gateway response (for audit / logs).
    """

    provider_ref: str | None
    checkout_url: str | None
    extra: dict[str, Any]
    raw: dict[str, Any]


@dataclass
class WebhookResult:
    """Normalised webhook outcome used by the router to mutate state."""

    merchant_ref: str
    provider_ref: str | None
    state: PaymentState
    amount: float | None = None
    raw: dict[str, Any] | None = None


class PaymentGateway(ABC):
    """Abstract gateway.  Concrete subclasses live in this same
    package (``fawry.py``, ``paymob.py``, ``cod.py``)."""

    provider: str  # "fawry", "paymob", "cod" — set by subclass
    supported_methods: tuple[PaymentMethod, ...]

    @abstractmethod
    async def initiate(
        self,
        *,
        merchant_ref: str,
        amount: float,
        method: PaymentMethod,
        customer_email: str,
        customer_phone: str,
        customer_name: str,
        description: str,
    ) -> InitiateResult: ...

    @abstractmethod
    def verify_webhook(self, payload: dict[str, Any]) -> bool: ...

    @abstractmethod
    def parse_webhook(self, payload: dict[str, Any]) -> WebhookResult: ...

    async def refund(self, provider_ref: str, amount: float) -> bool:
        """Optional — default implementation raises, so providers that
        don't implement it surface a clear error."""
        raise GatewayError(
            f"refund not implemented for {self.provider}",
            provider=self.provider,
        )
