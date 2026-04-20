"""Add favorites table and id-document fields to properties (KYC).

Revision ID: 003_add_favorites_and_id_docs
Revises: 002_add_fcm_status_offers
Create Date: 2026-04-18
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

revision: str = "003_add_favorites_and_id_docs"
down_revision: Union[str, None] = "002_add_fcm_status_offers"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # ── favorites table ───────────────────────────────────
    op.create_table(
        "favorites",
        sa.Column("id", sa.Integer(), primary_key=True, index=True),
        sa.Column(
            "user_id",
            sa.Integer(),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            nullable=False,
            index=True,
        ),
        sa.Column(
            "property_id",
            sa.Integer(),
            sa.ForeignKey("properties.id", ondelete="CASCADE"),
            nullable=False,
            index=True,
        ),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
        sa.UniqueConstraint(
            "user_id", "property_id", name="uq_favorite_user_property"
        ),
    )

    # ── KYC document URLs on properties ───────────────────
    op.add_column(
        "properties",
        sa.Column("id_document_front_url", sa.String(length=512), nullable=True),
    )
    op.add_column(
        "properties",
        sa.Column("id_document_back_url", sa.String(length=512), nullable=True),
    )


def downgrade() -> None:
    op.drop_column("properties", "id_document_back_url")
    op.drop_column("properties", "id_document_front_url")
    op.drop_table("favorites")
