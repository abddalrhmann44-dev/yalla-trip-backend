"""Paymob payment gateway – cards + e-wallets (Egypt).

Two-step flow:
  1. ``POST /auth/tokens``        → get an ephemeral API token
  2. ``POST /ecommerce/orders``   → create an order against our merchant
  3. ``POST /acceptance/payment_keys`` → get a ``payment_key`` bound to
     the order + an integration id (card / wallet)
  4. Client opens ``https://accept.paymob.com/api/acceptance/iframes/{ID}?payment_token={key}``

Webhook signature uses HMAC-SHA-512 over a canonical concatenation of
fields (documented by Paymob); ``verify_webhook`` implements the
standard check.

Credentials required from .env:
  * ``PAYMOB_API_KEY``            – admin API key
  * ``PAYMOB_HMAC_SECRET``        – shared secret for webhook verification
  * ``PAYMOB_INTEGRATION_CARD``   – card integration id
  * ``PAYMOB_INTEGRATION_WALLET`` – mobile-wallet integration id
  * ``PAYMOB_IFRAME_ID``          – hosted iframe id used by the card flow
"""

from __future__ import annotations

import hashlib
import hmac
from typing import Any

import httpx
import structlog

from app.config import get_settings
from app.models.payment import PaymentMethod, PaymentState
from app.services.gateways.base import (
    GatewayError,
    InitiateResult,
    PaymentGateway,
    WebhookResult,
)

logger = structlog.get_logger(__name__)

_BASE_URL = "https://accept.paymob.com/api"


class PaymobGateway(PaymentGateway):
    provider = "paymob"
    supported_methods = (PaymentMethod.card, PaymentMethod.wallet)

    def __init__(self) -> None:
        s = get_settings()
        self._api_key = s.PAYMOB_API_KEY
        self._hmac_secret = s.PAYMOB_HMAC_SECRET
        self._iframe_id = s.PAYMOB_IFRAME_ID
        self._int_card = s.PAYMOB_INTEGRATION_CARD
        self._int_wallet = s.PAYMOB_INTEGRATION_WALLET

    def _require_config(self) -> None:
        missing = [
            n for n, v in (
                ("PAYMOB_API_KEY", self._api_key),
                ("PAYMOB_HMAC_SECRET", self._hmac_secret),
            ) if not v
        ]
        if missing:
            raise GatewayError(
                f"Paymob credentials missing: {', '.join(missing)}",
                provider=self.provider,
            )

    async def _auth(self, client: httpx.AsyncClient) -> str:
        resp = await client.post(
            f"{_BASE_URL}/auth/tokens",
            json={"api_key": self._api_key},
        )
        data = resp.json()
        token = data.get("token")
        if not token:
            raise GatewayError(
                "Paymob auth failed", provider=self.provider, raw=data
            )
        return token

    async def _create_order(
        self, client: httpx.AsyncClient, token: str, *, merchant_ref: str, amount_cents: int
    ) -> int:
        resp = await client.post(
            f"{_BASE_URL}/ecommerce/orders",
            json={
                "auth_token": token,
                "delivery_needed": "false",
                "amount_cents": amount_cents,
                "currency": "EGP",
                "merchant_order_id": merchant_ref,
                "items": [],
            },
        )
        data = resp.json()
        order_id = data.get("id")
        if not order_id:
            raise GatewayError(
                f"Paymob order creation failed: {data}",
                provider=self.provider,
                raw=data,
            )
        return int(order_id)

    async def _payment_key(
        self,
        client: httpx.AsyncClient,
        token: str,
        *,
        order_id: int,
        amount_cents: int,
        integration_id: str,
        customer_email: str,
        customer_phone: str,
        customer_name: str,
    ) -> str:
        first, _, last = customer_name.strip().partition(" ")
        billing = {
            "apartment": "NA",
            "email": customer_email or "noemail@talaa.app",
            "floor": "NA",
            "first_name": first or "Customer",
            "street": "NA",
            "building": "NA",
            "phone_number": customer_phone or "+201000000000",
            "shipping_method": "NA",
            "postal_code": "NA",
            "city": "NA",
            "country": "EG",
            "last_name": last or "NA",
            "state": "NA",
        }
        resp = await client.post(
            f"{_BASE_URL}/acceptance/payment_keys",
            json={
                "auth_token": token,
                "amount_cents": amount_cents,
                "expiration": 3600,
                "order_id": order_id,
                "billing_data": billing,
                "currency": "EGP",
                "integration_id": integration_id,
            },
        )
        data = resp.json()
        key = data.get("token")
        if not key:
            raise GatewayError(
                f"Paymob payment_key failed: {data}",
                provider=self.provider,
                raw=data,
            )
        return key

    # ── initiate ────────────────────────────────────────────
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
        self._require_config()

        integration = (
            self._int_card
            if method == PaymentMethod.card
            else self._int_wallet
        )
        if not integration:
            raise GatewayError(
                f"No Paymob integration id configured for method {method.value}",
                provider=self.provider,
            )

        amount_cents = int(round(amount * 100))
        try:
            async with httpx.AsyncClient(timeout=30) as client:
                token = await self._auth(client)
                order_id = await self._create_order(
                    client, token,
                    merchant_ref=merchant_ref,
                    amount_cents=amount_cents,
                )
                payment_key = await self._payment_key(
                    client, token,
                    order_id=order_id,
                    amount_cents=amount_cents,
                    integration_id=str(integration),
                    customer_email=customer_email,
                    customer_phone=customer_phone,
                    customer_name=customer_name,
                )
        except httpx.HTTPError as exc:
            raise GatewayError(
                f"Paymob HTTP error: {exc}", provider=self.provider
            ) from exc

        if method == PaymentMethod.card:
            checkout_url = (
                f"https://accept.paymob.com/api/acceptance/iframes/"
                f"{self._iframe_id}?payment_token={payment_key}"
            )
        else:
            # Wallet flow returns a redirect URL in the next call
            checkout_url = (
                f"https://accept.paymob.com/api/acceptance/post_pay?"
                f"payment_token={payment_key}"
            )

        logger.info(
            "paymob_initiate",
            ref=merchant_ref,
            order_id=order_id,
            method=method.value,
        )
        return InitiateResult(
            provider_ref=str(order_id),
            checkout_url=checkout_url,
            extra={
                "order_id": order_id,
                "payment_key": payment_key,
                "iframe_id": self._iframe_id,
            },
            raw={"order_id": order_id, "payment_key": payment_key},
        )

    # ── webhook ─────────────────────────────────────────────
    # Paymob HMAC is built by concatenating the following fields in
    # the exact documented order, all lowercased-string.  See:
    # https://docs.paymob.com/docs/hmac-calculation
    _HMAC_FIELDS = (
        "amount_cents",
        "created_at",
        "currency",
        "error_occured",
        "has_parent_transaction",
        "id",
        "integration_id",
        "is_3d_secure",
        "is_auth",
        "is_capture",
        "is_refunded",
        "is_standalone_payment",
        "is_voided",
        "order.id",
        "owner",
        "pending",
        "source_data.pan",
        "source_data.sub_type",
        "source_data.type",
        "success",
    )

    def _extract_field(self, obj: dict[str, Any], dotted: str) -> str:
        cur: Any = obj
        for part in dotted.split("."):
            if not isinstance(cur, dict):
                return ""
            cur = cur.get(part, "")
        if isinstance(cur, bool):
            return "true" if cur else "false"
        return "" if cur is None else str(cur)

    def verify_webhook(self, payload: dict[str, Any]) -> bool:
        if not self._hmac_secret:
            return False
        obj = payload.get("obj") if isinstance(payload.get("obj"), dict) else payload
        concatenated = "".join(self._extract_field(obj, f) for f in self._HMAC_FIELDS)
        expected = hmac.new(
            self._hmac_secret.encode(),
            concatenated.encode(),
            hashlib.sha512,
        ).hexdigest()
        provided = payload.get("hmac") or ""
        return hmac.compare_digest(expected, provided)

    async def refund(self, provider_ref: str, amount: float) -> bool:
        """Issue a (partial) refund through Paymob.

        ``provider_ref`` is the transaction id we stored when the
        webhook marked the payment ``paid``.
        """
        self._require_config()
        amount_cents = int(round(amount * 100))
        try:
            async with httpx.AsyncClient(timeout=30) as client:
                token = await self._auth(client)
                resp = await client.post(
                    f"{_BASE_URL}/acceptance/void_refund/refund",
                    headers={"Authorization": f"Bearer {token}"},
                    json={
                        "auth_token": token,
                        "transaction_id": provider_ref,
                        "amount_cents": amount_cents,
                    },
                )
                data = resp.json() if resp.content else {}
        except httpx.HTTPError as exc:
            raise GatewayError(
                f"Paymob refund HTTP error: {exc}", provider=self.provider
            ) from exc

        logger.info(
            "paymob_refund_response",
            ref=provider_ref,
            amount=amount,
            ok=resp.is_success,
        )
        if not resp.is_success:
            raise GatewayError(
                f"Paymob refund failed: {data}",
                provider=self.provider,
                raw=data if isinstance(data, dict) else None,
            )
        return True

    def parse_webhook(self, payload: dict[str, Any]) -> WebhookResult:
        obj = payload.get("obj") if isinstance(payload.get("obj"), dict) else payload
        success = bool(obj.get("success"))
        pending = bool(obj.get("pending"))
        refunded = bool(obj.get("is_refunded"))
        voided = bool(obj.get("is_voided"))

        if refunded:
            state = PaymentState.refunded
        elif voided:
            state = PaymentState.cancelled
        elif success:
            state = PaymentState.paid
        elif pending:
            state = PaymentState.processing
        else:
            state = PaymentState.failed

        order = obj.get("order") or {}
        merchant_ref = (
            order.get("merchant_order_id")
            or obj.get("merchant_order_id")
            or str(order.get("id", ""))
        )
        amount = None
        try:
            amount = float(obj.get("amount_cents", 0)) / 100.0
        except (TypeError, ValueError):
            pass

        return WebhookResult(
            merchant_ref=str(merchant_ref),
            provider_ref=str(obj.get("id") or ""),
            state=state,
            amount=amount,
            raw=payload,
        )
