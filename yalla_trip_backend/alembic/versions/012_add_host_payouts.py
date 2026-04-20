"""Add host_bank_accounts + payouts + payout_items + booking.payout_status.

Revision ID: 012_add_host_payouts
Revises: 011_add_promo_codes
Create Date: 2026-04-19
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

revision: str = "012_add_host_payouts"
down_revision: Union[str, None] = "011_add_promo_codes"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


_BANK_TYPE = sa.Enum(
    "iban", "wallet", "instapay",
    name="bank_account_type", create_type=True,
)
_PAYOUT_STATUS = sa.Enum(
    "pending", "processing", "paid", "failed",
    name="payout_status", create_type=True,
)


def upgrade() -> None:
    # ── host_bank_accounts ─────────────────────────────────────
    op.create_table(
        "host_bank_accounts",
        sa.Column("id", sa.Integer(), primary_key=True, index=True),
        sa.Column(
            "host_id", sa.Integer(),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            nullable=False, index=True,
        ),
        sa.Column("type", _BANK_TYPE, nullable=False),
        sa.Column("account_name", sa.String(200), nullable=False),
        sa.Column("bank_name", sa.String(100), nullable=True),
        sa.Column("iban", sa.String(34), nullable=True),
        sa.Column("wallet_phone", sa.String(20), nullable=True),
        sa.Column("instapay_address", sa.String(100), nullable=True),
        sa.Column(
            "is_default", sa.Boolean(),
            server_default="false", nullable=False,
        ),
        sa.Column(
            "verified", sa.Boolean(),
            server_default="false", nullable=False,
        ),
        sa.Column(
            "created_at", sa.DateTime(timezone=True),
            server_default=sa.func.now(), nullable=False,
        ),
        sa.Column(
            "updated_at", sa.DateTime(timezone=True),
            server_default=sa.func.now(), nullable=False,
        ),
    )

    # ── payouts ────────────────────────────────────────────────
    op.create_table(
        "payouts",
        sa.Column("id", sa.Integer(), primary_key=True, index=True),
        sa.Column(
            "host_id", sa.Integer(),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            nullable=False, index=True,
        ),
        sa.Column(
            "bank_account_id", sa.Integer(),
            sa.ForeignKey("host_bank_accounts.id", ondelete="SET NULL"),
            nullable=True,
        ),
        sa.Column("total_amount", sa.Float(), nullable=False),
        sa.Column("cycle_start", sa.Date(), nullable=False),
        sa.Column("cycle_end", sa.Date(), nullable=False),
        sa.Column(
            "status", _PAYOUT_STATUS,
            server_default="pending", nullable=False,
        ),
        sa.Column("reference_number", sa.String(100), nullable=True),
        sa.Column("admin_notes", sa.Text(), nullable=True),
        sa.Column(
            "processed_by_id", sa.Integer(),
            sa.ForeignKey("users.id", ondelete="SET NULL"),
            nullable=True,
        ),
        sa.Column(
            "processed_at", sa.DateTime(timezone=True),
            nullable=True,
        ),
        sa.Column(
            "created_at", sa.DateTime(timezone=True),
            server_default=sa.func.now(), nullable=False,
        ),
        sa.Column(
            "updated_at", sa.DateTime(timezone=True),
            server_default=sa.func.now(), nullable=False,
        ),
    )

    # ── payout_items ───────────────────────────────────────────
    op.create_table(
        "payout_items",
        sa.Column("id", sa.Integer(), primary_key=True, index=True),
        sa.Column(
            "payout_id", sa.Integer(),
            sa.ForeignKey("payouts.id", ondelete="CASCADE"),
            nullable=False, index=True,
        ),
        sa.Column(
            "booking_id", sa.Integer(),
            sa.ForeignKey("bookings.id", ondelete="CASCADE"),
            nullable=False, index=True,
        ),
        sa.Column("amount", sa.Float(), nullable=False),
        sa.Column(
            "created_at", sa.DateTime(timezone=True),
            server_default=sa.func.now(), nullable=False,
        ),
        sa.UniqueConstraint("booking_id", name="uq_payout_item_booking"),
    )

    # ── bookings.payout_status ─────────────────────────────────
    op.add_column(
        "bookings",
        sa.Column(
            "payout_status", sa.String(16),
            server_default="unpaid", nullable=False,
        ),
    )
    op.create_index(
        "ix_bookings_payout_status", "bookings", ["payout_status"],
    )


def downgrade() -> None:
    op.drop_index("ix_bookings_payout_status", table_name="bookings")
    op.drop_column("bookings", "payout_status")
    op.drop_table("payout_items")
    op.drop_table("payouts")
    op.drop_table("host_bank_accounts")
    postgresql.ENUM(name="payout_status").drop(op.get_bind(), checkfirst=True)
    postgresql.ENUM(name="bank_account_type").drop(op.get_bind(), checkfirst=True)
