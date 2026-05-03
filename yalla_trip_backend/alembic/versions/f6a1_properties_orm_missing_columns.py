"""Backfill properties columns that exist on the ORM but had no / split migrations.

Revision ID: f6a1b2c3d4e5
Revises: e2f1a8b9c0d4

Adds (idempotent on PostgreSQL 11+):

* ``total_rooms`` — hotel / multi-room inventory (default 1).
* ``closing_time`` — optional ``HH:MM`` for same-day listings.
* ``services`` — optional JSONB list of structured add-ons.

Earlier revisions ``f4d2e8a1b3c5`` and ``f5e3b2c4d6e8`` were superseded by this
single migration.  If ``alembic_version`` still lists either of those IDs,
stamp back to ``e2f1a8b9c0d4`` *once* (columns may already exist), then run
``alembic upgrade head``::

    alembic stamp e2f1a8b9c0d4
    alembic upgrade head

``ADD COLUMN IF NOT EXISTS`` keeps this safe when columns are already present.
"""

from __future__ import annotations

from typing import Sequence, Union

from alembic import op


revision: str = "f6a1b2c3d4e5"
down_revision: Union[str, None] = "e2f1a8b9c0d4"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.execute(
        "ALTER TABLE properties ADD COLUMN IF NOT EXISTS total_rooms integer "
        "NOT NULL DEFAULT 1"
    )
    op.execute(
        "ALTER TABLE properties ADD COLUMN IF NOT EXISTS closing_time varchar(5)"
    )
    op.execute("ALTER TABLE properties ADD COLUMN IF NOT EXISTS services jsonb")


def downgrade() -> None:
    op.execute("ALTER TABLE properties DROP COLUMN IF EXISTS services")
    op.execute("ALTER TABLE properties DROP COLUMN IF EXISTS closing_time")
    op.execute("ALTER TABLE properties DROP COLUMN IF EXISTS total_rooms")
