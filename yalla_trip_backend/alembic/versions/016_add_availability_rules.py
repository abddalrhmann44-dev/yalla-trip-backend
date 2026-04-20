"""Wave 14 – Host availability editor.

Adds ``availability_rules`` table for per-date pricing overrides,
minimum-stay rules, and closed-date markers.
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "016_add_availability_rules"
down_revision: Union[str, None] = "015_add_calendar_sync"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "availability_rules",
        sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column(
            "property_id",
            sa.Integer(),
            sa.ForeignKey("properties.id", ondelete="CASCADE"),
            nullable=False,
            index=True,
        ),
        sa.Column(
            "rule_type",
            sa.Enum("pricing", "min_stay", "closed", "note", name="ruletype"),
            nullable=False,
            index=True,
        ),
        sa.Column("start_date", sa.Date(), nullable=False),
        sa.Column("end_date", sa.Date(), nullable=False),
        sa.Column("price_override", sa.Float(), nullable=True),
        sa.Column("min_nights", sa.Integer(), nullable=True),
        sa.Column("label", sa.String(200), nullable=True),
        sa.Column("note", sa.Text(), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
        ),
        sa.UniqueConstraint(
            "property_id", "start_date", "end_date", "rule_type",
            name="uq_avail_rule_range_type",
        ),
    )


def downgrade() -> None:
    op.drop_table("availability_rules")
    op.execute("DROP TYPE IF EXISTS ruletype")
