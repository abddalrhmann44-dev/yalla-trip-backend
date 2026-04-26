"""add_cash_on_arrival_and_deposit_fields

Revision ID: 76e03bf50558
Revises: b8cb13284b6f
Create Date: 2026-04-26 12:33:57.443544
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '76e03bf50558'
down_revision: Union[str, None] = 'b8cb13284b6f'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Wave 25 — hybrid online deposit + cash on arrival.

    Adds the host-controlled opt-in flag on properties and the
    booking-side bookkeeping the new payment workflow needs:

    * ``properties.cash_on_arrival_enabled`` — host opts in to the
      "pay deposit online + cash to me on arrival" flow.
    * ``bookings.deposit_amount`` / ``remaining_cash_amount`` — split
      of what the guest pays online vs. in cash.
    * ``bookings.cash_collection_status`` — state machine for the
      double-confirmation handshake (owner ✚ guest must both ack).
    * Three timestamps so we have an audit trail and can drive a
      48 h auto-dispute timer in Phase 3.

    The data migration backfills existing rows so legacy bookings
    look like "100 % online" (``deposit_amount = total_price``,
    ``status = not_applicable``).  This keeps the
    ``Payment.amount = booking.deposit_amount`` rule in
    ``payments.initiate`` correct for in-flight bookings.
    """

    # ── Properties: opt-in flag ──────────────────────────────
    op.add_column(
        "properties",
        sa.Column(
            "cash_on_arrival_enabled",
            sa.Boolean(),
            server_default=sa.text("false"),
            nullable=False,
        ),
    )

    # ── Bookings: deposit amounts ────────────────────────────
    op.add_column(
        "bookings",
        sa.Column(
            "deposit_amount",
            sa.Float(),
            server_default=sa.text("0"),
            nullable=False,
        ),
    )
    op.add_column(
        "bookings",
        sa.Column(
            "remaining_cash_amount",
            sa.Float(),
            server_default=sa.text("0"),
            nullable=False,
        ),
    )

    # ── Bookings: cash collection state machine ──────────────
    cash_status = sa.Enum(
        "not_applicable",
        "pending",
        "owner_confirmed",
        "guest_confirmed",
        "confirmed",
        "disputed",
        "no_show",
        name="cashcollectionstatus",
    )
    cash_status.create(op.get_bind(), checkfirst=True)
    op.add_column(
        "bookings",
        sa.Column(
            "cash_collection_status",
            cash_status,
            server_default=sa.text("'not_applicable'"),
            nullable=False,
        ),
    )

    # ── Bookings: confirmation timestamps ────────────────────
    op.add_column(
        "bookings",
        sa.Column(
            "owner_cash_confirmed_at",
            sa.DateTime(timezone=True),
            nullable=True,
        ),
    )
    op.add_column(
        "bookings",
        sa.Column(
            "guest_arrival_confirmed_at",
            sa.DateTime(timezone=True),
            nullable=True,
        ),
    )
    op.add_column(
        "bookings",
        sa.Column(
            "no_show_reported_at",
            sa.DateTime(timezone=True),
            nullable=True,
        ),
    )

    # ── Backfill existing rows as "100 % online" so the new
    # ``Payment.amount = booking.deposit_amount`` rule keeps working
    # for bookings that predate this migration.
    op.execute(
        "UPDATE bookings "
        "SET deposit_amount = total_price, "
        "    remaining_cash_amount = 0 "
        "WHERE deposit_amount = 0"
    )


def downgrade() -> None:
    op.drop_column("bookings", "no_show_reported_at")
    op.drop_column("bookings", "guest_arrival_confirmed_at")
    op.drop_column("bookings", "owner_cash_confirmed_at")
    op.drop_column("bookings", "cash_collection_status")
    sa.Enum(name="cashcollectionstatus").drop(op.get_bind(), checkfirst=True)
    op.drop_column("bookings", "remaining_cash_amount")
    op.drop_column("bookings", "deposit_amount")
    op.drop_column("properties", "cash_on_arrival_enabled")
