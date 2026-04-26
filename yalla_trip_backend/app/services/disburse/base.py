"""Abstract disbursement gateway.

Every concrete provider (Kashier, mock, future ones like NBD or
Vodafone B2P) implements the same three primitives:

1. ``initiate(request)`` — fire the outgoing transfer and return a
   provider reference.  Network / auth errors raise; business
   failures (insufficient balance, IBAN rejected) come back inside
   :class:`DisburseResult` with a non-success status so the caller
   can surface a friendly message.
2. ``parse_webhook(headers, body)`` — turn the provider's async
   notification into a normalised :class:`DisburseWebhook`.  Verifies
   the signature; returns ``None`` on tampered payloads so the router
   can 401 the caller.
3. ``status(provider_ref)`` — optional read-back used by reconciliation
   crons when a webhook is suspected lost.

Keeping the three primitives narrow makes mocking trivial and lets
the registry pick a concrete implementation based purely on env
vars — no ``if provider == 'kashier'`` ladders inside business
logic.
"""

from __future__ import annotations

from abc import ABC, abstractmethod
from dataclasses import dataclass, field
from enum import Enum
from typing import Any


class DisburseChannel(str, Enum):
    """Destination type for the transfer.

    Mirrors :class:`app.models.payout.BankAccountType` 1:1 — kept as a
    separate enum here so the gateway layer doesn't import from
    ``models`` (avoids a circular dependency).
    """
    iban = "iban"
    wallet = "wallet"          # Vodafone / Etisalat / Orange / WE Pay
    instapay = "instapay"


class DisburseResultStatus(str, Enum):
    """High-level outcome of an :meth:`initiate` call."""
    initiated = "initiated"   # gateway accepted; webhook will follow
    succeeded = "succeeded"   # rare — sync confirmation (e.g. mock)
    failed = "failed"         # gateway rejected up-front


@dataclass(slots=True)
class DisburseRequest:
    """Outgoing transfer order.

    The amount is always EGP (the platform is Egypt-only); the
    gateway is responsible for any minor-units conversion (Kashier
    expects piastres, for example).
    """
    payout_id: int           # our internal id — used as idempotency key
    amount_egp: float        # human-readable amount in pounds
    channel: DisburseChannel
    account_name: str        # IBAN holder / wallet owner — printed on receipt
    # Exactly one of these will be populated based on ``channel``.
    iban: str | None = None
    wallet_phone: str | None = None
    instapay_address: str | None = None
    # Optional human note that some providers display on the recipient
    # statement (Kashier surfaces it as ``description``).
    note: str | None = None


@dataclass(slots=True)
class DisburseResult:
    """Synchronous response to an :meth:`initiate` call."""
    status: DisburseResultStatus
    provider_ref: str | None              # gateway transaction id
    provider_message: str | None = None   # surfaced to admin dashboard
    raw: dict[str, Any] = field(default_factory=dict)


@dataclass(slots=True)
class DisburseWebhook:
    """Normalised webhook payload returned by :meth:`parse_webhook`.

    Always carries enough information for the router to find the
    matching :class:`~app.models.payout.Payout` row and update its
    state without re-querying the gateway.
    """
    payout_id: int                     # our id, recovered from metadata
    provider_ref: str                  # gateway id (cross-check)
    succeeded: bool                    # True on terminal success
    failed: bool                       # True on terminal failure
    message: str | None = None         # gateway-side reason string
    raw: dict[str, Any] = field(default_factory=dict)


class DisburseGateway(ABC):
    """Common contract every disbursement provider implements."""

    #: Short stable identifier persisted on :attr:`Payout.disburse_provider`.
    #: Lower-case, snake-friendly — appears in audit logs and API
    #: responses, so don't change it after launch.
    name: str = "abstract"

    @abstractmethod
    async def initiate(self, request: DisburseRequest) -> DisburseResult:
        """Send the transfer order to the provider."""

    @abstractmethod
    async def parse_webhook(
        self,
        headers: dict[str, str],
        body: bytes,
    ) -> DisburseWebhook | None:
        """Verify + decode an inbound webhook.

        Returns ``None`` when the signature check fails so the router
        can return ``401`` without leaking which check failed.
        """

    async def fetch_status(self, provider_ref: str) -> DisburseWebhook | None:
        """Optional: poll the provider for the current status.

        Default implementation returns ``None`` — gateways that don't
        expose a read API (or we haven't wired it yet) inherit this.
        Reconciliation crons call this when a payout has been stuck
        in ``processing`` past the SLA.
        """
        return None
