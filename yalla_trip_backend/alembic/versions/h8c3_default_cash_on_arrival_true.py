"""Wave 29 — default cash_on_arrival_enabled to True for every property.

Revision ID: h8c3d4e5f6a7
Revises: g7b2c8d9e1f3

Product rule (May 2026): every booking should collect a one-night
online deposit and settle the remainder as cash on arrival, so the
property-level toggle defaults to ``True``.  Existing rows that were
created under the old ``False`` default are flipped here to keep
behaviour consistent across the catalogue; hosts who actively want
the legacy 100%-online flow can still toggle the field off afterwards.
"""

from __future__ import annotations

from typing import Sequence, Union

from alembic import op


revision: str = "h8c3d4e5f6a7"
down_revision: Union[str, None] = "g7b2c8d9e1f3"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Flip the column-level default first so any future inserts
    # (including those running against the new server_default) follow
    # the new product rule.
    op.execute(
        "ALTER TABLE properties "
        "ALTER COLUMN cash_on_arrival_enabled SET DEFAULT true"
    )
    # Backfill existing rows.  We deliberately overwrite every row
    # (not just NULLs) so hosts who never touched the toggle inherit
    # the new default; anyone who needs the legacy flow can opt out
    # in the property edit screen.
    op.execute(
        "UPDATE properties SET cash_on_arrival_enabled = true "
        "WHERE cash_on_arrival_enabled = false"
    )


def downgrade() -> None:
    op.execute(
        "ALTER TABLE properties "
        "ALTER COLUMN cash_on_arrival_enabled SET DEFAULT false"
    )
