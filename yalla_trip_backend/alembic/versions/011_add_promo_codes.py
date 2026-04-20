"""Add promo_codes + promo_redemptions tables and booking.promo_discount.

Revision ID: 011_add_promo_codes
Revises: 010_add_reports
Create Date: 2026-04-19
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

revision: str = "011_add_promo_codes"
down_revision: Union[str, None] = "010_add_reports"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


_TYPE = sa.Enum("percent", "fixed", name="promo_type", create_type=True)


def upgrade() -> None:
    op.create_table(
        "promo_codes",
        sa.Column("id", sa.Integer(), primary_key=True, index=True),
        sa.Column("code", sa.String(32), nullable=False, unique=True, index=True),
        sa.Column("description", sa.Text(), nullable=True),
        sa.Column("type", _TYPE, nullable=False),
        sa.Column("value", sa.Float(), nullable=False),
        sa.Column("max_discount", sa.Float(), nullable=True),
        sa.Column("min_booking_amount", sa.Float(), nullable=True),
        sa.Column("max_uses", sa.Integer(), nullable=True),
        sa.Column("max_uses_per_user", sa.Integer(), nullable=True),
        sa.Column(
            "uses_count", sa.Integer(),
            server_default="0", nullable=False,
        ),
        sa.Column("valid_from", sa.DateTime(timezone=True), nullable=True),
        sa.Column("valid_until", sa.DateTime(timezone=True), nullable=True),
        sa.Column(
            "is_active", sa.Boolean(),
            server_default="true", nullable=False,
        ),
        sa.Column(
            "created_by_id", sa.Integer(),
            sa.ForeignKey("users.id", ondelete="SET NULL"),
            nullable=True,
        ),
        sa.Column(
            "created_at", sa.DateTime(timezone=True),
            server_default=sa.func.now(), nullable=False,
        ),
        sa.Column(
            "updated_at", sa.DateTime(timezone=True),
            server_default=sa.func.now(), nullable=False,
        ),
    )

    op.create_table(
        "promo_redemptions",
        sa.Column("id", sa.Integer(), primary_key=True, index=True),
        sa.Column(
            "promo_id", sa.Integer(),
            sa.ForeignKey("promo_codes.id", ondelete="CASCADE"),
            nullable=False, index=True,
        ),
        sa.Column(
            "user_id", sa.Integer(),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            nullable=False, index=True,
        ),
        sa.Column(
            "booking_id", sa.Integer(),
            sa.ForeignKey("bookings.id", ondelete="CASCADE"),
            nullable=False, index=True,
        ),
        sa.Column("discount_amount", sa.Float(), nullable=False),
        sa.Column("original_amount", sa.Float(), nullable=False),
        sa.Column(
            "created_at", sa.DateTime(timezone=True),
            server_default=sa.func.now(), nullable=False,
        ),
        sa.UniqueConstraint("booking_id", name="uq_promo_redemption_booking"),
    )

    # ── bookings.promo_discount ────────────────────────────────
    op.add_column(
        "bookings",
        sa.Column(
            "promo_discount", sa.Float(),
            server_default="0", nullable=False,
        ),
    )


def downgrade() -> None:
    op.drop_column("bookings", "promo_discount")
    op.drop_table("promo_redemptions")
    op.drop_table("promo_codes")
    postgresql.ENUM(name="promo_type").drop(op.get_bind(), checkfirst=True)
