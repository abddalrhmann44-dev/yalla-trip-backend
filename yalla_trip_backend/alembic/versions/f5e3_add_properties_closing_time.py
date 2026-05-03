"""Add properties.closing_time (ORM field was never migrated).

Revision ID: f5e3b2c4d6e8
Revises: f4d2e8a1b3c5

Optional HH:MM same-day checkout cutoff for categories that use it.
Fixes ``UndefinedColumnError: column properties.closing_time does not exist``.
"""

from __future__ import annotations

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op


revision: str = "f5e3b2c4d6e8"
down_revision: Union[str, None] = "f4d2e8a1b3c5"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "properties",
        sa.Column("closing_time", sa.String(5), nullable=True),
    )


def downgrade() -> None:
    op.drop_column("properties", "closing_time")
