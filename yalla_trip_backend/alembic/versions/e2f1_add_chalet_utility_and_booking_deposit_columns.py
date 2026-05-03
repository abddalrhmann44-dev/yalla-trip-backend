"""Chalet utility fees on properties + per-booking deposit snapshot.

Revision ID: e2f1a8b9c0d4
Revises: d8e1f7c4a2b9

The ORM already maps these columns; production failed with
``UndefinedColumnError: bookings.electricity_fee`` when loading
``User.bookings_as_guest`` (e.g. during ``/auth/verify-token``).
"""

from __future__ import annotations

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op


revision: str = "e2f1a8b9c0d4"
down_revision: Union[str, None] = "d8e1f7c4a2b9"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # ── properties: chalet utility line items (already on SQLAlchemy model)
    op.add_column(
        "properties",
        sa.Column(
            "electricity_fee",
            sa.Float(),
            server_default=sa.text("0"),
            nullable=False,
        ),
    )
    op.add_column(
        "properties",
        sa.Column(
            "water_fee",
            sa.Float(),
            server_default=sa.text("0"),
            nullable=False,
        ),
    )
    op.add_column(
        "properties",
        sa.Column(
            "security_deposit",
            sa.Float(),
            server_default=sa.text("0"),
            nullable=False,
        ),
    )

    # ── bookings: snapshot at booking time + deposit lifecycle
    deposit_status = sa.Enum(
        "held",
        "refunded",
        "deducted",
        name="depositstatus",
    )
    deposit_status.create(op.get_bind(), checkfirst=True)

    op.add_column(
        "bookings",
        sa.Column(
            "electricity_fee",
            sa.Float(),
            server_default=sa.text("0"),
            nullable=False,
        ),
    )
    op.add_column(
        "bookings",
        sa.Column(
            "water_fee",
            sa.Float(),
            server_default=sa.text("0"),
            nullable=False,
        ),
    )
    op.add_column(
        "bookings",
        sa.Column(
            "security_deposit",
            sa.Float(),
            server_default=sa.text("0"),
            nullable=False,
        ),
    )
    op.add_column(
        "bookings",
        sa.Column(
            "deposit_status",
            deposit_status,
            server_default=sa.text("'held'"),
            nullable=False,
        ),
    )

    # Legacy rows had no security deposit line; treat as already settled.
    op.execute(
        "UPDATE bookings SET deposit_status = 'refunded' "
        "WHERE security_deposit = 0"
    )


def downgrade() -> None:
    op.drop_column("bookings", "deposit_status")
    sa.Enum(name="depositstatus").drop(op.get_bind(), checkfirst=True)
    op.drop_column("bookings", "security_deposit")
    op.drop_column("bookings", "water_fee")
    op.drop_column("bookings", "electricity_fee")

    op.drop_column("properties", "security_deposit")
    op.drop_column("properties", "water_fee")
    op.drop_column("properties", "electricity_fee")
