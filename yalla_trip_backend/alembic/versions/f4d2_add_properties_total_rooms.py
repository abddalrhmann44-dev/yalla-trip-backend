"""Add properties.total_rooms (ORM column was never migrated).

Revision ID: f4d2e8a1b3c5
Revises: e2f1a8b9c0d4

Fixes ``UndefinedColumnError: column properties.total_rooms does not exist``
when loading properties (e.g. during login / token verify).
"""

from __future__ import annotations

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op


revision: str = "f4d2e8a1b3c5"
down_revision: Union[str, None] = "e2f1a8b9c0d4"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "properties",
        sa.Column(
            "total_rooms",
            sa.Integer(),
            server_default=sa.text("1"),
            nullable=False,
        ),
    )


def downgrade() -> None:
    op.drop_column("properties", "total_rooms")
