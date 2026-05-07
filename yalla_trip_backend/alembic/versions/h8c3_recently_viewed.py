"""Wave 28 — Add ``recently_viewed`` table.

Revision ID: h8c3d4e5f6a7
Revises: g7b2c8d9e1f3

Creates the per-user property view log used by the home page's
"Recently viewed" carousel.  One row per (user, property) — re-views
update the existing row's ``viewed_at`` timestamp instead of inserting
a duplicate.

Idempotent: ``CREATE TABLE IF NOT EXISTS`` plus ``CREATE INDEX IF NOT
EXISTS`` so re-running the migration on an already-patched database is
a no-op.
"""

from __future__ import annotations

from typing import Sequence, Union

from alembic import op


# revision identifiers, used by Alembic.
revision: str = "h8c3d4e5f6a7"
down_revision: Union[str, None] = "g7b2c8d9e1f3"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.execute(
        """
        CREATE TABLE IF NOT EXISTS recently_viewed (
            id SERIAL PRIMARY KEY,
            user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
            property_id INTEGER NOT NULL REFERENCES properties(id) ON DELETE CASCADE,
            viewed_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
            CONSTRAINT uq_recently_viewed_user_property UNIQUE (user_id, property_id)
        );
        """
    )
    op.execute(
        "CREATE INDEX IF NOT EXISTS ix_recently_viewed_user_id "
        "ON recently_viewed (user_id);"
    )
    op.execute(
        "CREATE INDEX IF NOT EXISTS ix_recently_viewed_property_id "
        "ON recently_viewed (property_id);"
    )
    # Composite index that backs the GET endpoint's "latest 10 per user"
    # query — cheaper than scanning by user_id alone then sorting.
    op.execute(
        "CREATE INDEX IF NOT EXISTS ix_recently_viewed_user_viewed_at "
        "ON recently_viewed (user_id, viewed_at DESC);"
    )


def downgrade() -> None:
    op.execute("DROP TABLE IF EXISTS recently_viewed CASCADE;")
