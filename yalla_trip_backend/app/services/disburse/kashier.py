"""Kashier disbursement gateway.

Kashier is an Egyptian-licensed payment infrastructure provider
that exposes both *acceptance* (taking money in) and *disbursement*
(paying money out) APIs.  This module covers the disbursement leg
only; payment acceptance lives in :pymod:`app.services.gateways`.

⚠️  Status: SKELETON
───────────────────────────────────────────────────────────────
The exact endpoint paths, request bodies, and webhook signature
algorithm depend on the disbursement product Kashier signs us up
for (they have a generic Bulk Payouts product and a wallet-only
``Send Money`` product with slightly different shapes).  Every
location that needs a docs-confirmed value is marked ``TODO(KASHIER)``
below — flip those to real values once you have:

* Sandbox merchant credentials (``KASHIER_DISBURSE_MERCHANT_ID``,
  ``KASHIER_DISBURSE_API_KEY``, ``KASHIER_DISBURSE_SECRET``).
* The production base URL (sandbox is ``https://test-fep.kashier.io``,
  prod is ``https://fep.kashier.io`` for acceptance — confirm the
  disbursement equivalent).
* A copy of their disbursement HMAC algorithm (acceptance uses
  HMAC-SHA256 over a sorted query string — disbursement is usually
  the same but verify).

The skeleton keeps the *shape* of the integration honest so the
router and migration are already correct; only the HTTP wire
format needs to be plugged in once the contract is signed.
"""

from __future__ import annotations

import hashlib
import hmac
import json
from typing import Any

import httpx
import structlog

from app.config import get_settings
from app.services.disburse.base import (
    DisburseGateway,
    DisburseRequest,
    DisburseResult,
    DisburseResultStatus,
    DisburseWebhook,
)

logger = structlog.get_logger(__name__)
settings = get_settings()


# TODO(KASHIER): replace with the disbursement endpoints from the
# signed contract.  These mirror the public docs for the acceptance
# product and are almost certainly close but not exact.
_KASHIER_BASE_URL = getattr(
    settings, "KASHIER_DISBURSE_BASE_URL", "https://api.kashier.io"
)
_INITIATE_PATH = "/payouts/v1/disburse"


def _piastres(amount_egp: float) -> int:
    """Kashier (like every other Egyptian gateway) takes amounts in
    minor units.  Round half-up to avoid floor-bias in our favour —
    that would silently short-pay the host."""
    return int(round(amount_egp * 100))


def _sign(secret: str, payload: dict[str, Any]) -> str:
    """HMAC-SHA256 over the JSON-canonicalised payload.

    TODO(KASHIER): confirm whether the actual product uses the same
    algorithm as acceptance (sorted query string, lower-case hex).
    The implementation below is the generic shape; only the
    serialisation may need to change.
    """
    canonical = json.dumps(payload, sort_keys=True, separators=(",", ":"))
    return hmac.new(
        secret.encode("utf-8"),
        canonical.encode("utf-8"),
        hashlib.sha256,
    ).hexdigest()


class KashierDisburseGateway(DisburseGateway):
    name = "kashier"

    def __init__(self) -> None:
        # Fail fast on missing creds — the registry should never have
        # picked us in that case but guard so production never silently
        # uses a half-configured gateway.
        merchant_id = getattr(settings, "KASHIER_DISBURSE_MERCHANT_ID", "")
        api_key = getattr(settings, "KASHIER_DISBURSE_API_KEY", "")
        secret = getattr(settings, "KASHIER_DISBURSE_SECRET", "")
        if not (merchant_id and api_key and secret):
            raise RuntimeError(
                "Kashier disburse credentials not configured — set "
                "KASHIER_DISBURSE_MERCHANT_ID / API_KEY / SECRET."
            )
        self._merchant_id = merchant_id
        self._api_key = api_key
        self._secret = secret

    # ── Initiate ────────────────────────────────────────────────
    async def initiate(self, request: DisburseRequest) -> DisburseResult:
        # The body shape below follows the *generic* disbursement
        # contract (channel + recipient + amount + idempotency).
        # Adjust field names once the docs confirm the exact schema.
        body: dict[str, Any] = {
            "merchantId": self._merchant_id,
            # ``payout_id`` doubles as the idempotency key — Kashier
            # rejects duplicates with the same value, which protects
            # us from double-paying on retry.
            "merchantOrderId": f"payout-{request.payout_id}",
            "amount": _piastres(request.amount_egp),
            "currency": "EGP",
            "channel": request.channel.value,
            "recipient": {
                "name": request.account_name,
                # Only one of these is sent — Kashier ignores the
                # rest based on ``channel``.
                "iban": request.iban,
                "walletPhone": request.wallet_phone,
                "instapayAddress": request.instapay_address,
            },
            "description": request.note or f"Talaa payout #{request.payout_id}",
        }
        body["signature"] = _sign(self._secret, body)

        headers = {
            "Authorization": f"Bearer {self._api_key}",
            "Content-Type": "application/json",
        }

        try:
            async with httpx.AsyncClient(timeout=20.0) as http:
                resp = await http.post(
                    f"{_KASHIER_BASE_URL}{_INITIATE_PATH}",
                    headers=headers,
                    json=body,
                )
        except httpx.HTTPError as exc:
            # Network-level failure — don't lose the request, but
            # surface enough context for the admin to diagnose.
            logger.error(
                "kashier_disburse_network_error",
                payout_id=request.payout_id,
                error=str(exc),
            )
            return DisburseResult(
                status=DisburseResultStatus.failed,
                provider_ref=None,
                provider_message=f"Network error: {exc}",
            )

        # ``Kashier`` returns 200 + body on success and a 4xx with
        # ``errorMessage`` on failure.  Defensive parsing because
        # webhook bodies sometimes ship as text/plain in test envs.
        try:
            payload: dict[str, Any] = resp.json()
        except ValueError:
            payload = {"raw_text": resp.text}

        if resp.status_code >= 400:
            return DisburseResult(
                status=DisburseResultStatus.failed,
                provider_ref=payload.get("transactionId"),
                provider_message=payload.get(
                    "errorMessage", f"HTTP {resp.status_code}"
                ),
                raw=payload,
            )

        # TODO(KASHIER): confirm the field name for the gateway-side id.
        # Acceptance uses ``transactionId`` — disbursement is usually
        # the same but watch for ``payoutId`` or ``referenceId``.
        provider_ref = (
            payload.get("transactionId")
            or payload.get("payoutId")
            or payload.get("referenceId")
        )
        return DisburseResult(
            status=DisburseResultStatus.initiated,
            provider_ref=provider_ref,
            provider_message=payload.get("message"),
            raw=payload,
        )

    # ── Webhook verification ────────────────────────────────────
    async def parse_webhook(
        self,
        headers: dict[str, str],
        body: bytes,
    ) -> DisburseWebhook | None:
        lower = {k.lower(): v for k, v in headers.items()}
        # TODO(KASHIER): replace ``x-kashier-signature`` if their
        # disbursement product uses a different header name.
        provided_sig = lower.get("x-kashier-signature")
        if not provided_sig:
            logger.warning("kashier_webhook_missing_signature")
            return None

        try:
            payload: dict[str, Any] = json.loads(body)
        except json.JSONDecodeError:
            logger.warning("kashier_webhook_bad_json")
            return None

        # The signature is computed over the payload *minus* the
        # signature field itself — same convention as acceptance.
        verify_payload = {k: v for k, v in payload.items() if k != "signature"}
        expected = _sign(self._secret, verify_payload)
        if not hmac.compare_digest(provided_sig, expected):
            logger.warning(
                "kashier_webhook_bad_signature",
                payout_id=payload.get("merchantOrderId"),
            )
            return None

        # ``merchantOrderId`` is what we sent, formatted ``payout-{id}``.
        order_id = str(payload.get("merchantOrderId", ""))
        if not order_id.startswith("payout-"):
            logger.warning(
                "kashier_webhook_unknown_order_id", order_id=order_id
            )
            return None
        try:
            payout_id = int(order_id.removeprefix("payout-"))
        except ValueError:
            return None

        # TODO(KASHIER): map their status codes to our boolean flags.
        # Common values: SUCCESS, FAILED, PROCESSING, REJECTED.
        status = str(payload.get("status", "")).upper()
        succeeded = status in {"SUCCESS", "SUCCEEDED", "PAID"}
        failed = status in {"FAILED", "REJECTED", "DECLINED"}

        return DisburseWebhook(
            payout_id=payout_id,
            provider_ref=str(
                payload.get("transactionId")
                or payload.get("payoutId")
                or ""
            ),
            succeeded=succeeded,
            failed=failed,
            message=payload.get("message") or payload.get("errorMessage"),
            raw=payload,
        )

    # ── Status read-back (reconciliation) ───────────────────────
    async def fetch_status(self, provider_ref: str) -> DisburseWebhook | None:
        """Poll Kashier for the current state of a transaction.

        Used by the reconciliation scheduler when a payout has been
        stuck in ``processing`` past :data:`DISBURSE_SLA_HOURS` —
        usually because the success webhook was lost.  Returns the
        same normalised :class:`DisburseWebhook` so the caller can
        treat it identically to a real webhook.
        """
        # TODO(KASHIER): confirm the read endpoint path.  Acceptance
        # exposes ``GET /payments/{transactionId}`` — disbursement
        # follows the same pattern but the segment may be different.
        if not provider_ref:
            return None

        url = f"{_KASHIER_BASE_URL}/payouts/v1/disburse/{provider_ref}"
        headers = {
            "Authorization": f"Bearer {self._api_key}",
            "Accept": "application/json",
        }
        try:
            async with httpx.AsyncClient(timeout=15.0) as http:
                resp = await http.get(url, headers=headers)
        except httpx.HTTPError as exc:
            # Reconciliation runs in a loop; never crash on a
            # transient network blip.  The next sweep will retry.
            logger.warning(
                "kashier_fetch_status_network_error",
                provider_ref=provider_ref,
                error=str(exc),
            )
            return None

        if resp.status_code >= 400:
            logger.warning(
                "kashier_fetch_status_http_error",
                provider_ref=provider_ref,
                status_code=resp.status_code,
            )
            return None

        try:
            payload: dict[str, Any] = resp.json()
        except ValueError:
            return None

        # Re-use the webhook decoder so we map status codes the same
        # way (single source of truth for SUCCESS/FAILED matching).
        order_id = str(payload.get("merchantOrderId", ""))
        if not order_id.startswith("payout-"):
            return None
        try:
            payout_id = int(order_id.removeprefix("payout-"))
        except ValueError:
            return None

        status = str(payload.get("status", "")).upper()
        succeeded = status in {"SUCCESS", "SUCCEEDED", "PAID"}
        failed = status in {"FAILED", "REJECTED", "DECLINED"}

        return DisburseWebhook(
            payout_id=payout_id,
            provider_ref=provider_ref,
            succeeded=succeeded,
            failed=failed,
            message=payload.get("message") or payload.get("errorMessage"),
            raw=payload,
        )
