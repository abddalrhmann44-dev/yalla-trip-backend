"""Expand Area enum with 10 new Egyptian destinations.

Revision ID: 024a_expand_area
Revises: f6a1b2c3d4e5

Adds: العلمين الجديدة, مرسى مطروح, دهب, القاهرة, اسكندرية,
      الفيوم, سهل حشيش, مرسى علم, الأقصر, أسوان
"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op


revision: str = "024a_expand_area"
down_revision: Union[str, None] = "f6a1b2c3d4e5"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

# New values to add to the PostgreSQL 'area' enum.
_NEW_AREAS = [
    "العلمين الجديدة",
    "مرسى مطروح",
    "دهب",
    "القاهرة",
    "اسكندرية",
    "الفيوم",
    "سهل حشيش",
    "مرسى علم",
    "الأقصر",
    "أسوان",
]


def upgrade() -> None:
    # ``ALTER TYPE … ADD VALUE`` cannot run inside a normal Alembic
    # transaction on PG < 12.  Commit the migration transaction first,
    # add the values, then let Alembic continue.
    op.execute(sa.text("COMMIT"))
    for area in _NEW_AREAS:
        op.execute(sa.text(
            f"ALTER TYPE area ADD VALUE IF NOT EXISTS '{area}'"
        ))


def downgrade() -> None:
    # PostgreSQL does not support removing enum values.  A full
    # migration to a new enum type would be required; left as a
    # no-op since we never intend to drop these areas.
    pass
