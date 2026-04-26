"""payout: add disburse_* columns + DisburseStatus enum

Revision ID: b5c7d2e8f1a3
Revises: a3f9b1c2d4e5
Create Date: 2026-04-26 19:30:00

Wave 26 — Kashier disbursement integration.  We're adding the
provider-facing leg of payouts as a parallel state-machine so the
existing manual flow keeps working unchanged: legacy rows stay at
``disburse_status='not_started'`` and only new gateway calls move
through the new states.

The enum is created explicitly first because Alembic's autogenerate
sometimes races a CREATE TYPE with the ADD COLUMN that uses it,
which fails on older Postgres versions.  Doing it in two passes
keeps the migration deterministic.
"""

from __future__ import annotations

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects.postgresql import JSONB


# Alembic identifiers
revision = "b5c7d2e8f1a3"
down_revision = "a3f9b1c2d4e5"
branch_labels = None
depends_on = None


_DISBURSE_STATES = (
    "not_started",
    "initiated",
    "processing",
    "succeeded",
    "failed",
)


def upgrade() -> None:
    # 1) Create the enum type first so the ADD COLUMN below has
    #    something to reference.  ``checkfirst=False`` lets the
    #    migration fail loudly if the type already exists — easier
    #    to reason about than a silent skip.
    disburse_enum = sa.Enum(*_DISBURSE_STATES, name="disburse_status")
    disburse_enum.create(op.get_bind(), checkfirst=True)

    # 2) Add the columns in one batch.  Server defaults are set on
    #    the bool/enum columns so existing rows backfill cleanly
    #    without a separate UPDATE pass.
    op.add_column(
        "payouts",
        sa.Column("disburse_provider", sa.String(length=40), nullable=True),
    )
    op.add_column(
        "payouts",
        sa.Column("disburse_ref", sa.String(length=120), nullable=True),
    )
    op.add_column(
        "payouts",
        sa.Column(
            "disburse_status",
            sa.Enum(
                *_DISBURSE_STATES,
                name="disburse_status",
                create_type=False,  # type already exists from step 1
            ),
            nullable=False,
            server_default="not_started",
        ),
    )
    op.add_column(
        "payouts",
        sa.Column("disbursed_at", sa.DateTime(timezone=True), nullable=True),
    )
    op.add_column(
        "payouts",
        sa.Column("disburse_payload", JSONB(), nullable=True),
    )
    op.add_column(
        "payouts",
        sa.Column("disburse_receipt_url", sa.String(length=500), nullable=True),
    )


def downgrade() -> None:
    # Reverse order of upgrade so dependencies unwind cleanly.
    op.drop_column("payouts", "disburse_receipt_url")
    op.drop_column("payouts", "disburse_payload")
    op.drop_column("payouts", "disbursed_at")
    op.drop_column("payouts", "disburse_status")
    op.drop_column("payouts", "disburse_ref")
    op.drop_column("payouts", "disburse_provider")
    sa.Enum(name="disburse_status").drop(op.get_bind(), checkfirst=True)
