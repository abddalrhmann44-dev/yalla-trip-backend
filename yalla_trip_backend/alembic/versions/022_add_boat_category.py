"""Wave 22 – Boat listings.

Extends the ``category`` enum with ``مركب`` and adds
``properties.trip_duration_hours`` for boats (hours per trip).
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "022_add_boat_category"
down_revision: Union[str, None] = "021_add_wallet_topup_type"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Postgres enum values must be appended via ALTER TYPE, outside of
    # a transaction block.
    with op.get_context().autocommit_block():
        op.execute("ALTER TYPE category ADD VALUE IF NOT EXISTS 'مركب'")

    op.add_column(
        "properties",
        sa.Column("trip_duration_hours", sa.Integer(), nullable=True),
    )


def downgrade() -> None:
    op.drop_column("properties", "trip_duration_hours")
    # Enum-value removal is a no-op: PostgreSQL cannot drop a single
    # enum value without rebuilding the type and orphaning dependent
    # rows.
