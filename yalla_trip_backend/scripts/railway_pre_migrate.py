"""Align alembic_version after deleted superseded revisions (see f6a1 migration).

If ``alembic_version`` still references removed revisions ``f5e3b2c4d6e8`` or
``f4d2e8a1b3c5``, rewrite it to ``e2f1a8b9c0d4`` so ``alembic upgrade head``
can run. Safe no-op for all other states (including missing table).
"""

from __future__ import annotations

import os
import sys

from sqlalchemy import create_engine, text
from sqlalchemy.exc import ProgrammingError

BAD = frozenset({"f5e3b2c4d6e8", "f4d2e8a1b3c5"})
STAMP_TO = "e2f1a8b9c0d4"


def _sync_url(raw: str) -> str:
    url = raw.replace("postgresql+asyncpg://", "postgresql://", 1)
    if url.startswith("postgres://"):
        url = "postgresql://" + url[len("postgres://") :]
    return url


def main() -> int:
    raw = (os.environ.get("DATABASE_URL") or "").strip()
    if not raw:
        return 0

    eng = create_engine(_sync_url(raw))
    with eng.begin() as conn:
        try:
            row = conn.execute(text("SELECT version_num FROM alembic_version")).fetchone()
        except ProgrammingError as e:
            msg = str(e.orig) if getattr(e, "orig", None) is not None else str(e)
            if "alembic_version" in msg and "does not exist" in msg:
                return 0
            raise
        if row and row[0] in BAD:
            conn.execute(
                text("UPDATE alembic_version SET version_num = :v"),
                {"v": STAMP_TO},
            )
    return 0


if __name__ == "__main__":
    sys.exit(main())
