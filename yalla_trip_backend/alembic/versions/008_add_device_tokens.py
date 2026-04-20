"""Add device_tokens table for multi-device FCM push.

Revision ID: 008_add_device_tokens
Revises: 007_add_cancellation_policy
Create Date: 2026-04-18
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

revision: str = "008_add_device_tokens"
down_revision: Union[str, None] = "007_add_cancellation_policy"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    bind = op.get_bind()
    postgresql.ENUM(
        "android", "ios", "web",
        name="deviceplatform",
    ).create(bind, checkfirst=True)

    op.create_table(
        "device_tokens",
        sa.Column("id", sa.Integer(), primary_key=True, index=True),
        sa.Column(
            "user_id",
            sa.Integer(),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            nullable=False,
            index=True,
        ),
        sa.Column("token", sa.String(length=512), nullable=False),
        sa.Column(
            "platform",
            postgresql.ENUM(
                "android", "ios", "web",
                name="deviceplatform",
                create_type=False,
            ),
            server_default="android",
            nullable=False,
        ),
        sa.Column("app_version", sa.String(length=32), nullable=True),
        sa.Column(
            "last_seen_at", sa.DateTime(timezone=True),
            server_default=sa.func.now(), nullable=False,
        ),
        sa.Column(
            "created_at", sa.DateTime(timezone=True),
            server_default=sa.func.now(), nullable=False,
        ),
        sa.UniqueConstraint(
            "user_id", "token", name="uq_device_token_user_token"
        ),
    )


def downgrade() -> None:
    op.drop_table("device_tokens")
    bind = op.get_bind()
    postgresql.ENUM(name="deviceplatform").drop(bind, checkfirst=True)
