"""Wave 13 – iCal export + import.

Adds:

* ``properties.ical_token`` — unguessable secret for the public feed URL.
* ``calendar_imports`` — remote iCal feeds the host has subscribed to.
* ``calendar_blocks`` — half-open date ranges marking a property as
  unavailable (manual, imported, or booking-derived).
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "015_add_calendar_sync"
down_revision: Union[str, None] = "014_add_wallet"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def _block_source(create_type: bool) -> sa.Enum:
    return sa.Enum(
        "manual", "imported", "booking",
        name="blocksource",
        create_type=create_type,
    )


def upgrade() -> None:
    # ── Property.ical_token ─────────────────────────────────
    op.add_column(
        "properties",
        sa.Column("ical_token", sa.String(64), nullable=True),
    )
    op.create_index(
        "ix_properties_ical_token",
        "properties", ["ical_token"],
        unique=True,
    )

    # ── calendar_imports ────────────────────────────────────
    op.create_table(
        "calendar_imports",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column(
            "property_id", sa.Integer(),
            sa.ForeignKey("properties.id", ondelete="CASCADE"),
            nullable=False, index=True,
        ),
        sa.Column("name", sa.String(100), nullable=False),
        sa.Column("url", sa.String(2048), nullable=False),
        sa.Column(
            "is_active", sa.Boolean(),
            nullable=False, server_default="true",
        ),
        sa.Column(
            "last_synced_at", sa.DateTime(timezone=True), nullable=True,
        ),
        sa.Column("last_error", sa.Text(), nullable=True),
        sa.Column(
            "last_event_count", sa.Integer(),
            nullable=False, server_default="0",
        ),
        sa.Column(
            "created_at", sa.DateTime(timezone=True),
            server_default=sa.func.now(), nullable=False,
        ),
        sa.Column(
            "updated_at", sa.DateTime(timezone=True),
            server_default=sa.func.now(), nullable=False,
        ),
    )

    # ── calendar_blocks ─────────────────────────────────────
    op.create_table(
        "calendar_blocks",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column(
            "property_id", sa.Integer(),
            sa.ForeignKey("properties.id", ondelete="CASCADE"),
            nullable=False, index=True,
        ),
        sa.Column(
            "import_id", sa.Integer(),
            sa.ForeignKey("calendar_imports.id", ondelete="CASCADE"),
            nullable=True, index=True,
        ),
        sa.Column("start_date", sa.Date(), nullable=False, index=True),
        sa.Column("end_date", sa.Date(), nullable=False, index=True),
        sa.Column(
            "source", _block_source(create_type=True),
            nullable=False, server_default="manual",
        ),
        sa.Column("summary", sa.String(500), nullable=True),
        sa.Column("external_uid", sa.String(500), nullable=True, index=True),
        sa.Column(
            "created_at", sa.DateTime(timezone=True),
            server_default=sa.func.now(), nullable=False,
        ),
        sa.UniqueConstraint(
            "import_id", "external_uid",
            name="uq_calblock_import_uid",
        ),
    )


def downgrade() -> None:
    op.drop_table("calendar_blocks")
    op.drop_table("calendar_imports")
    op.drop_index("ix_properties_ical_token", table_name="properties")
    op.drop_column("properties", "ical_token")
    bind = op.get_bind()
    _block_source(create_type=False).drop(bind, checkfirst=True)
