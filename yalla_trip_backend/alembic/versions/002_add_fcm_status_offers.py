"""Add fcm_token to users, status/admin_note/offer fields to properties.

Revision ID: 002_add_fcm_status_offers
Revises: 001_initial
Create Date: 2025-04-15
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

revision: str = "002_add_fcm_status_offers"
down_revision: Union[str, None] = "001_initial"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

# Enum for property status
_property_status = sa.Enum("pending", "approved", "rejected", "needs_edit", name="propertystatus")


def upgrade() -> None:
    # ── Users: add fcm_token ──────────────────────────────
    op.add_column("users", sa.Column("fcm_token", sa.String(512), nullable=True))

    # ── Properties: add status, admin_note, offer fields ──
    _property_status.create(op.get_bind(), checkfirst=True)
    op.add_column(
        "properties",
        sa.Column("status", _property_status, server_default="pending", nullable=False),
    )
    op.add_column("properties", sa.Column("admin_note", sa.Text(), nullable=True))
    op.add_column("properties", sa.Column("offer_price", sa.Float(), nullable=True))
    op.add_column(
        "properties",
        sa.Column("offer_start", sa.DateTime(timezone=True), nullable=True),
    )
    op.add_column(
        "properties",
        sa.Column("offer_end", sa.DateTime(timezone=True), nullable=True),
    )


def downgrade() -> None:
    op.drop_column("properties", "offer_end")
    op.drop_column("properties", "offer_start")
    op.drop_column("properties", "offer_price")
    op.drop_column("properties", "admin_note")
    op.drop_column("properties", "status")
    _property_status.drop(op.get_bind(), checkfirst=True)
    op.drop_column("users", "fcm_token")
