"""rename category 'بيت شاطئ' → 'رحلة يوم واحد' (beach_house → day_use)

Revision ID: a3f9b1c2d4e5
Revises: 76e03bf50558
Create Date: 2026-04-26 18:50:00

Wave 25.5 — the original "Beach House" category turned out to be a
misleading label.  The platform mostly serves Egyptian properties
where the equivalent product is a *day-use* (دخول وخروج فى نفس
اليوم بدون مبيت) — chalet pools, beach passes, etc.  No real
inventory was ever filed under "بيت شاطئ" so we can rename the enum
value safely without a data backfill.

PostgreSQL stores enums as a separate ``pg_type`` row; the only
supported way to rename a value in-place is ``ALTER TYPE … RENAME
VALUE``.  That keeps the OIDs stable so any FK / index that
references the column doesn't need to be rebuilt.
"""

from __future__ import annotations

from alembic import op


# Alembic identifiers
revision = "a3f9b1c2d4e5"
down_revision = "76e03bf50558"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # SQLAlchemy stores the Python *member name* (e.g. ``beach_house``)
    # in the Postgres enum — not the Arabic ``value`` attribute — so
    # the rename is ASCII-only.  Confirmed via:
    #   SELECT enumlabel FROM pg_enum e
    #     JOIN pg_type t ON e.enumtypid = t.oid
    #    WHERE t.typname = 'category';
    # ALTER TYPE … RENAME VALUE has been supported since Postgres 10
    # and runs in O(1) — it only touches the catalog row.
    op.execute("ALTER TYPE category RENAME VALUE 'beach_house' TO 'day_use'")


def downgrade() -> None:
    op.execute("ALTER TYPE category RENAME VALUE 'day_use' TO 'beach_house'")
