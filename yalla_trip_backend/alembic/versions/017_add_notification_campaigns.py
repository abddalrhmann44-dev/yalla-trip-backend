"""Wave 17 – Admin notification campaigns.

Adds ``notification_campaigns`` table for broadcast push notifications.
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "017_add_notification_campaigns"
down_revision: Union[str, None] = "016_add_availability_rules"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "notification_campaigns",
        sa.Column("id", sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column(
            "created_by",
            sa.Integer(),
            sa.ForeignKey("users.id", ondelete="SET NULL"),
            nullable=True,
            index=True,
        ),
        sa.Column("title_ar", sa.String(200), nullable=False),
        sa.Column("title_en", sa.String(200), nullable=True),
        sa.Column("body_ar", sa.Text(), nullable=False),
        sa.Column("body_en", sa.Text(), nullable=True),
        sa.Column("deeplink", sa.String(500), nullable=True),
        sa.Column(
            "audience",
            sa.Enum(
                "all_users", "hosts", "guests", "by_area", "recent_bookers",
                name="campaignaudience",
            ),
            nullable=False,
            index=True,
        ),
        sa.Column("filter_area", sa.String(100), nullable=True),
        sa.Column("filter_recent_days", sa.Integer(), nullable=True),
        sa.Column(
            "status",
            sa.Enum(
                "draft", "scheduled", "sending", "sent", "failed", "cancelled",
                name="campaignstatus",
            ),
            nullable=False,
            server_default="draft",
            index=True,
        ),
        sa.Column("scheduled_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("sent_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("target_count", sa.Integer(), server_default="0"),
        sa.Column("success_count", sa.Integer(), server_default="0"),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
        ),
    )


def downgrade() -> None:
    op.drop_table("notification_campaigns")
    op.execute("DROP TYPE IF EXISTS campaignstatus")
    op.execute("DROP TYPE IF EXISTS campaignaudience")
