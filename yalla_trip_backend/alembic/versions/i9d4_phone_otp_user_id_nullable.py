"""Wave 29 — make phone_otps.user_id nullable for pre-auth WhatsApp OTP.

Revision ID: i9d4e5f6a7b8
Revises: h8c3d4e5f6a7

The ``phone_otps`` table was originally only used for the host phone
verification flow (an already-signed-in user proves ownership of a
phone number).  We now reuse the same table for pre-auth WhatsApp
login/register OTPs, where there is no user row yet — the user is
only created once the code is verified.  Relaxing the FK to nullable
lets both flows live in one table.
"""

from __future__ import annotations

from typing import Sequence, Union

from alembic import op


revision: str = "i9d4e5f6a7b8"
down_revision: Union[str, None] = "h8c3d4e5f6a7"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.execute(
        "ALTER TABLE phone_otps "
        "ALTER COLUMN user_id DROP NOT NULL"
    )


def downgrade() -> None:
    # Best-effort: pre-auth rows have no owner so we can't restore the
    # NOT NULL constraint without losing them.  Drop those rows first
    # so the column-level constraint can re-apply cleanly.
    op.execute("DELETE FROM phone_otps WHERE user_id IS NULL")
    op.execute(
        "ALTER TABLE phone_otps "
        "ALTER COLUMN user_id SET NOT NULL"
    )
