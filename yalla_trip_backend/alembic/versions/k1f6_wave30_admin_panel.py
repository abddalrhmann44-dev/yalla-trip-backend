"""Wave 30 — finishing touches on the admin panel.

Revision ID: k1f6a7b8c9d0
Revises: j0e5f6a7b8c9

Adds the four remaining admin-panel features in one migration:

  - ``feature_flags`` + ``feature_flag_assignments`` — A/B testing
    and gradual rollouts.
  - ``api_keys`` — partner / integration auth keys with scoped
    permissions and rotation.
  - ``promo_banners`` — homepage marketing banners with scheduling
    and engagement tracking.
  - ``messages.is_flagged`` / ``is_hidden`` / ``flag_reason`` —
    chat-monitor moderation columns.

We bundle them because they ship together; rollback drops the new
tables and the new columns in the order opposite to creation.
"""

from __future__ import annotations

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op


revision: str = "k1f6a7b8c9d0"
down_revision: Union[str, None] = "j0e5f6a7b8c9"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # ── Feature flags ─────────────────────────────────────
    op.create_table(
        "feature_flags",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("key", sa.String(length=100), nullable=False),
        sa.Column("description", sa.Text(), nullable=True),
        sa.Column(
            "kind",
            sa.Enum("boolean", "rollout", "ab_test", name="flagkind"),
            nullable=False,
            server_default="boolean",
        ),
        sa.Column(
            "enabled", sa.Boolean(),
            nullable=False, server_default=sa.text("false"),
        ),
        sa.Column(
            "default_value", sa.Boolean(),
            nullable=False, server_default=sa.text("false"),
        ),
        sa.Column(
            "rollout_percent", sa.Integer(),
            nullable=False, server_default="0",
        ),
        sa.Column("variant_a", sa.String(length=60), nullable=True),
        sa.Column("variant_b", sa.String(length=60), nullable=True),
        sa.Column("last_change_note", sa.Text(), nullable=True),
        sa.Column(
            "created_at", sa.DateTime(timezone=True),
            nullable=False, server_default=sa.text("CURRENT_TIMESTAMP"),
        ),
        sa.Column(
            "updated_at", sa.DateTime(timezone=True),
            nullable=False, server_default=sa.text("CURRENT_TIMESTAMP"),
        ),
        sa.Column(
            "updated_by", sa.Integer(),
            sa.ForeignKey("users.id", ondelete="SET NULL"),
            nullable=True,
        ),
    )
    op.create_index(
        "ix_feature_flags_key", "feature_flags", ["key"], unique=True,
    )
    op.create_index(
        "ix_feature_flags_updated_by", "feature_flags", ["updated_by"],
    )

    op.create_table(
        "feature_flag_assignments",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column(
            "flag_id", sa.Integer(),
            sa.ForeignKey("feature_flags.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column(
            "user_id", sa.Integer(),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("variant", sa.String(length=60), nullable=False),
        sa.Column(
            "assigned_at", sa.DateTime(timezone=True),
            nullable=False, server_default=sa.text("CURRENT_TIMESTAMP"),
        ),
        sa.UniqueConstraint(
            "flag_id", "user_id",
            name="uq_feature_flag_assignment_flag_user",
        ),
    )
    op.create_index(
        "ix_ffa_flag_id", "feature_flag_assignments", ["flag_id"],
    )
    op.create_index(
        "ix_ffa_user_id", "feature_flag_assignments", ["user_id"],
    )

    # ── API keys ──────────────────────────────────────────
    op.create_table(
        "api_keys",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("name", sa.String(length=120), nullable=False),
        sa.Column("description", sa.Text(), nullable=True),
        sa.Column("key_prefix", sa.String(length=16), nullable=False),
        sa.Column("key_hash", sa.String(length=128), nullable=False),
        sa.Column(
            "scopes", sa.ARRAY(sa.String()),
            nullable=False, server_default="{}",
        ),
        sa.Column(
            "created_by", sa.Integer(),
            sa.ForeignKey("users.id", ondelete="SET NULL"),
            nullable=True,
        ),
        sa.Column(
            "created_at", sa.DateTime(timezone=True),
            nullable=False, server_default=sa.text("CURRENT_TIMESTAMP"),
        ),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("revoked_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("last_used_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column(
            "usage_count", sa.Integer(),
            nullable=False, server_default="0",
        ),
    )
    op.create_index(
        "ix_api_keys_key_prefix", "api_keys", ["key_prefix"], unique=True,
    )
    op.create_index("ix_api_keys_key_hash", "api_keys", ["key_hash"])
    op.create_index("ix_api_keys_created_by", "api_keys", ["created_by"])
    op.create_index("ix_api_keys_revoked_at", "api_keys", ["revoked_at"])

    # ── Promo banners ─────────────────────────────────────
    op.create_table(
        "promo_banners",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("title_ar", sa.String(length=200), nullable=True),
        sa.Column("title_en", sa.String(length=200), nullable=True),
        sa.Column("subtitle_ar", sa.String(length=300), nullable=True),
        sa.Column("subtitle_en", sa.String(length=300), nullable=True),
        sa.Column("image_url", sa.String(length=512), nullable=False),
        sa.Column("accent_color", sa.String(length=20), nullable=True),
        sa.Column(
            "cta_kind",
            sa.Enum(
                "none", "deeplink", "url", "property", "area",
                name="bannerctakind",
            ),
            nullable=False,
            server_default="none",
        ),
        sa.Column("cta_target", sa.String(length=512), nullable=True),
        sa.Column(
            "priority", sa.Integer(),
            nullable=False, server_default="0",
        ),
        sa.Column(
            "is_active", sa.Boolean(),
            nullable=False, server_default=sa.text("false"),
        ),
        sa.Column("start_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("end_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column(
            "impressions", sa.Integer(),
            nullable=False, server_default="0",
        ),
        sa.Column(
            "clicks", sa.Integer(),
            nullable=False, server_default="0",
        ),
        sa.Column(
            "created_by", sa.Integer(),
            sa.ForeignKey("users.id", ondelete="SET NULL"),
            nullable=True,
        ),
        sa.Column(
            "created_at", sa.DateTime(timezone=True),
            nullable=False, server_default=sa.text("CURRENT_TIMESTAMP"),
        ),
        sa.Column(
            "updated_at", sa.DateTime(timezone=True),
            nullable=False, server_default=sa.text("CURRENT_TIMESTAMP"),
        ),
    )
    op.create_index(
        "ix_promo_banners_priority", "promo_banners", ["priority"],
    )
    op.create_index(
        "ix_promo_banners_is_active", "promo_banners", ["is_active"],
    )
    op.create_index(
        "ix_promo_banners_created_by", "promo_banners", ["created_by"],
    )

    # ── Chat moderation columns ───────────────────────────
    op.add_column(
        "messages",
        sa.Column(
            "is_flagged", sa.Boolean(),
            nullable=False, server_default=sa.text("false"),
        ),
    )
    op.add_column(
        "messages",
        sa.Column(
            "is_hidden", sa.Boolean(),
            nullable=False, server_default=sa.text("false"),
        ),
    )
    op.add_column(
        "messages",
        sa.Column("flag_reason", sa.String(length=200), nullable=True),
    )
    op.create_index(
        "ix_messages_is_flagged", "messages", ["is_flagged"],
    )
    op.create_index(
        "ix_messages_is_hidden", "messages", ["is_hidden"],
    )


def downgrade() -> None:
    # Reverse order of upgrade.
    op.drop_index("ix_messages_is_hidden", table_name="messages")
    op.drop_index("ix_messages_is_flagged", table_name="messages")
    op.drop_column("messages", "flag_reason")
    op.drop_column("messages", "is_hidden")
    op.drop_column("messages", "is_flagged")

    op.drop_index("ix_promo_banners_created_by", table_name="promo_banners")
    op.drop_index("ix_promo_banners_is_active", table_name="promo_banners")
    op.drop_index("ix_promo_banners_priority", table_name="promo_banners")
    op.drop_table("promo_banners")
    op.execute("DROP TYPE IF EXISTS bannerctakind")

    op.drop_index("ix_api_keys_revoked_at", table_name="api_keys")
    op.drop_index("ix_api_keys_created_by", table_name="api_keys")
    op.drop_index("ix_api_keys_key_hash", table_name="api_keys")
    op.drop_index("ix_api_keys_key_prefix", table_name="api_keys")
    op.drop_table("api_keys")

    op.drop_index("ix_ffa_user_id", table_name="feature_flag_assignments")
    op.drop_index("ix_ffa_flag_id", table_name="feature_flag_assignments")
    op.drop_table("feature_flag_assignments")
    op.drop_index("ix_feature_flags_updated_by", table_name="feature_flags")
    op.drop_index("ix_feature_flags_key", table_name="feature_flags")
    op.drop_table("feature_flags")
    op.execute("DROP TYPE IF EXISTS flagkind")
