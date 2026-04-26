"""payout: hardening – disburse_initiated_at + default-bank uniqueness

Revision ID: c4d9e2f3a5b7
Revises: b5c7d2e8f1a3
Create Date: 2026-04-27 01:35:00

Wave 26.1 — payout concurrency / correctness hardening.

Two changes ride on the same migration so we only pay one offline
window:

1. ``payouts.disburse_initiated_at`` (nullable TIMESTAMPTZ).  Until
   now the reconciliation scheduler used ``created_at`` as a proxy
   for "when did we hit the gateway?", which is wrong if an admin
   batches a payout on Monday and disburses it on Friday — the
   reconciler would chase the gateway 4 days too early.  The new
   column is set inside ``admin_disburse`` at the moment we call
   the gateway; the reconciler now keys off it directly.

   Backfill strategy: copy ``created_at`` for any existing rows in
   non-terminal states.  That preserves current behaviour for
   in-flight disbursements (the proxy was correct most of the time)
   while letting future rows record the truth.

2. Partial unique index ``uq_default_per_host`` on
   ``host_bank_accounts(host_id) WHERE is_default = true``.  Closes
   a TOCTOU race where two concurrent ``POST /bank-accounts`` calls
   could both flip the previous default to ``false`` and then both
   INSERT a new ``is_default=true`` row, leaving the host with two
   defaults and an undefined "which one wins" payout target.  The
   index makes the second INSERT fail at the DB layer regardless of
   what the application does.

   Rather than guess which row to keep when backfilling existing
   data, we leave the partial index to fire on the *next* INSERT;
   if the table already contains duplicate defaults, the migration
   logs a warning and the on-call cleans them up via SQL.  Such
   duplicates haven't been observed in production yet (the API
   path always tries to enforce uniqueness) so the warning path is
   defensive, not expected.
"""

from __future__ import annotations

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# Alembic identifiers
revision: str = "c4d9e2f3a5b7"
down_revision: Union[str, None] = "b5c7d2e8f1a3"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # ── 1. payouts.disburse_initiated_at ────────────────────────
    op.add_column(
        "payouts",
        sa.Column(
            "disburse_initiated_at",
            sa.DateTime(timezone=True),
            nullable=True,
        ),
    )
    # Backfill: any payout currently mid-flight gets ``created_at``
    # as a best-effort timestamp so the reconciler keeps its
    # existing behaviour for in-flight rows.  Terminal rows
    # (succeeded / failed / not_started) are left NULL — they're
    # not chased by the scheduler anyway.
    op.execute(
        """
        UPDATE payouts
        SET disburse_initiated_at = created_at
        WHERE disburse_status IN ('initiated', 'processing')
          AND disburse_initiated_at IS NULL
        """
    )

    # ── 2. host_bank_accounts default-uniqueness ─────────────────
    # Detect duplicates *before* creating the index so the migration
    # fails loudly rather than at index-creation time with a less
    # actionable error message.
    bind = op.get_bind()
    dup_rows = bind.execute(
        sa.text(
            """
            SELECT host_id, COUNT(*) AS n
            FROM host_bank_accounts
            WHERE is_default = true
            GROUP BY host_id
            HAVING COUNT(*) > 1
            """
        )
    ).fetchall()
    if dup_rows:
        # Don't auto-pick a winner — operator review required.  The
        # exception aborts the migration; ops can clean up with a
        # simple "UPDATE ... SET is_default = false WHERE id NOT IN
        # (SELECT MIN(id) ...)" then re-run.
        details = ", ".join(f"host_id={r.host_id}({r.n})" for r in dup_rows)
        raise RuntimeError(
            "Refusing to add unique partial index — duplicate default "
            f"bank accounts already exist: {details}.  Resolve manually "
            "before re-running this migration."
        )

    op.create_index(
        "uq_default_per_host",
        "host_bank_accounts",
        ["host_id"],
        unique=True,
        postgresql_where=sa.text("is_default = true"),
    )


def downgrade() -> None:
    op.drop_index("uq_default_per_host", table_name="host_bank_accounts")
    op.drop_column("payouts", "disburse_initiated_at")
