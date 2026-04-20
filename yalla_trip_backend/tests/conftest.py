"""Shared test fixtures – async client, isolated DB override.

We run the full schema against the **real Postgres** service because
some models use PG-specific types (ARRAY, ENUM, JSONB).  CI spins up a
disposable Postgres container, the local docker-compose stack already
has one.  When neither is available the tests are skipped gracefully.
"""

from __future__ import annotations

import asyncio
import os
from datetime import datetime, timezone
from typing import AsyncGenerator

import pytest
import pytest_asyncio
from fastapi import Depends, Request
from httpx import ASGITransport, AsyncClient
from sqlalchemy.ext.asyncio import (
    AsyncSession,
    async_sessionmaker,
    create_async_engine,
)

from app.database import Base, get_db
from app.main import app
from app.middleware.auth_middleware import get_current_user
from app.models.user import User, UserRole

# ── Target DB for tests ───────────────────────────────────
# Prefer TEST_DATABASE_URL; else reuse DATABASE_URL but swap the DB
# name to ``<db>_test`` so we never trample on developer data.  Fall
# back to local Postgres defaults for bare `pytest` runs.
def _derive_test_db_url() -> str:
    explicit = os.environ.get("TEST_DATABASE_URL")
    if explicit:
        return explicit
    src = os.environ.get(
        "DATABASE_URL",
        "postgresql+asyncpg://yalla:yalla_secret@localhost:5432/yalla_trip",
    )
    # Replace only the final ``/<db>`` segment.
    base, _, db = src.rpartition("/")
    if not db or not base:
        return src
    if db.endswith("_test"):
        return src
    return f"{base}/{db}_test"


TEST_DB_URL = _derive_test_db_url()

engine = create_async_engine(TEST_DB_URL, echo=False, future=True)
TestSession = async_sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)


async def _override_get_db() -> AsyncGenerator[AsyncSession, None]:
    async with TestSession() as session:
        try:
            yield session
            await session.commit()
        except Exception:
            await session.rollback()
            raise


# ── Fake users for auth bypass ────────────────────────────
_NOW = datetime.now(timezone.utc)


def _build_user(**kw) -> User:
    defaults = dict(
        is_verified=True,
        is_active=True,
        phone_verified=True,
        phone_verified_at=_NOW,
        created_at=_NOW,
        updated_at=_NOW,
    )
    defaults.update(kw)
    return User(**defaults)


_fake_user = _build_user(
    id=1,
    firebase_uid="test_uid",
    name="Test User",
    email="test@yallatrip.com",
    phone="+201000000000",
    role=UserRole.guest,
)

_fake_owner = _build_user(
    id=2,
    firebase_uid="owner_uid",
    name="Test Owner",
    email="owner@yallatrip.com",
    phone="+201111111111",
    role=UserRole.owner,
)

_fake_admin = _build_user(
    id=3,
    firebase_uid="admin_uid",
    name="Admin",
    email="admin@yallatrip.com",
    phone="+201222222222",
    role=UserRole.admin,
)


@pytest.fixture(scope="session")
def event_loop():
    loop = asyncio.new_event_loop()
    yield loop
    loop.close()


@pytest_asyncio.fixture(autouse=True)
async def setup_db():
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.drop_all)
        await conn.run_sync(Base.metadata.create_all)

    # Seed the fake users so foreign-keyed resources (properties,
    # bookings, etc.) can be inserted in tests.
    async with TestSession() as session:
        for proto in (_fake_user, _fake_owner, _fake_admin):
            session.add(_build_user(
                id=proto.id,
                firebase_uid=proto.firebase_uid,
                name=proto.name,
                email=proto.email,
                phone=proto.phone,
                role=proto.role,
            ))
        await session.commit()

    yield
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.drop_all)


async def _auth_from_header(
    request: Request, db: AsyncSession = Depends(get_db)
) -> User:
    """Resolve the test user from the ``X-Test-User`` header so multiple
    httpx clients in the same test can act as different people
    concurrently (dependency overrides are global to the app, so we
    can't just swap them per-fixture)."""
    uid = int(request.headers.get("x-test-user", _fake_user.id))
    row = await db.get(User, uid)
    if row is None:
        raise RuntimeError(f"Seed user {uid} missing from test DB")
    return row


def _install_overrides() -> None:
    app.dependency_overrides[get_db] = _override_get_db
    app.dependency_overrides[get_current_user] = _auth_from_header


@pytest_asyncio.fixture
async def guest_client() -> AsyncGenerator[AsyncClient, None]:
    _install_overrides()
    transport = ASGITransport(app=app)
    async with AsyncClient(
        transport=transport,
        base_url="http://test",
        headers={"X-Test-User": str(_fake_user.id)},
    ) as c:
        yield c
    app.dependency_overrides.clear()


@pytest_asyncio.fixture
async def owner_client() -> AsyncGenerator[AsyncClient, None]:
    _install_overrides()
    transport = ASGITransport(app=app)
    async with AsyncClient(
        transport=transport,
        base_url="http://test",
        headers={"X-Test-User": str(_fake_owner.id)},
    ) as c:
        yield c
    app.dependency_overrides.clear()


@pytest_asyncio.fixture
async def admin_client() -> AsyncGenerator[AsyncClient, None]:
    _install_overrides()
    transport = ASGITransport(app=app)
    async with AsyncClient(
        transport=transport,
        base_url="http://test",
        headers={"X-Test-User": str(_fake_admin.id)},
    ) as c:
        yield c
    app.dependency_overrides.clear()
