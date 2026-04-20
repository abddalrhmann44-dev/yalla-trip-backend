"""Add owner_response + moderation fields to reviews.

Revision ID: 006_add_review_extras
Revises: 005_add_payments_table
Create Date: 2026-04-18
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

revision: str = "006_add_review_extras"
down_revision: Union[str, None] = "005_add_payments_table"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "reviews",
        sa.Column("owner_response", sa.Text(), nullable=True),
    )
    op.add_column(
        "reviews",
        sa.Column(
            "owner_response_at",
            sa.DateTime(timezone=True),
            nullable=True,
        ),
    )
    op.add_column(
        "reviews",
        sa.Column(
            "is_hidden",
            sa.Boolean(),
            server_default=sa.false(),
            nullable=False,
        ),
    )
    op.add_column(
        "reviews",
        sa.Column(
            "report_count",
            sa.Integer(),
            server_default="0",
            nullable=False,
        ),
    )
    op.create_index(
        "ix_reviews_is_hidden",
        "reviews",
        ["is_hidden"],
    )


def downgrade() -> None:
    op.drop_index("ix_reviews_is_hidden", table_name="reviews")
    op.drop_column("reviews", "report_count")
    op.drop_column("reviews", "is_hidden")
    op.drop_column("reviews", "owner_response_at")
    op.drop_column("reviews", "owner_response")
