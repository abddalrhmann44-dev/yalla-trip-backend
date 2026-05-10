"""Wave 30 — admin-tunable platform settings.

Revision ID: j0e5f6a7b8c9
Revises: i9d4e5f6a7b8

Creates the singleton ``platform_settings`` table that backs the
admin Pricing-Rules page.  Settings the platform exposes:

  - platform_fee_percent       — commission charged on every booking
  - deposit_percent_default    — default deposit % when host doesn't override
  - payout_hold_days           — host payout delay after check-out
  - wallet_min_redeem_subtotal — wallet redemption guard
  - referral_reward_egp        — referrer reward on invitee signup
  - referral_reward_cap        — max rewarded referrals per user

The table holds exactly one row (id=1).  We seed it on upgrade so
the first admin call to ``GET /admin/settings`` always returns the
defaults rather than 404.
"""

from __future__ import annotations

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op


revision: str = "j0e5f6a7b8c9"
down_revision: Union[str, None] = "i9d4e5f6a7b8"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "platform_settings",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column(
            "platform_fee_percent", sa.Float(),
            nullable=False, server_default="10.0",
        ),
        sa.Column(
            "deposit_percent_default", sa.Float(),
            nullable=False, server_default="20.0",
        ),
        sa.Column(
            "payout_hold_days", sa.Integer(),
            nullable=False, server_default="1",
        ),
        sa.Column(
            "wallet_min_redeem_subtotal", sa.Float(),
            nullable=False, server_default="3000.0",
        ),
        sa.Column(
            "referral_reward_egp", sa.Float(),
            nullable=False, server_default="100.0",
        ),
        sa.Column(
            "referral_reward_cap", sa.Integer(),
            nullable=False, server_default="3",
        ),
        sa.Column("last_change_note", sa.Text(), nullable=True),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.text("CURRENT_TIMESTAMP"),
        ),
        sa.Column("updated_by_name", sa.String(length=120), nullable=True),
    )
    # Seed singleton row.
    op.execute(
        "INSERT INTO platform_settings "
        "(id, platform_fee_percent, deposit_percent_default, payout_hold_days, "
        "wallet_min_redeem_subtotal, referral_reward_egp, referral_reward_cap) "
        "VALUES (1, 10.0, 20.0, 1, 3000.0, 100.0, 3)"
    )


def downgrade() -> None:
    op.drop_table("platform_settings")
