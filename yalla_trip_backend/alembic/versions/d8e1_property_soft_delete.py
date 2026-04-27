"""property: soft-delete column + filter pending bookings on delete

Revision ID: d8e1f7c4a2b9
Revises: c4d9e2f3a5b7
Create Date: 2026-04-27 02:00:00

Wave 26.2 — host dashboard hardening.

Adds ``properties.deleted_at`` (nullable TIMESTAMPTZ) so the host
"delete property" action becomes a *soft* delete.  Hard-deletion was
catastrophic in production: the FK ``bookings.property_id`` is
``ON DELETE CASCADE``, so removing a listing also wiped every
non-terminal booking + payment + review attached to it.  A malicious
host could exploit this to nuke paid guest bookings.

The application layer now:

* Refuses the delete entirely when active bookings exist (409).
* Otherwise stamps ``deleted_at`` instead of removing the row, and
  flips ``is_available = false`` so the listing disappears from
  search.

Routers + queries that surface listings to guests (``/properties``,
``/properties/{id}``, search, recommendations) already gain a
``deleted_at IS NULL`` filter at the application layer in this
release; the column itself is the durable enforcement point.

Index is partial — only non-deleted rows are indexed because
``deleted_at IS NULL`` is the hot path; the soft-deleted tail stays
out of the way.
"""

from __future__ import annotations

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# Alembic identifiers
revision: str = "d8e1f7c4a2b9"
down_revision: Union[str, None] = "c4d9e2f3a5b7"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "properties",
        sa.Column(
            "deleted_at",
            sa.DateTime(timezone=True),
            nullable=True,
        ),
    )
    # Partial index keeps the live-listings hot path tight.  Hosts
    # rarely query their own deleted rows; admins fall back to a full
    # scan which is fine because the soft-deleted tail is small.
    op.create_index(
        "ix_properties_active",
        "properties",
        ["id"],
        unique=False,
        postgresql_where=sa.text("deleted_at IS NULL"),
    )


def downgrade() -> None:
    op.drop_index("ix_properties_active", table_name="properties")
    op.drop_column("properties", "deleted_at")
