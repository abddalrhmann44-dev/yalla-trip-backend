"""Fawry payment gateway – Egyptian market.

Supports two methods:
  * ``fawry_voucher`` – customer pays at any Fawry outlet using the
    reference number we surface to them.
  * ``card``          – Fawry-hosted card page (optional upgrade).

Uses the classic SHA-256 signature scheme Fawry documents.
"""

from __future__ import annotations

import hashlib
import time
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


class FawryGateway(PaymentGateway):
    provider = "fawry"
    supported_methods = (PaymentMethod.fawry_voucher, PaymentMethod.card)

    def __init__(self) -> None:
        s = get_settings()
        self._merchant = s.FAWRY_MERCHANT_CODE
        self._secret = s.FAWRY_SECRET_KEY
        self._base = s.FAWRY_BASE_URL.rstrip("/")

    # ── helpers ─────────────────────────────────────────────
    def _sign(self, *parts: str) -> str:
        return hashlib.sha256("".join(parts).encode()).hexdigest()

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
        if not self._merchant or not self._secret:
            raise GatewayError(
                "Fawry credentials are not configured",
                provider=self.provider,
            )

        signature = self._sign(
            self._merchant,
            merchant_ref,
            customer_phone,
            f"{amount:.2f}",
            self._secret,
        )
        payload = {
            "merchantCode": self._merchant,
            "merchantRefNum": merchant_ref,
            "customerMobile": customer_phone,
            "customerEmail": customer_email or "",
            "customerName": customer_name or "Customer",
            "customerProfileId": customer_phone or merchant_ref,
            "amount": round(amount, 2),
            "currencyCode": "EGP",
            "description": description,
            "paymentExpiry": int(time.time() * 1000) + 24 * 60 * 60 * 1000,
            "chargeItems": [
                {
                    "itemId": merchant_ref,
                    "description": description,
                    "price": round(amount, 2),
                    "quantity": 1,
                }
            ],
            "signature": signature,
            "paymentMethod": (
                "CARD" if method == PaymentMethod.card else "PAYATFAWRY"
            ),
        }
        url = f"{self._base}/ECommerceWeb/Fawry/payments/charge"
        try:
            async with httpx.AsyncClient(timeout=30) as client:
                resp = await client.post(url, json=payload)
                data = resp.json()
        except httpx.HTTPError as exc:
            raise GatewayError(
                f"Fawry HTTP error: {exc}", provider=self.provider
            ) from exc

        logger.info(
            "fawry_charge_response",
            ref=merchant_ref,
            status=data.get("statusCode"),
        )

        if data.get("statusCode") != 200:
            raise GatewayError(
                data.get("statusDescription", "Fawry charge failed"),
                provider=self.provider,
                raw=data,
            )

        provider_ref = str(data.get("referenceNumber") or "")
        return InitiateResult(
            provider_ref=provider_ref,
            # Fawry vouchers don't use a redirect URL; we return the
            # reference number instead.  Card flow returns a hosted URL.
            checkout_url=data.get("paymentURL") or data.get("expirationTime"),
            extra={
                "reference_number": provider_ref,
                "expiration_time": data.get("expirationTime"),
            },
            raw=data,
        )

    # ── refund ──────────────────────────────────────────────
    async def refund(self, provider_ref: str, amount: float) -> bool:
        """Call Fawry's refund endpoint with the transaction reference."""
        if not self._merchant or not self._secret:
            raise GatewayError(
                "Fawry credentials are not configured",
                provider=self.provider,
            )
        signature = self._sign(
            self._merchant,
            provider_ref,
            f"{amount:.2f}",
            self._secret,
        )
        payload = {
            "merchantCode": self._merchant,
            "referenceNumber": provider_ref,
            "refundAmount": round(amount, 2),
            "reason": "Customer cancellation",
            "signature": signature,
        }
        url = f"{self._base}/ECommerceWeb/Fawry/payments/refund"
        try:
            async with httpx.AsyncClient(timeout=30) as client:
                resp = await client.post(url, json=payload)
                data = resp.json() if resp.content else {}
        except httpx.HTTPError as exc:
            raise GatewayError(
                f"Fawry refund HTTP error: {exc}", provider=self.provider
            ) from exc

        logger.info(
            "fawry_refund_response", ref=provider_ref, status=data.get("statusCode")
        )
        if data.get("statusCode") != 200:
            raise GatewayError(
                data.get("statusDescription", "Fawry refund failed"),
                provider=self.provider,
                raw=data if isinstance(data, dict) else None,
            )
        return True

    # ── webhook ─────────────────────────────────────────────
    def verify_webhook(self, payload: dict[str, Any]) -> bool:
        expected = self._sign(
            payload.get("fawryRefNumber", ""),
            payload.get("merchantRefNumber", payload.get("merchantRefNum", "")),
            str(payload.get("paymentAmount", "")),
            str(payload.get("orderAmount", "")),
            payload.get("orderStatus", ""),
            payload.get("paymentMethod", ""),
            self._secret,
        )
        return expected == payload.get("messageSignature", "")

    def parse_webhook(self, payload: dict[str, Any]) -> WebhookResult:
        merchant_ref = (
            payload.get("merchantRefNumber")
            or payload.get("merchantRefNum")
            or ""
        )
        status_map = {
            "PAID": PaymentState.paid,
            "NEW": PaymentState.pending,
            "EXPIRED": PaymentState.expired,
            "REFUNDED": PaymentState.refunded,
            "CANCELED": PaymentState.cancelled,
            "CANCELLED": PaymentState.cancelled,
            "FAILED": PaymentState.failed,
        }
        state = status_map.get(
            (payload.get("orderStatus") or "").upper(),
            PaymentState.processing,
        )
        amount = None
        try:
            amount = float(payload.get("paymentAmount") or payload.get("orderAmount") or 0)
        except (TypeError, ValueError):
            pass

        return WebhookResult(
            merchant_ref=str(merchant_ref),
            provider_ref=str(payload.get("fawryRefNumber") or ""),
            state=state,
            amount=amount,
            raw=payload,
        )
