"""Promote a user to admin by email or user ID.

Usage:
    python -m scripts.make_admin --email owner@talaa.com
    python -m scripts.make_admin --id 42

Requires the backend `.env` (DATABASE_URL) to be loaded.
"""

from __future__ import annotations

import argparse
import asyncio
import sys

from sqlalchemy import select

from app.database import async_session as AsyncSessionLocal
from app.models.user import User, UserRole


async def _promote(email: str | None, user_id: int | None) -> int:
    async with AsyncSessionLocal() as db:  # type: AsyncSession
        stmt = select(User)
        if email:
            stmt = stmt.where(User.email == email.lower())
        elif user_id is not None:
            stmt = stmt.where(User.id == user_id)
        else:
            print("error: either --email or --id is required", file=sys.stderr)
            return 2

        result = await db.execute(stmt)
        user = result.scalar_one_or_none()
        if user is None:
            print(f"error: user not found (email={email} id={user_id})", file=sys.stderr)
            return 1

        if user.role == UserRole.admin:
            print(f"✓ User {user.id} ({user.email}) is already admin")
            return 0

        user.role = UserRole.admin
        user.is_active = True
        await db.commit()
        print(f"✓ Promoted user {user.id} ({user.email}) to admin")
        return 0


def main() -> None:
    parser = argparse.ArgumentParser(description="Promote a user to admin")
    parser.add_argument("--email", help="User email")
    parser.add_argument("--id", type=int, help="User ID")
    args = parser.parse_args()
    sys.exit(asyncio.run(_promote(args.email, args.id)))


if __name__ == "__main__":
    main()
