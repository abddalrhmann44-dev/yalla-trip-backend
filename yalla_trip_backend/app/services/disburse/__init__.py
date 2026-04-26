"""Disbursement gateways — automated payout to host bank accounts.

Mirrors :pymod:`app.services.gateways` (payment side) but for the
*outgoing* leg: how the platform wires money from the merchant
escrow back out to the property owner.  Two implementations ship
out of the box:

* :class:`KashierDisburseGateway` — production, hits Kashier's
  Egyptian-licensed disbursement API.
* :class:`MockDisburseGateway` — local/dev, simulates the round-trip
  including the success webhook so you can exercise the full flow
  without burning real money.
"""

from app.services.disburse.base import (
    DisburseChannel,
    DisburseGateway,
    DisburseRequest,
    DisburseResult,
    DisburseResultStatus,
    DisburseWebhook,
)
from app.services.disburse.kashier import KashierDisburseGateway
from app.services.disburse.mock import MockDisburseGateway
from app.services.disburse.registry import get_disburse_gateway

__all__ = [
    "DisburseChannel",
    "DisburseGateway",
    "DisburseRequest",
    "DisburseResult",
    "DisburseResultStatus",
    "DisburseWebhook",
    "KashierDisburseGateway",
    "MockDisburseGateway",
    "get_disburse_gateway",
]
