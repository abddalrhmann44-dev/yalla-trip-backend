"""Wave 28 — Add owner-form fields: location link, village/parking/audience, day-use price-per-person, optional photos.

Revision ID: g7b2c8d9e1f3
Revises: 025a_re_expand_area

Adds (idempotent on PostgreSQL 11+):

* ``location_link`` — optional Google Maps URL (replaces detailed address textbox).
* ``village_name`` — promoted from being baked into description.
* ``village_fees`` — chalet/villa per-stay village/compound fees.
* ``parking_is_free`` (default true) + ``parking_fee`` (default 0) — informational; never added to booking total.
* ``audience_type`` enum (``family_only`` / ``youth_only`` / ``both``, default ``both``).
* ``price_per_person`` — day-use only, NULL elsewhere.
* ``amenity_photos`` (JSONB list of {label, url}) — optional photos per amenity.
* ``nearby_photos`` (ARRAY of S3 URLs) — optional photos of the surrounding area.

All ``ADD COLUMN IF NOT EXISTS`` so re-running the migration is safe even if a
hot-fix added one of these columns out of band.
"""

from __future__ import annotations

from typing import Sequence, Union

from alembic import op


revision: str = "g7b2c8d9e1f3"
down_revision: Union[str, None] = "025a_re_expand_area"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # AudienceType enum — created idempotently so re-running on a fresh
    # database doesn't blow up if a previous migration step partially
    # ran.  The DO block is the standard PostgreSQL pattern.
    op.execute(
        """
        DO $$
        BEGIN
            IF NOT EXISTS (
                SELECT 1 FROM pg_type WHERE typname = 'audiencetype'
            ) THEN
                CREATE TYPE audiencetype AS ENUM (
                    'family_only', 'youth_only', 'both'
                );
            END IF;
        END $$;
        """
    )

    # New columns — all idempotent.
    op.execute(
        "ALTER TABLE properties "
        "ADD COLUMN IF NOT EXISTS location_link varchar(500)"
    )
    op.execute(
        "ALTER TABLE properties "
        "ADD COLUMN IF NOT EXISTS village_name varchar(200)"
    )
    op.execute(
        "ALTER TABLE properties "
        "ADD COLUMN IF NOT EXISTS village_fees double precision "
        "NOT NULL DEFAULT 0"
    )
    op.execute(
        "ALTER TABLE properties "
        "ADD COLUMN IF NOT EXISTS parking_is_free boolean "
        "NOT NULL DEFAULT true"
    )
    op.execute(
        "ALTER TABLE properties "
        "ADD COLUMN IF NOT EXISTS parking_fee double precision "
        "NOT NULL DEFAULT 0"
    )
    op.execute(
        "ALTER TABLE properties "
        "ADD COLUMN IF NOT EXISTS audience_type audiencetype "
        "NOT NULL DEFAULT 'both'"
    )
    op.execute(
        "ALTER TABLE properties "
        "ADD COLUMN IF NOT EXISTS price_per_person double precision"
    )
    op.execute(
        "ALTER TABLE properties "
        "ADD COLUMN IF NOT EXISTS amenity_photos jsonb"
    )
    op.execute(
        "ALTER TABLE properties "
        "ADD COLUMN IF NOT EXISTS nearby_photos varchar(512)[]"
    )


def downgrade() -> None:
    op.execute(
        "ALTER TABLE properties DROP COLUMN IF EXISTS nearby_photos"
    )
    op.execute(
        "ALTER TABLE properties DROP COLUMN IF EXISTS amenity_photos"
    )
    op.execute(
        "ALTER TABLE properties DROP COLUMN IF EXISTS price_per_person"
    )
    op.execute(
        "ALTER TABLE properties DROP COLUMN IF EXISTS audience_type"
    )
    op.execute("DROP TYPE IF EXISTS audiencetype")
    op.execute(
        "ALTER TABLE properties DROP COLUMN IF EXISTS parking_fee"
    )
    op.execute(
        "ALTER TABLE properties DROP COLUMN IF EXISTS parking_is_free"
    )
    op.execute(
        "ALTER TABLE properties DROP COLUMN IF EXISTS village_fees"
    )
    op.execute(
        "ALTER TABLE properties DROP COLUMN IF EXISTS village_name"
    )
    op.execute(
        "ALTER TABLE properties DROP COLUMN IF EXISTS location_link"
    )
