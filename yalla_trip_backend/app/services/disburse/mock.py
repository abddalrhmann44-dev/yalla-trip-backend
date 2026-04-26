"""In-process disbursement gateway for development & CI.

The mock plays back a realistic round-trip: ``initiate`` always
returns ``initiated`` with a fake ``MOCK-DSB-…`` reference, and
:meth:`make_success_webhook` / :meth:`make_failure_webhook` produce
the matching webhook payload + signature so the test suite can
drive the full state machine without a network call.

The signature is HMAC-SHA256 over the raw body using a fixed
``MOCK_DISBURSE_SECRET`` so even the verification path gets
exercised — copying the production code shape pays off the day a
developer accidentally weakens the real verifier.
"""

from __future__ import annotations

import hashlib
import hmac
import json
import time
import uuid
from typing import Any

import structlog

from app.services.disburse.base import (
    DisburseGateway,
    DisburseRequest,
    DisburseResult,
    DisburseResultStatus,
    DisburseWebhook,
)

logger = structlog.get_logger(__name__)

# Fixed secret so tests can re-derive signatures deterministically.
# Real gateways pull this from settings — the mock is intentionally
# hard-coded because it never leaves the dev environment.
MOCK_DISBURSE_SECRET = b"mock-disburse-secret-do-not-use-in-prod"


def _sign(body: bytes) -> str:
    return hmac.new(MOCK_DISBURSE_SECRET, body, hashlib.sha256).hexdigest()


class MockDisburseGateway(DisburseGateway):
    name = "mock"

    async def initiate(self, request: DisburseRequest) -> DisburseResult:
        # Generate a stable-looking ref the admin can paste into the
        # mock webhook helper below.  Using ``payout_id`` in the
        # suffix makes log lines self-explanatory.
        ref = f"MOCK-DSB-{request.payout_id}-{uuid.uuid4().hex[:8].upper()}"
        logger.info(
            "mock_disburse_initiated",
            payout_id=request.payout_id,
            amount=request.amount_egp,
            channel=request.channel.value,
            ref=ref,
        )
        return DisburseResult(
            status=DisburseResultStatus.initiated,
            provider_ref=ref,
            provider_message="Accepted (mock)",
            raw={
                "ref": ref,
                "amount": request.amount_egp,
                "channel": request.channel.value,
                "note": request.note,
            },
        )

    async def parse_webhook(
        self,
        headers: dict[str, str],
        body: bytes,
    ) -> DisburseWebhook | None:
        # Header lookup is case-insensitive in HTTP land — most ASGI
        # servers already lower-case keys but normalise to be safe.
        lower = {k.lower(): v for k, v in headers.items()}
        sig = lower.get("x-mock-signature")
        if not sig or not hmac.compare_digest(sig, _sign(body)):
            logger.warning("mock_disburse_webhook_bad_signature")
            return None

        try:
            payload: dict[str, Any] = json.loads(body)
        except json.JSONDecodeError:
            logger.warning("mock_disburse_webhook_bad_json")
            return None

        # Required keys.  Missing values are treated as a malformed
        # webhook so we never crash on partial payloads.
        try:
            payout_id = int(payload["payout_id"])
            ref = str(payload["ref"])
            status = str(payload["status"])
        except (KeyError, ValueError, TypeError):
            logger.warning("mock_disburse_webhook_missing_fields")
            return None

        # ``amount`` is optional in the mock payload; tests that don't
        # set it leave the cross-check disabled, which mirrors how the
        # router handles real gateways that simply omit the field.
        amount_raw = payload.get("amount")
        try:
            amount_egp = float(amount_raw) if amount_raw is not None else None
        except (TypeError, ValueError):
            amount_egp = None

        return DisburseWebhook(
            payout_id=payout_id,
            provider_ref=ref,
            succeeded=(status == "succeeded"),
            failed=(status == "failed"),
            message=payload.get("message"),
            amount_egp=amount_egp,
            raw=payload,
        )

    # ── Test helpers (NOT part of the gateway interface) ────────
    @staticmethod
    def make_success_webhook(
        *, payout_id: int, ref: str, amount: float | None = None
    ) -> tuple[bytes, dict[str, str]]:
        """Build a body+headers pair the router can ingest verbatim.

        ``amount`` (EGP) is optional; when provided it is included in
        the payload so the router can exercise the amount-mismatch
        cross-check.  Tests that don't care about that path can leave
        it as ``None`` (matches gateways that omit the field).
        """
        body_dict: dict[str, Any] = {
            "payout_id": payout_id,
            "ref": ref,
            "status": "succeeded",
            "message": "Funds delivered (mock)",
            "ts": int(time.time()),
        }
        if amount is not None:
            body_dict["amount"] = amount
        body = json.dumps(body_dict).encode("utf-8")
        return body, {"X-Mock-Signature": _sign(body)}

    @staticmethod
    def make_failure_webhook(
        *, payout_id: int, ref: str, reason: str
    ) -> tuple[bytes, dict[str, str]]:
        body_dict = {
            "payout_id": payout_id,
            "ref": ref,
            "status": "failed",
            "message": reason,
            "ts": int(time.time()),
        }
        body = json.dumps(body_dict).encode("utf-8")
        return body, {"X-Mock-Signature": _sign(body)}

    # ── Status read-back ────────────────────────────────────────
    async def fetch_status(self, provider_ref: str) -> DisburseWebhook | None:
        """Mock has no out-of-band store, so we report ``processing``.

        Real gateways look up the gateway-side row.  For the mock we
        simply admit we don't know — the reconciliation cron will
        log this and keep watching.  Tests that need a deterministic
        terminal status should call :meth:`make_success_webhook`
        directly instead.
        """
        if not provider_ref.startswith("MOCK-DSB-"):
            return None
        try:
            payout_id = int(provider_ref.split("-")[2])
        except (IndexError, ValueError):
            return None
        return DisburseWebhook(
            payout_id=payout_id,
            provider_ref=provider_ref,
            succeeded=False,
            failed=False,
            message="Status unknown (mock fetch_status)",
            raw={"ref": provider_ref, "status": "processing"},
        )
