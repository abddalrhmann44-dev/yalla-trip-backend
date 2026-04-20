"""Add payments table (multi-gateway: Fawry, Paymob, COD).

Revision ID: 005_add_payments_table
Revises: 004_add_chat_tables
Create Date: 2026-04-18
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

revision: str = "005_add_payments_table"
down_revision: Union[str, None] = "004_add_chat_tables"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


# Use the postgresql-specific ENUM so ``create_type=False`` is honored
# — the generic ``sa.Enum`` ignores the flag when emitting
# ``CREATE TABLE`` through ``op.create_table``.
_provider = postgresql.ENUM(
    "fawry", "paymob", "cod",
    name="paymentprovider", create_type=False,
)
_method = postgresql.ENUM(
    "card", "wallet", "fawry_voucher", "instapay", "cod",
    name="paymentmethod", create_type=False,
)
_state = postgresql.ENUM(
    "pending", "processing", "paid", "failed",
    "refunded", "expired", "cancelled",
    name="paymentstate", create_type=False,
)


def upgrade() -> None:
    bind = op.get_bind()
    # Create the enum types first (idempotent).
    postgresql.ENUM(
        "fawry", "paymob", "cod", name="paymentprovider",
    ).create(bind, checkfirst=True)
    postgresql.ENUM(
        "card", "wallet", "fawry_voucher", "instapay", "cod",
        name="paymentmethod",
    ).create(bind, checkfirst=True)
    postgresql.ENUM(
        "pending", "processing", "paid", "failed",
        "refunded", "expired", "cancelled",
        name="paymentstate",
    ).create(bind, checkfirst=True)

    op.create_table(
        "payments",
        sa.Column("id", sa.Integer(), primary_key=True, index=True),
        sa.Column(
            "booking_id",
            sa.Integer(),
            sa.ForeignKey("bookings.id", ondelete="CASCADE"),
            nullable=False,
            index=True,
        ),
        sa.Column(
            "user_id",
            sa.Integer(),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            nullable=False,
            index=True,
        ),
        sa.Column("provider", _provider, nullable=False, index=True),
        sa.Column("method", _method, nullable=False),
        sa.Column(
            "state", _state,
            server_default="pending", nullable=False, index=True,
        ),
        sa.Column("amount", sa.Float(), nullable=False),
        sa.Column("currency", sa.String(length=3), server_default="EGP", nullable=False),
        sa.Column("merchant_ref", sa.String(length=64), nullable=False, index=True),
        sa.Column("provider_ref", sa.String(length=100), nullable=True, index=True),
        sa.Column("checkout_url", sa.String(length=2048), nullable=True),
        sa.Column("request_payload", sa.JSON(), nullable=True),
        sa.Column("response_payload", sa.JSON(), nullable=True),
        sa.Column("error_message", sa.String(length=1024), nullable=True),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("paid_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
    )


def downgrade() -> None:
    op.drop_table("payments")
    bind = op.get_bind()
    _state.drop(bind, checkfirst=True)
    _method.drop(bind, checkfirst=True)
    _provider.drop(bind, checkfirst=True)
