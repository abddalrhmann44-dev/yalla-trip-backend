"""Wave 23 – chat negotiation + phone OTP.

Schema changes
--------------
1. ``conversations`` gains booking intent + negotiation state:
     - ``check_in``, ``check_out`` (DATE, nullable)
     - ``guests`` (INT, nullable)
     - ``status`` (enum ``conversationstatus``, default 'open')
     - ``latest_offer_amount`` (DOUBLE PRECISION, nullable)
     - ``latest_offer_by`` (VARCHAR(8), nullable)  — 'guest' | 'owner'
     - ``booking_id`` (INT, nullable, FK → bookings.id ON DELETE SET NULL)

2. ``messages`` gains:
     - ``kind`` (enum ``messagekind``, default 'text')
     - ``offer_amount`` (DOUBLE PRECISION, nullable)
     - ``booking_id`` (INT, nullable, FK → bookings.id ON DELETE SET NULL)

3. ``users`` gains owner-phone-OTP bookkeeping:
     - ``phone_verified`` (BOOL default FALSE)
     - ``phone_verified_at`` (TIMESTAMPTZ, nullable)

4. New table ``phone_otps`` for OTP challenges.
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "023_chat_negot_phone_otp"
down_revision: Union[str, None] = "022_add_boat_category"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # ── 1. New enum types ─────────────────────────────────────
    op.execute(
        "DO $$ BEGIN "
        "CREATE TYPE conversationstatus AS ENUM "
        "('open', 'accepted', 'declined', 'expired');"
        "EXCEPTION WHEN duplicate_object THEN null; END $$;"
    )
    op.execute(
        "DO $$ BEGIN "
        "CREATE TYPE messagekind AS ENUM "
        "('text', 'offer', 'accept', 'decline', 'system');"
        "EXCEPTION WHEN duplicate_object THEN null; END $$;"
    )

    # ── 2. conversations extensions ───────────────────────────
    op.add_column("conversations", sa.Column("check_in", sa.Date(), nullable=True))
    op.add_column("conversations", sa.Column("check_out", sa.Date(), nullable=True))
    op.add_column("conversations", sa.Column("guests", sa.Integer(), nullable=True))
    op.add_column(
        "conversations",
        sa.Column(
            "status",
            sa.Enum(
                "open", "accepted", "declined", "expired",
                name="conversationstatus",
                create_type=False,
            ),
            nullable=False,
            server_default="open",
        ),
    )
    op.create_index(
        "ix_conversations_status", "conversations", ["status"],
    )
    op.add_column(
        "conversations",
        sa.Column("latest_offer_amount", sa.Float(), nullable=True),
    )
    op.add_column(
        "conversations",
        sa.Column("latest_offer_by", sa.String(length=8), nullable=True),
    )
    op.add_column(
        "conversations",
        sa.Column("booking_id", sa.Integer(), nullable=True),
    )
    op.create_foreign_key(
        "fk_conversations_booking_id",
        "conversations", "bookings",
        ["booking_id"], ["id"], ondelete="SET NULL",
    )
    op.create_index(
        "ix_conversations_booking_id", "conversations", ["booking_id"],
    )

    # ── 3. messages extensions ────────────────────────────────
    op.add_column(
        "messages",
        sa.Column(
            "kind",
            sa.Enum(
                "text", "offer", "accept", "decline", "system",
                name="messagekind",
                create_type=False,
            ),
            nullable=False,
            server_default="text",
        ),
    )
    op.create_index("ix_messages_kind", "messages", ["kind"])
    op.add_column(
        "messages",
        sa.Column("offer_amount", sa.Float(), nullable=True),
    )
    op.add_column(
        "messages",
        sa.Column("booking_id", sa.Integer(), nullable=True),
    )
    op.create_foreign_key(
        "fk_messages_booking_id",
        "messages", "bookings",
        ["booking_id"], ["id"], ondelete="SET NULL",
    )
    op.create_index("ix_messages_booking_id", "messages", ["booking_id"])

    # ── 4. users OTP columns ──────────────────────────────────
    op.add_column(
        "users",
        sa.Column(
            "phone_verified", sa.Boolean(),
            nullable=False, server_default=sa.text("false"),
        ),
    )
    op.add_column(
        "users",
        sa.Column(
            "phone_verified_at",
            sa.DateTime(timezone=True),
            nullable=True,
        ),
    )

    # ── 5. phone_otps table ───────────────────────────────────
    op.create_table(
        "phone_otps",
        sa.Column("id", sa.Integer(), primary_key=True, index=True),
        sa.Column(
            "user_id", sa.Integer(),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            nullable=False, index=True,
        ),
        sa.Column("phone", sa.String(length=20), nullable=False, index=True),
        sa.Column("code_hash", sa.String(length=64), nullable=False),
        sa.Column(
            "attempts", sa.Integer(),
            nullable=False, server_default="0",
        ),
        sa.Column(
            "expires_at", sa.DateTime(timezone=True),
            nullable=False, index=True,
        ),
        sa.Column(
            "used", sa.Boolean(),
            nullable=False, server_default=sa.text("false"),
        ),
        sa.Column(
            "created_at", sa.DateTime(timezone=True),
            nullable=False, server_default=sa.func.now(),
        ),
    )


def downgrade() -> None:
    op.drop_table("phone_otps")

    op.drop_column("users", "phone_verified_at")
    op.drop_column("users", "phone_verified")

    op.drop_index("ix_messages_booking_id", table_name="messages")
    op.drop_constraint("fk_messages_booking_id", "messages", type_="foreignkey")
    op.drop_column("messages", "booking_id")
    op.drop_column("messages", "offer_amount")
    op.drop_index("ix_messages_kind", table_name="messages")
    op.drop_column("messages", "kind")

    op.drop_index("ix_conversations_booking_id", table_name="conversations")
    op.drop_constraint(
        "fk_conversations_booking_id", "conversations", type_="foreignkey",
    )
    op.drop_column("conversations", "booking_id")
    op.drop_column("conversations", "latest_offer_by")
    op.drop_column("conversations", "latest_offer_amount")
    op.drop_index("ix_conversations_status", table_name="conversations")
    op.drop_column("conversations", "status")
    op.drop_column("conversations", "guests")
    op.drop_column("conversations", "check_out")
    op.drop_column("conversations", "check_in")

    op.execute("DROP TYPE IF EXISTS messagekind")
    op.execute("DROP TYPE IF EXISTS conversationstatus")
