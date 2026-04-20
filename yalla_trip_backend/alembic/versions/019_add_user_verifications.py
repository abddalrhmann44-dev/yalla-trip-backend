"""Wave 19 – Guest (user) identity verification.

Adds ``user_verifications`` table – KYC submissions reviewed by admins.
``users.is_verified`` already exists (see migration 001).
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "019_add_user_verifications"
down_revision: Union[str, None] = "018_add_property_verifications"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "user_verifications",
        sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column(
            "user_id",
            sa.Integer(),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            nullable=False,
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
                name="userverificationstatus",
            ),
            nullable=False,
            server_default="pending",
            index=True,
        ),
        sa.Column(
            "id_doc_type",
            sa.Enum(
                "national_id", "passport", "driver_license",
                name="useriddoctype",
            ),
            nullable=False,
            server_default="national_id",
        ),
        sa.Column("id_front_url", sa.String(512), nullable=False),
        sa.Column("id_back_url", sa.String(512), nullable=True),
        sa.Column("selfie_url", sa.String(512), nullable=False),
        sa.Column("admin_note", sa.Text(), nullable=True),
        sa.Column(
            "submitted_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
        ),
        sa.Column("reviewed_at", sa.DateTime(timezone=True), nullable=True),
    )


def downgrade() -> None:
    op.drop_table("user_verifications")
    op.execute("DROP TYPE IF EXISTS userverificationstatus")
    op.execute("DROP TYPE IF EXISTS useriddoctype")
