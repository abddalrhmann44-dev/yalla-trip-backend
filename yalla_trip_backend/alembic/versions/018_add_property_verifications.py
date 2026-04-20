"""Wave 18 – Property verification / KYC.

Adds ``property_verifications`` table and ``properties.is_verified``
column for the "verified host" badge.
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql


revision: str = "018_add_property_verifications"
down_revision: Union[str, None] = "017_add_notification_campaigns"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # is_verified flag on properties
    op.add_column(
        "properties",
        sa.Column(
            "is_verified",
            sa.Boolean(),
            server_default="false",
            nullable=False,
        ),
    )

    op.create_table(
        "property_verifications",
        sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column(
            "property_id",
            sa.Integer(),
            sa.ForeignKey("properties.id", ondelete="CASCADE"),
            nullable=False,
            index=True,
        ),
        sa.Column(
            "submitted_by",
            sa.Integer(),
            sa.ForeignKey("users.id", ondelete="SET NULL"),
            nullable=True,
            index=True,
        ),
        sa.Column(
            "reviewed_by",
            sa.Integer(),
            sa.ForeignKey("users.id", ondelete="SET NULL"),
            nullable=True,
            index=True,
        ),
        sa.Column(
            "status",
            sa.Enum(
                "pending", "approved", "rejected", "needs_edit",
                name="verificationstatus",
            ),
            nullable=False,
            server_default="pending",
            index=True,
        ),
        sa.Column(
            "document_urls",
            postgresql.ARRAY(sa.String()),
            nullable=False,
            server_default="{}",
        ),
        sa.Column(
            "primary_document_type",
            sa.Enum(
                "ownership_contract", "utility_bill", "id_card",
                "commercial_register", "other",
                name="documenttype",
            ),
            nullable=False,
            server_default="ownership_contract",
        ),
        sa.Column("host_note", sa.Text(), nullable=True),
        sa.Column("admin_note", sa.Text(), nullable=True),
        sa.Column(
            "submitted_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
        ),
        sa.Column("reviewed_at", sa.DateTime(timezone=True), nullable=True),
    )


def downgrade() -> None:
    op.drop_table("property_verifications")
    op.drop_column("properties", "is_verified")
    op.execute("DROP TYPE IF EXISTS verificationstatus")
    op.execute("DROP TYPE IF EXISTS documenttype")
