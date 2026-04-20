"""Add wallets, wallet_transactions, referrals + user.referral_code.

Revision ID: 014_add_wallet
Revises: 013_add_audit_log
Create Date: 2026-04-19
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

revision: str = "014_add_wallet"
down_revision: Union[str, None] = "013_add_audit_log"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def _wallet_txn_type(create_type: bool) -> sa.Enum:
    return sa.Enum(
        "referral_bonus", "signup_bonus", "booking_refund",
        "booking_redeem", "admin_adjust",
        name="wallettxntype", create_type=create_type,
    )


def _referral_status(create_type: bool) -> sa.Enum:
    return sa.Enum(
        "pending", "rewarded", "expired",
        name="referralstatus", create_type=create_type,
    )


def upgrade() -> None:
    # Let the first column-using table create the enum type.  All
    # subsequent references use ``create_type=False`` so Postgres
    # doesn't raise ``DuplicateObject``.

    # ── wallets ──────────────────────────────────────────────
    op.create_table(
        "wallets",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column(
            "user_id", sa.Integer(),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            nullable=False, unique=True, index=True,
        ),
        sa.Column("balance", sa.Float(), nullable=False, server_default="0"),
        sa.Column(
            "lifetime_earned", sa.Float(), nullable=False, server_default="0",
        ),
        sa.Column(
            "lifetime_spent", sa.Float(), nullable=False, server_default="0",
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

    # ── referrals ────────────────────────────────────────────
    op.create_table(
        "referrals",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column(
            "referrer_id", sa.Integer(),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            nullable=False, index=True,
        ),
        sa.Column(
            "invitee_id", sa.Integer(),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("referral_code", sa.String(32), nullable=False, index=True),
        sa.Column(
            "status", _referral_status(create_type=True),
            server_default="pending", nullable=False, index=True,
        ),
        sa.Column("reward_amount", sa.Float(), nullable=True),
        sa.Column(
            "qualifying_booking_id", sa.Integer(),
            sa.ForeignKey("bookings.id", ondelete="SET NULL"),
            nullable=True,
        ),
        sa.Column(
            "rewarded_at", sa.DateTime(timezone=True), nullable=True,
        ),
        sa.Column(
            "created_at", sa.DateTime(timezone=True),
            server_default=sa.func.now(), nullable=False, index=True,
        ),
        sa.UniqueConstraint("invitee_id", name="uq_referrals_invitee"),
    )

    # ── wallet_transactions ──────────────────────────────────
    op.create_table(
        "wallet_transactions",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column(
            "wallet_id", sa.Integer(),
            sa.ForeignKey("wallets.id", ondelete="CASCADE"),
            nullable=False, index=True,
        ),
        sa.Column("amount", sa.Float(), nullable=False),
        sa.Column(
            "type", _wallet_txn_type(create_type=True),
            nullable=False, index=True,
        ),
        sa.Column("balance_after", sa.Float(), nullable=False),
        sa.Column("description", sa.String(500), nullable=True),
        sa.Column(
            "booking_id", sa.Integer(),
            sa.ForeignKey("bookings.id", ondelete="SET NULL"),
            nullable=True, index=True,
        ),
        sa.Column(
            "referral_id", sa.Integer(),
            sa.ForeignKey("referrals.id", ondelete="SET NULL"),
            nullable=True, index=True,
        ),
        sa.Column(
            "admin_id", sa.Integer(),
            sa.ForeignKey("users.id", ondelete="SET NULL"),
            nullable=True,
        ),
        sa.Column(
            "created_at", sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False, index=True,
        ),
    )

    # ── user.referral_code + booking.wallet_discount ────────
    op.add_column(
        "users",
        sa.Column("referral_code", sa.String(16), nullable=True, unique=True),
    )
    op.create_index(
        "ix_users_referral_code", "users", ["referral_code"], unique=True,
    )

    op.add_column(
        "bookings",
        sa.Column(
            "wallet_discount", sa.Float(),
            nullable=False, server_default="0",
        ),
    )


def downgrade() -> None:
    op.drop_column("bookings", "wallet_discount")
    op.drop_index("ix_users_referral_code", table_name="users")
    op.drop_column("users", "referral_code")
    op.drop_table("wallet_transactions")
    op.drop_table("referrals")
    op.drop_table("wallets")
    bind = op.get_bind()
    _referral_status(create_type=False).drop(bind, checkfirst=True)
    _wallet_txn_type(create_type=False).drop(bind, checkfirst=True)
