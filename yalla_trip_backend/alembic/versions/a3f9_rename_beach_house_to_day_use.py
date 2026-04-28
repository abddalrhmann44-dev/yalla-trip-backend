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
    #
    # Idempotency: PostgreSQL has no ``IF EXISTS`` clause on
    # ``ALTER TYPE … RENAME VALUE``.  We therefore wrap the rename in
    # a ``DO`` block that checks ``pg_enum`` first.  This makes the
    # migration safe across three real-world states observed in the
    # wild:
    #   1. ``beach_house`` exists, ``day_use`` does not  → rename runs.
    #   2. ``day_use`` already exists                    → no-op, success.
    #   3. Neither exists (fresh DB seeded post-rename)  → ``day_use``
    #      gets added so downstream code that relies on the label
    #      finds it in the enum.
    op.execute(
        """
        DO $$
        BEGIN
            IF EXISTS (
                SELECT 1 FROM pg_enum e
                JOIN pg_type t ON e.enumtypid = t.oid
                WHERE t.typname = 'category' AND e.enumlabel = 'beach_house'
            ) THEN
                ALTER TYPE category RENAME VALUE 'beach_house' TO 'day_use';
            ELSIF NOT EXISTS (
                SELECT 1 FROM pg_enum e
                JOIN pg_type t ON e.enumtypid = t.oid
                WHERE t.typname = 'category' AND e.enumlabel = 'day_use'
            ) THEN
                ALTER TYPE category ADD VALUE 'day_use';
            END IF;
        END $$;
        """
    )


def downgrade() -> None:
    # Symmetric guard — only rename back if ``day_use`` exists and
    # ``beach_house`` does not, to keep the downgrade re-runnable.
    op.execute(
        """
        DO $$
        BEGIN
            IF EXISTS (
                SELECT 1 FROM pg_enum e
                JOIN pg_type t ON e.enumtypid = t.oid
                WHERE t.typname = 'category' AND e.enumlabel = 'day_use'
            ) AND NOT EXISTS (
                SELECT 1 FROM pg_enum e
                JOIN pg_type t ON e.enumtypid = t.oid
                WHERE t.typname = 'category' AND e.enumlabel = 'beach_house'
            ) THEN
                ALTER TYPE category RENAME VALUE 'day_use' TO 'beach_house';
            END IF;
        END $$;
        """
    )
