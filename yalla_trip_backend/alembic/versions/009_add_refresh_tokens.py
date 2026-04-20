"""Add refresh_tokens table for rotation + session tracking.

Revision ID: 009_add_refresh_tokens
Revises: 008_add_device_tokens
Create Date: 2026-04-18
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

revision: str = "009_add_refresh_tokens"
down_revision: Union[str, None] = "008_add_device_tokens"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "refresh_tokens",
        sa.Column("id", sa.Integer(), primary_key=True, index=True),
        sa.Column(
            "user_id", sa.Integer(),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            nullable=False, index=True,
        ),
        sa.Column(
            "jti", sa.String(length=64), unique=True, index=True, nullable=False
        ),
        sa.Column("family_id", sa.String(length=64), nullable=False),
        sa.Column(
            "used_at", sa.DateTime(timezone=True), nullable=True
        ),
        sa.Column(
            "revoked", sa.Boolean(),
            server_default=sa.text("false"), nullable=False,
        ),
        sa.Column("revoked_reason", sa.String(length=120), nullable=True),
        sa.Column("user_agent", sa.String(length=256), nullable=True),
        sa.Column("ip_address", sa.String(length=64), nullable=True),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column(
            "created_at", sa.DateTime(timezone=True),
            server_default=sa.func.now(), nullable=False,
        ),
    )
    op.create_index(
        "ix_refresh_tokens_family", "refresh_tokens", ["family_id"]
    )
    op.create_index(
        "ix_refresh_tokens_user_active",
        "refresh_tokens",
        ["user_id", "revoked"],
    )


def downgrade() -> None:
    op.drop_index("ix_refresh_tokens_user_active", table_name="refresh_tokens")
    op.drop_index("ix_refresh_tokens_family", table_name="refresh_tokens")
    op.drop_table("refresh_tokens")
