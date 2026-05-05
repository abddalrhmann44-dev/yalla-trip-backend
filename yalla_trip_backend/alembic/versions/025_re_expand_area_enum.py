"""Re-apply Area enum expansion (safety net).

Revision ID: 025a_re_expand_area
Revises: 024a_expand_area

The previous migration (024) may have been recorded in alembic_version
without actually adding the values to the PostgreSQL enum (raw string
vs sa.text() issue with SQLAlchemy 2.x).  This migration re-runs the
ALTER TYPE statements — ``IF NOT EXISTS`` makes them safe to repeat.
"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op


revision: str = "025a_re_expand_area"
down_revision: Union[str, None] = "024a_expand_area"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

_ALL_NEW_AREAS = [
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
    # Must run outside a transaction for ADD VALUE on PG < 12.
    op.execute(sa.text("COMMIT"))
    for area in _ALL_NEW_AREAS:
        op.execute(sa.text(
            f"ALTER TYPE area ADD VALUE IF NOT EXISTS '{area}'"
        ))


def downgrade() -> None:
    pass
