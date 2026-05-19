"""Wave 31 — admin-controlled administrative fee charged to the guest.

Revision ID: m2g7h8i9j0k1
Revises: k1f6a7b8c9d0

Adds:
  * ``platform_settings.admin_fee_percent`` (Float, default 0.0) — the
    percentage the admin can configure from the Pricing-Rules page.
  * ``bookings.admin_fee`` (Float, default 0.0) — the absolute EGP
    amount stamped on each booking at checkout time so receipts and
    historical reports remain accurate even if the percent is later
    changed by the admin.

Unlike ``platform_fee`` (which is deducted from the *host's* payout),
``admin_fee`` is added on top of the subtotal and **paid by the guest**.
That keeps the host's economics unchanged while letting the platform
recover infrastructure / KYC / payment-gateway costs from the buyer.
"""

from __future__ import annotations

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op


revision: str = "m2g7h8i9j0k1"
down_revision: Union[str, None] = "k1f6a7b8c9d0"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # 1. Add admin_fee_percent to the singleton settings row.
    op.add_column(
        "platform_settings",
        sa.Column(
            "admin_fee_percent",
            sa.Float(),
            nullable=False,
            server_default="0.0",
        ),
    )

    # 2. Stamp the absolute fee on every booking row so receipts stay
    #    correct after future percentage changes.
    op.add_column(
        "bookings",
        sa.Column(
            "admin_fee",
            sa.Float(),
            nullable=False,
            server_default="0.0",
        ),
    )


def downgrade() -> None:
    op.drop_column("bookings", "admin_fee")
    op.drop_column("platform_settings", "admin_fee_percent")
