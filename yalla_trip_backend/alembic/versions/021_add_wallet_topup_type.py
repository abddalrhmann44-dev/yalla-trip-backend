"""Wave 21 – Wallet top-ups.

Extends the ``wallettxntype`` enum with a new ``topup`` value so users
can credit their own wallet via card payment.
"""

from typing import Sequence, Union

from alembic import op


revision: str = "021_add_wallet_topup_type"
down_revision: Union[str, None] = "020_add_trip_posts"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Postgres enum values are added via ALTER TYPE and must run
    # outside a transaction block.
    with op.get_context().autocommit_block():
        op.execute("ALTER TYPE wallettxntype ADD VALUE IF NOT EXISTS 'topup'")


def downgrade() -> None:
    # Enum value removal requires rebuilding the type; left as a no-op
    # since downgrading would orphan rows tagged `topup`.
    pass
