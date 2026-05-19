"""Add property_code to properties table.

Revision ID: n3h8o4p5q6r7
Revises: m2g7h8i9j0k1

* Adds ``properties.property_code`` VARCHAR(12) UNIQUE — auto-generated
  short code for each property (format: PROP-XXXXXX).
* Backfills existing rows with a generated code derived from their id
  so the column can be made NOT NULL in a later migration.
"""

from __future__ import annotations

import random
import string
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "n3h8o4p5q6r7"
down_revision: Union[str, None] = "m2g7h8i9j0k1"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

_CHARS = string.ascii_uppercase + string.digits


def _generate_code(prop_id: int) -> str:
    """Deterministic seed from id so backfill is idempotent on re-run."""
    rng = random.Random(prop_id * 0xDEAD_BEEF)
    suffix = "".join(rng.choices(_CHARS, k=6))
    return f"PROP-{suffix}"


def upgrade() -> None:
    op.add_column(
        "properties",
        sa.Column(
            "property_code",
            sa.String(12),
            nullable=True,
            unique=True,
        ),
    )
    op.create_index(
        "ix_properties_property_code",
        "properties",
        ["property_code"],
        unique=True,
    )

    # Backfill existing rows
    conn = op.get_bind()
    rows = conn.execute(
        sa.text("SELECT id FROM properties ORDER BY id")
    ).fetchall()
    for (prop_id,) in rows:
        code = _generate_code(prop_id)
        conn.execute(
            sa.text(
                "UPDATE properties SET property_code = :code WHERE id = :pid"
            ),
            {"code": code, "pid": prop_id},
        )


def downgrade() -> None:
    op.drop_index("ix_properties_property_code", table_name="properties")
    op.drop_column("properties", "property_code")
