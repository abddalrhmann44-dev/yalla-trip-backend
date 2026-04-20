"""Cash-on-delivery / pay-at-check-in gateway.

No external call — we simply mark the payment as ``pending`` and rely
on the host marking it paid after the guest arrives.
"""

from __future__ import annotations

from typing import Any

from app.models.payment import PaymentMethod, PaymentState
from app.services.gateways.base import (
    InitiateResult,
    PaymentGateway,
    WebhookResult,
)


class CODGateway(PaymentGateway):
    provider = "cod"
    supported_methods = (PaymentMethod.cod,)

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
    ) -> InitiateResult:
        return InitiateResult(
            provider_ref=merchant_ref,
            checkout_url=None,
            extra={"note": "Pay in cash at check-in."},
            raw={"provider": "cod"},
        )

    def verify_webhook(self, payload: dict[str, Any]) -> bool:
        # COD never fires a webhook.
        return False

    def parse_webhook(self, payload: dict[str, Any]) -> WebhookResult:
        return WebhookResult(
            merchant_ref=str(payload.get("merchant_ref", "")),
            provider_ref=None,
            state=PaymentState.pending,
            raw=payload,
        )

    async def refund(self, provider_ref: str, amount: float) -> bool:
        # Nothing was ever charged – treat the refund as a no-op success.
        return True
