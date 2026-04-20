"""Add reports / dispute queue table.

Revision ID: 010_add_reports
Revises: 009_add_refresh_tokens
Create Date: 2026-04-18
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

revision: str = "010_add_reports"
down_revision: Union[str, None] = "009_add_refresh_tokens"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


_TARGET = sa.Enum(
    "property", "user", "review", "booking",
    name="report_target", create_type=True,
)
_REASON = sa.Enum(
    "spam", "inappropriate", "fraud", "fake_listing",
    "abuse", "not_as_described", "payment_issue", "other",
    name="report_reason", create_type=True,
)
_STATUS = sa.Enum(
    "pending", "resolved", "dismissed",
    name="report_status", create_type=True,
)


def upgrade() -> None:
    op.create_table(
        "reports",
        sa.Column("id", sa.Integer(), primary_key=True, index=True),
        sa.Column(
            "reporter_id", sa.Integer(),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            nullable=False, index=True,
        ),
        sa.Column("target_type", _TARGET, nullable=False, index=True),
        sa.Column("target_id", sa.Integer(), nullable=False, index=True),
        sa.Column("reason", _REASON, nullable=False),
        sa.Column("details", sa.Text(), nullable=True),
        sa.Column(
            "status", _STATUS,
            server_default="pending", nullable=False, index=True,
        ),
        sa.Column("resolution_notes", sa.Text(), nullable=True),
        sa.Column(
            "resolved_by_id", sa.Integer(),
            sa.ForeignKey("users.id", ondelete="SET NULL"),
            nullable=True,
        ),
        sa.Column("resolved_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column(
            "created_at", sa.DateTime(timezone=True),
            server_default=sa.func.now(), nullable=False,
        ),
    )
    op.create_index("ix_reports_target", "reports", ["target_type", "target_id"])


def downgrade() -> None:
    op.drop_index("ix_reports_target", table_name="reports")
    op.drop_table("reports")
    bind = op.get_bind()
    postgresql.ENUM(name="report_status").drop(bind, checkfirst=True)
    postgresql.ENUM(name="report_reason").drop(bind, checkfirst=True)
    postgresql.ENUM(name="report_target").drop(bind, checkfirst=True)
