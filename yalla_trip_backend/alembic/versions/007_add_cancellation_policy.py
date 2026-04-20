"""Add cancellation_policy to properties + partially_refunded payment state.

Revision ID: 007_add_cancellation_policy
Revises: 006_add_review_extras
Create Date: 2026-04-18
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

revision: str = "007_add_cancellation_policy"
down_revision: Union[str, None] = "006_add_review_extras"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    bind = op.get_bind()

    # New enum for the per-property cancellation rules.
    postgresql.ENUM(
        "flexible", "moderate", "strict",
        name="cancellationpolicy",
    ).create(bind, checkfirst=True)

    op.add_column(
        "properties",
        sa.Column(
            "cancellation_policy",
            postgresql.ENUM(
                "flexible", "moderate", "strict",
                name="cancellationpolicy",
                create_type=False,
            ),
            server_default="moderate",
            nullable=False,
        ),
    )

    # Extend the payments state enum with ``partially_refunded`` to
    # support cancellation tiers (50 % back, etc.).
    op.execute(
        "ALTER TYPE paymentstate ADD VALUE IF NOT EXISTS 'partially_refunded'"
    )

    # Also widen the booking payment_status enum to carry the same
    # semantic — some cancellations return a fraction of the total.
    op.execute(
        "ALTER TYPE paymentstatus ADD VALUE IF NOT EXISTS 'partially_refunded'"
    )

    op.add_column(
        "bookings",
        sa.Column("refund_amount", sa.Float(), nullable=True),
    )
    op.add_column(
        "bookings",
        sa.Column("cancelled_at", sa.DateTime(timezone=True), nullable=True),
    )
    op.add_column(
        "bookings",
        sa.Column(
            "cancellation_reason", sa.String(length=500), nullable=True
        ),
    )


def downgrade() -> None:
    op.drop_column("bookings", "cancellation_reason")
    op.drop_column("bookings", "cancelled_at")
    op.drop_column("bookings", "refund_amount")
    op.drop_column("properties", "cancellation_policy")
    # Note: we intentionally don't shrink the enum types on downgrade –
    # Postgres doesn't support removing enum values without an
    # elaborate "rename type / recreate" dance, and none of it buys
    # anything in practice.
