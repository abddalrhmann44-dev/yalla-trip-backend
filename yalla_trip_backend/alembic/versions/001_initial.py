"""Initial schema – users, properties, bookings, reviews, notifications.

Revision ID: 001_initial
Revises: None
Create Date: 2024-01-01 00:00:00.000000
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

revision: str = "001_initial"
down_revision: Union[str, None] = None
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # ── users ─────────────────────────────────────────────
    op.create_table(
        "users",
        sa.Column("id", sa.Integer(), primary_key=True, index=True),
        sa.Column("firebase_uid", sa.String(128), unique=True, nullable=False, index=True),
        sa.Column("name", sa.String(120), nullable=False),
        sa.Column("email", sa.String(255), unique=True, nullable=True, index=True),
        sa.Column("phone", sa.String(20), unique=True, nullable=True, index=True),
        sa.Column("role", sa.Enum("guest", "owner", "admin", name="userrole"), server_default="guest"),
        sa.Column("avatar_url", sa.String(512), nullable=True),
        sa.Column("is_verified", sa.Boolean(), server_default="false"),
        sa.Column("is_active", sa.Boolean(), server_default="true"),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
    )

    # ── properties ────────────────────────────────────────
    op.create_table(
        "properties",
        sa.Column("id", sa.Integer(), primary_key=True, index=True),
        sa.Column("owner_id", sa.Integer(), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True),
        sa.Column("name", sa.String(200), nullable=False),
        sa.Column("description", sa.Text(), nullable=True),
        sa.Column("area", sa.Enum(
            "عين السخنة", "الساحل الشمالي", "الجونة", "الغردقة", "شرم الشيخ", "رأس سدر",
            name="area",
        ), nullable=False, index=True),
        sa.Column("category", sa.Enum(
            "شاليه", "فندق", "فيلا", "منتجع", "أكوا بارك", "بيت شاطئ",
            name="category",
        ), nullable=False, index=True),
        sa.Column("price_per_night", sa.Float(), nullable=False),
        sa.Column("weekend_price", sa.Float(), nullable=True),
        sa.Column("cleaning_fee", sa.Float(), server_default="0"),
        sa.Column("bedrooms", sa.Integer(), default=1),
        sa.Column("bathrooms", sa.Integer(), default=1),
        sa.Column("max_guests", sa.Integer(), default=4),
        sa.Column("images", postgresql.ARRAY(sa.String(512)), nullable=True),
        sa.Column("amenities", postgresql.ARRAY(sa.String(100)), nullable=True),
        sa.Column("rating", sa.Float(), server_default="0"),
        sa.Column("review_count", sa.Integer(), server_default="0"),
        sa.Column("is_available", sa.Boolean(), server_default="true"),
        sa.Column("is_featured", sa.Boolean(), server_default="false"),
        sa.Column("instant_booking", sa.Boolean(), server_default="false"),
        sa.Column("latitude", sa.Float(), nullable=True),
        sa.Column("longitude", sa.Float(), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
    )

    # ── bookings ──────────────────────────────────────────
    op.create_table(
        "bookings",
        sa.Column("id", sa.Integer(), primary_key=True, index=True),
        sa.Column("booking_code", sa.String(8), unique=True, nullable=False, index=True),
        sa.Column("property_id", sa.Integer(), sa.ForeignKey("properties.id", ondelete="CASCADE"), nullable=False, index=True),
        sa.Column("guest_id", sa.Integer(), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True),
        sa.Column("owner_id", sa.Integer(), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True),
        sa.Column("check_in", sa.Date(), nullable=False),
        sa.Column("check_out", sa.Date(), nullable=False),
        sa.Column("guests_count", sa.Integer(), default=1),
        sa.Column("total_price", sa.Float(), nullable=False),
        sa.Column("platform_fee", sa.Float(), nullable=False),
        sa.Column("owner_payout", sa.Float(), nullable=False),
        sa.Column("status", sa.Enum("pending", "confirmed", "cancelled", "completed", name="bookingstatus"), server_default="pending"),
        sa.Column("payment_status", sa.Enum("pending", "paid", "refunded", name="paymentstatus"), server_default="pending"),
        sa.Column("fawry_ref", sa.String(100), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
    )

    # ── reviews ───────────────────────────────────────────
    op.create_table(
        "reviews",
        sa.Column("id", sa.Integer(), primary_key=True, index=True),
        sa.Column("booking_id", sa.Integer(), sa.ForeignKey("bookings.id", ondelete="CASCADE"), unique=True, nullable=False),
        sa.Column("property_id", sa.Integer(), sa.ForeignKey("properties.id", ondelete="CASCADE"), nullable=False, index=True),
        sa.Column("reviewer_id", sa.Integer(), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True),
        sa.Column("rating", sa.Float(), nullable=False),
        sa.Column("comment", sa.Text(), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
    )

    # ── notifications ─────────────────────────────────────
    op.create_table(
        "notifications",
        sa.Column("id", sa.Integer(), primary_key=True, index=True),
        sa.Column("user_id", sa.Integer(), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True),
        sa.Column("title", sa.String(200), nullable=False),
        sa.Column("body", sa.Text(), nullable=False),
        sa.Column("type", sa.Enum(
            "booking_created", "booking_confirmed", "booking_cancelled",
            "booking_completed", "payment_received", "review_received", "system",
            name="notificationtype",
        ), server_default="system"),
        sa.Column("is_read", sa.Boolean(), server_default="false"),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
    )


def downgrade() -> None:
    op.drop_table("notifications")
    op.drop_table("reviews")
    op.drop_table("bookings")
    op.drop_table("properties")
    op.drop_table("users")
    op.execute("DROP TYPE IF EXISTS userrole")
    op.execute("DROP TYPE IF EXISTS area")
    op.execute("DROP TYPE IF EXISTS category")
    op.execute("DROP TYPE IF EXISTS bookingstatus")
    op.execute("DROP TYPE IF EXISTS paymentstatus")
    op.execute("DROP TYPE IF EXISTS notificationtype")
