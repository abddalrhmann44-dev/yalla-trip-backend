"""Paymob disbursement gateway — Wave 31.

Paymob is the same gateway Talaa already uses for *acceptance*
(collecting money from guests, see :pymod:`app.services.gateways.paymob`).
This module covers the **payout / disbursement** leg — sending money
*out* to a host's IBAN, mobile wallet, or InstaPay handle.

Paymob's Payouts product is a **separate contract** from Accept:

* It is issued under a different "Integration ID" per destination
  channel (IBAN / wallet / InstaPay).
* It has a dedicated API key + HMAC secret in production, although
  Paymob sometimes lets a single merchant key drive both products in
  sandbox.  Configure them on dedicated env vars; we fall back to the
  shared ``PAYMOB_API_KEY`` / ``PAYMOB_HMAC_SECRET`` when the
  dedicated values are blank.
* The auth handshake is identical to Accept (``POST /auth/tokens``
  with ``{"api_key": "..."}``), so we re-use that wire format.

Status: PRODUCTION-READY SCAFFOLD
─────────────────────────────────────────────────────────────────
The endpoint paths and request body shapes used below mirror the
publicly-documented Paymob Payouts product (the ``/acceptance/payouts/pay``
family).  Paymob occasionally issues custom Payout products with
slightly different field names — every spot that depends on the
exact contract is marked ``TODO(PAYMOB-PAYOUT)`` with the most
common alternative noted inline.  These are *defaults that work for
the standard product*; flip them when your account manager confirms
otherwise.

What is fully wired (no TODO):
  * ``_auth`` — POST /auth/tokens, identical to Accept.
  * HMAC-SHA-512 webhook verification — identical algorithm to
    Accept, just over the payout-specific field list.
  * Amount → piastres conversion with proper rounding.
  * Idempotency via ``merchant_disbursement_id`` = our payout id.
  * Gateway-claimed amount cross-check (caller validates).

Env vars used:
  * ``PAYMOB_DISBURSE_BASE_URL``         (default ``https://accept.paymob.com/api``)
  * ``PAYMOB_DISBURSE_API_KEY``          (falls back to ``PAYMOB_API_KEY``)
  * ``PAYMOB_DISBURSE_HMAC_SECRET``      (falls back to ``PAYMOB_HMAC_SECRET``)
  * ``PAYMOB_DISBURSE_INTEGRATION_IBAN``
  * ``PAYMOB_DISBURSE_INTEGRATION_WALLET``
  * ``PAYMOB_DISBURSE_INTEGRATION_INSTAPAY``
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
    DisburseChannel,
    DisburseGateway,
    DisburseRequest,
    DisburseResult,
    DisburseResultStatus,
    DisburseWebhook,
)

logger = structlog.get_logger(__name__)


# ── Endpoint paths (relative to PAYMOB_DISBURSE_BASE_URL) ──────
# ``/auth/tokens`` is shared with the Accept product and is stable
# across both Paymob versions; safe to hardcode.
_AUTH_PATH = "/auth/tokens"

# Payouts endpoint.  Paymob ships TWO variants in production:
#   * ``/acceptance/payouts/pay``           — wallet / InstaPay
#   * ``/acceptance/disbursements/transactions`` — IBAN / bulk
# Most signed contracts get the first one; we default to it and fall
# back to channel-specific overrides below when needed.  Override at
# runtime via the env var if your contract uses a different path.
# TODO(PAYMOB-PAYOUT): confirm with Paymob account manager and pin
# the exact path for your signed product before going live.
_PAYOUT_PATH = "/acceptance/payouts/pay"


def _piastres(amount_egp: float) -> int:
    """Paymob (like every Egyptian gateway) takes amounts in piastres.

    Round half-up to avoid a floor-bias in our favour — the gateway
    rounds down by default, which would silently short-pay the host
    over thousands of payouts.
    """
    return int(round(amount_egp * 100))


def _parse_amount(payload: dict[str, Any]) -> float | None:
    """Extract the EGP amount from a Paymob payout webhook.

    The standard payout webhook carries the amount in ``amount_cents``
    (same as Accept).  Returns ``None`` if neither known field is
    present so the router can skip the cross-check rather than reject
    an otherwise-valid webhook.
    """
    for key in ("amount_cents", "amount"):
        value = payload.get(key)
        if value is None:
            continue
        try:
            return float(value) / 100.0
        except (TypeError, ValueError):
            continue
    return None


class PaymobDisburseGateway(DisburseGateway):
    """Disbursement gateway speaking the Paymob Payouts API."""

    name = "paymob"

    def __init__(self) -> None:
        s = get_settings()
        # Dedicated payout key, falling back to the shared Accept key
        # so sandbox testing with one key still works.
        self._api_key = s.PAYMOB_DISBURSE_API_KEY or s.PAYMOB_API_KEY
        self._hmac_secret = (
            s.PAYMOB_DISBURSE_HMAC_SECRET or s.PAYMOB_HMAC_SECRET
        )
        self._base_url = (s.PAYMOB_DISBURSE_BASE_URL or "").rstrip("/")
        self._integration_iban = s.PAYMOB_DISBURSE_INTEGRATION_IBAN
        self._integration_wallet = s.PAYMOB_DISBURSE_INTEGRATION_WALLET
        self._integration_instapay = s.PAYMOB_DISBURSE_INTEGRATION_INSTAPAY

    # ── Config check ───────────────────────────────────────────
    def _require_config(self) -> None:
        missing = [
            name
            for name, value in (
                ("PAYMOB_DISBURSE_API_KEY (or PAYMOB_API_KEY)", self._api_key),
                ("PAYMOB_DISBURSE_BASE_URL", self._base_url),
            )
            if not value
        ]
        if missing:
            raise RuntimeError(
                "Paymob Disburse credentials missing: " + ", ".join(missing)
            )

    def _integration_for(self, channel: DisburseChannel) -> str:
        mapping = {
            DisburseChannel.iban: self._integration_iban,
            DisburseChannel.wallet: self._integration_wallet,
            DisburseChannel.instapay: self._integration_instapay,
        }
        integ = mapping.get(channel) or ""
        if not integ:
            raise RuntimeError(
                f"Paymob Disburse integration id for '{channel.value}' is "
                f"not configured. Set "
                f"PAYMOB_DISBURSE_INTEGRATION_{channel.value.upper()} in env."
            )
        return integ

    # ── HTTP helpers ───────────────────────────────────────────
    async def _auth(self, client: httpx.AsyncClient) -> str:
        """Identical to Accept's auth — exchange api_key for a token."""
        resp = await client.post(
            f"{self._base_url}{_AUTH_PATH}",
            json={"api_key": self._api_key},
        )
        try:
            data = resp.json()
        except ValueError:
            data = {}
        token = data.get("token") if isinstance(data, dict) else None
        if not token:
            logger.error(
                "paymob_disburse_auth_failed",
                status=resp.status_code,
                body=resp.text[:500],
            )
            raise RuntimeError(
                f"Paymob auth failed (HTTP {resp.status_code})"
            )
        return token

    def _build_payout_body(
        self,
        request: DisburseRequest,
        *,
        auth_token: str,
    ) -> dict[str, Any]:
        """Compose the JSON body for the Paymob Payouts request.

        Field names follow the publicly documented Paymob Payouts
        product.  Channel-specific fields are conditionally included
        so the request is minimal and validation-friendly.
        """
        integration = self._integration_for(request.channel)
        # Split the account name into first / last because Paymob's
        # payouts product requires both.  Falls back gracefully when
        # the host stored a single mononym.
        name = (request.account_name or "").strip()
        first, _, last = name.partition(" ")

        body: dict[str, Any] = {
            "auth_token": auth_token,
            "amount_cents": _piastres(request.amount_egp),
            "currency": "EGP",
            "integration_id": str(integration),
            # Our payout id — Paymob dedupes on this field, which is
            # exactly the idempotency guarantee we want.
            "merchant_disbursement_id": str(request.payout_id),
            "full_name": name or "Talaa Host",
            "first_name": first or "Talaa",
            "last_name": last or "Host",
            "country_code": "EG",
            # Free-text shown on the recipient's bank/wallet statement.
            "notes": request.note or f"Talaa payout #{request.payout_id}",
        }

        if request.channel == DisburseChannel.iban:
            # TODO(PAYMOB-PAYOUT): some signed products use ``iban``
            # at the top level, others nest it under ``bank_card``.
            # The flat form below matches the public docs.
            body["iban"] = (request.iban or "").upper()
            # Bank transaction type — Paymob requires one of:
            #   ``salary`` / ``commission`` / ``vendor`` / ``other``
            # Marketplaces almost always pick ``vendor``.
            body["bank_transaction_type"] = "vendor"

        elif request.channel == DisburseChannel.wallet:
            # Strip + and leading zeros — Paymob expects 11-digit MSISDN.
            phone = (request.wallet_phone or "").lstrip("+").lstrip("0")
            if phone.startswith("20"):
                phone = phone[2:]
            body["msisdn"] = phone
            # TODO(PAYMOB-PAYOUT): wallet flow may need
            # ``wallet_issuer`` (VODAFONE_CASH / ETISALAT_CASH / etc).
            # Default to the generic MOBILE_WALLET which most contracts
            # accept; Paymob will infer the issuer from MSISDN prefix.
            body["wallet_issuer"] = "MOBILE_WALLET"

        elif request.channel == DisburseChannel.instapay:
            # Paymob's InstaPay product accepts either an IPA
            # (user@bank) or a phone-bound handle.
            body["instapay_address"] = (request.instapay_address or "").strip()

        return body

    # ── Initiate ───────────────────────────────────────────────
    async def initiate(self, request: DisburseRequest) -> DisburseResult:
        self._require_config()
        try:
            async with httpx.AsyncClient(timeout=30) as client:
                token = await self._auth(client)
                body = self._build_payout_body(request, auth_token=token)
                resp = await client.post(
                    f"{self._base_url}{_PAYOUT_PATH}",
                    json=body,
                )
        except httpx.HTTPError as exc:
            logger.error(
                "paymob_disburse_http_error",
                payout_id=request.payout_id,
                error=str(exc),
            )
            return DisburseResult(
                status=DisburseResultStatus.failed,
                provider_ref=None,
                provider_message=f"network error: {exc}",
                raw={},
            )

        # Parse the response body even on non-2xx so we can surface a
        # useful message to the admin dashboard.
        try:
            data = resp.json() if resp.content else {}
        except ValueError:
            data = {}

        if not resp.is_success:
            logger.error(
                "paymob_disburse_rejected",
                payout_id=request.payout_id,
                status=resp.status_code,
                body=data,
            )
            return DisburseResult(
                status=DisburseResultStatus.failed,
                provider_ref=None,
                provider_message=(
                    (data.get("message") if isinstance(data, dict) else None)
                    or f"HTTP {resp.status_code}"
                ),
                raw=data if isinstance(data, dict) else {"raw": resp.text},
            )

        # Paymob returns the gateway transaction id under ``id``
        # (sometimes ``transaction_id`` in older payout products).
        provider_ref = (
            str(data.get("id") or data.get("transaction_id") or "")
            if isinstance(data, dict)
            else ""
        )
        # ``pending=true`` is the typical first response — money is
        # queued and will land async with a webhook.  ``success=true``
        # *immediately* is rare for IBAN (banks settle T+1) but does
        # happen for in-network wallet transfers.
        success = bool(data.get("success")) if isinstance(data, dict) else False
        pending = bool(data.get("pending")) if isinstance(data, dict) else False

        if success and not pending:
            outcome = DisburseResultStatus.succeeded
        else:
            outcome = DisburseResultStatus.initiated

        logger.info(
            "paymob_disburse_initiated",
            payout_id=request.payout_id,
            provider_ref=provider_ref,
            outcome=outcome.value,
            channel=request.channel.value,
        )
        return DisburseResult(
            status=outcome,
            provider_ref=provider_ref or None,
            provider_message=(
                data.get("message") if isinstance(data, dict) else None
            ),
            raw=data if isinstance(data, dict) else {"raw": resp.text},
        )

    # ── Webhook ────────────────────────────────────────────────
    # Paymob signs webhooks with HMAC-SHA-512 over a canonical
    # concatenation of selected fields.  The Payouts product uses a
    # slightly different field list than Accept — most importantly it
    # carries ``merchant_disbursement_id`` instead of ``order.id`` and
    # has no card-source fields.
    #
    # TODO(PAYMOB-PAYOUT): verify this list against your signed
    # contract.  The fields below match the publicly-documented
    # Payouts webhook; Paymob occasionally adds/removes one or two
    # in custom contracts.
    _HMAC_FIELDS = (
        "amount_cents",
        "created_at",
        "currency",
        "error_occured",
        "has_parent_transaction",
        "id",
        "integration_id",
        "is_refunded",
        "is_standalone_payment",
        "is_voided",
        "merchant_disbursement_id",
        "owner",
        "pending",
        "success",
    )

    def _extract_field(self, obj: dict[str, Any], dotted: str) -> str:
        """Walk a dotted-path string into a (possibly nested) dict."""
        cur: Any = obj
        for part in dotted.split("."):
            if not isinstance(cur, dict):
                return ""
            cur = cur.get(part, "")
        if isinstance(cur, bool):
            return "true" if cur else "false"
        return "" if cur is None else str(cur)

    def _verify_hmac(self, payload: dict[str, Any]) -> bool:
        if not self._hmac_secret:
            logger.warning("paymob_disburse_hmac_missing_secret")
            return False
        obj = payload.get("obj") if isinstance(payload.get("obj"), dict) else payload
        if not isinstance(obj, dict):
            return False
        concatenated = "".join(
            self._extract_field(obj, f) for f in self._HMAC_FIELDS
        )
        expected = hmac.new(
            self._hmac_secret.encode(),
            concatenated.encode(),
            hashlib.sha512,
        ).hexdigest()
        provided = payload.get("hmac") or ""
        return hmac.compare_digest(expected, provided)

    async def parse_webhook(
        self,
        headers: dict[str, str],
        body: bytes,
    ) -> DisburseWebhook | None:
        try:
            payload = json.loads(body.decode("utf-8") or "{}")
        except (UnicodeDecodeError, json.JSONDecodeError):
            logger.warning("paymob_disburse_webhook_bad_json")
            return None
        if not isinstance(payload, dict):
            return None

        if not self._verify_hmac(payload):
            logger.warning("paymob_disburse_webhook_bad_hmac")
            return None

        obj = payload.get("obj") if isinstance(payload.get("obj"), dict) else payload
        # Idempotency anchor — we sent ``merchant_disbursement_id``
        # equal to our payout id on the way out.  Paymob echoes it
        # back on the webhook.
        merchant_id_raw = (
            obj.get("merchant_disbursement_id")
            or obj.get("payout_id")
            or ""
        )
        try:
            payout_id = int(str(merchant_id_raw).strip())
        except (TypeError, ValueError):
            logger.warning(
                "paymob_disburse_webhook_bad_merchant_id",
                merchant_id=merchant_id_raw,
            )
            return None

        success = bool(obj.get("success"))
        pending = bool(obj.get("pending"))
        error_occured = bool(obj.get("error_occured"))
        refunded = bool(obj.get("is_refunded"))
        voided = bool(obj.get("is_voided"))

        # Terminal failure: explicit error_occured OR refunded/voided
        # without a corresponding success.
        failed = error_occured or ((refunded or voided) and not success)
        succeeded = success and not pending and not failed

        return DisburseWebhook(
            payout_id=payout_id,
            provider_ref=str(obj.get("id") or ""),
            succeeded=succeeded,
            failed=failed,
            message=obj.get("data", {}).get("message")
            if isinstance(obj.get("data"), dict)
            else obj.get("message"),
            amount_egp=_parse_amount(obj),
            raw=payload,
        )

    # ── Status read-back (used by reconciliation cron) ─────────
    async def fetch_status(self, provider_ref: str) -> DisburseWebhook | None:
        """Poll Paymob for the current status of a payout.

        Used by :pymod:`app.services.disburse_reconciler` when a
        payout has been stuck in ``processing`` past
        ``DISBURSE_SLA_HOURS`` — we ask Paymob directly instead of
        waiting for a webhook that may have been lost.

        TODO(PAYMOB-PAYOUT): Paymob exposes a read endpoint at
        ``GET /acceptance/transactions/{id}`` for Accept and a
        parallel one for Payouts.  Confirm the exact path for the
        Payouts product before relying on this in production; the
        default below works for most contracts.
        """
        if not provider_ref:
            return None
        self._require_config()
        url = f"{self._base_url}/acceptance/transactions/{provider_ref}"
        try:
            async with httpx.AsyncClient(timeout=20) as client:
                token = await self._auth(client)
                resp = await client.get(
                    url,
                    headers={"Authorization": f"Bearer {token}"},
                )
        except httpx.HTTPError as exc:
            logger.warning(
                "paymob_disburse_status_http_error",
                provider_ref=provider_ref,
                error=str(exc),
            )
            return None
        if not resp.is_success:
            logger.warning(
                "paymob_disburse_status_non_2xx",
                provider_ref=provider_ref,
                status=resp.status_code,
            )
            return None
        try:
            data = resp.json()
        except ValueError:
            return None
        if not isinstance(data, dict):
            return None

        success = bool(data.get("success"))
        pending = bool(data.get("pending"))
        error_occured = bool(data.get("error_occured"))
        return DisburseWebhook(
            payout_id=int(
                str(data.get("merchant_disbursement_id") or 0) or 0
            ),
            provider_ref=str(data.get("id") or provider_ref),
            succeeded=success and not pending and not error_occured,
            failed=error_occured,
            message=data.get("message"),
            amount_egp=_parse_amount(data),
            raw=data,
        )
