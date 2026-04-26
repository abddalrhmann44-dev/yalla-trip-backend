"""Mock payment gateway.

Used when ``PAYMENTS_MOCK_MODE=True`` so the Flutter app can ship to
the App Store / Play Store BEFORE we sign a contract with Paymob /
Kashier / Fawry.

The gateway returns a hosted checkout URL pointing at our own
``/payments/mock-checkout/{merchant_ref}`` endpoint, which renders a
plain HTML page with three buttons (Success / Failure / Cancel).
Pressing a button POSTs back to the API and mutates the matching
``Payment`` row exactly the way a real webhook would, so the booking
flow downstream (status polling, escrow ledger, owner notifications)
exercises the same code paths as the real provider.

To switch over to real gateways, ops just flips ``PAYMENTS_MOCK_MODE``
to ``False`` and fills in the ``PAYMOB_*`` (or Kashier) credentials —
no Flutter rebuild required.
"""

from __future__ import annotations

from typing import Any

from app.config import get_settings
from app.models.payment import PaymentMethod, PaymentState
from app.services.gateways.base import (
    InitiateResult,
    PaymentGateway,
    WebhookResult,
)


class MockGateway(PaymentGateway):
    """Stand-in for any external gateway during pre-launch testing."""

    provider = "mock"
    # We deliberately advertise every method real gateways combined
    # support so the router never rejects a request when mock mode is
    # on — including ``cod`` so the dispatch layer can swap us in for
    # the cash-on-delivery provider too.
    supported_methods = (
        PaymentMethod.card,
        PaymentMethod.wallet,
        PaymentMethod.fawry_voucher,
        PaymentMethod.instapay,
        PaymentMethod.cod,
    )

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
        s = get_settings()
        base = (s.APP_BASE_URL or "").rstrip("/")
        # Relative path is fine if the WebView follows http://host first
        # — but we surface an absolute URL whenever APP_BASE_URL is set
        # so the WebView can load it without any host context.
        path = f"/payments/mock-checkout/{merchant_ref}"
        checkout_url = f"{base}{path}" if base else path

        # Fawry vouchers in real life return a numeric reference the
        # user pays at a physical outlet.  We mimic that here with a
        # 6-digit deterministic stub so the Fawry UI on the client side
        # has something realistic to render.
        extra: dict[str, Any] = {"mock": True}
        if method == PaymentMethod.fawry_voucher:
            extra["reference_number"] = str(abs(hash(merchant_ref)) % 1_000_000).zfill(6)

        return InitiateResult(
            provider_ref=f"MOCK-{merchant_ref}",
            checkout_url=checkout_url,
            extra=extra,
            raw={"mock": True, "merchant_ref": merchant_ref, "amount": amount},
        )

    def verify_webhook(self, payload: dict[str, Any]) -> bool:
        # No real signature in mock mode.  The mock-checkout endpoint
        # is only reachable from authenticated sessions on our own
        # backend, so we accept anything that lands here — but only
        # when mock mode is actually on (the registry is the gate).
        return True

    def parse_webhook(self, payload: dict[str, Any]) -> WebhookResult:
        outcome = (payload.get("outcome") or "").lower()
        if outcome == "success":
            state = PaymentState.paid
        elif outcome == "failure":
            state = PaymentState.failed
        elif outcome == "cancel":
            state = PaymentState.cancelled
        else:
            state = PaymentState.pending

        return WebhookResult(
            merchant_ref=str(payload.get("merchant_ref", "")),
            provider_ref=str(payload.get("provider_ref", "")),
            state=state,
            amount=payload.get("amount"),
            raw=payload,
        )

    async def refund(self, provider_ref: str, amount: float) -> bool:
        # Mock refunds always succeed — the cron / admin tooling can
        # exercise the refund code path without an external call.
        return True
