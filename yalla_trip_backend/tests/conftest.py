"""Shared test fixtures – async client, in-memory DB override."""

from __future__ import annotations

import asyncio
from typing import AsyncGenerator

import pytest
import pytest_asyncio
from httpx import ASGITransport, AsyncClient
from sqlalchemy.ext.asyncio import (
    AsyncSession,
    async_sessionmaker,
    create_async_engine,
)

from app.database import Base, get_db
from app.main import app
from app.middleware.auth_middleware import create_access_token, get_current_user
from app.models.user import User, UserRole

# ── In-memory SQLite for tests ────────────────────────────
TEST_DB_URL = "sqlite+aiosqlite:///:memory:"

engine = create_async_engine(TEST_DB_URL, echo=False)
TestSession = async_sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)


async def _override_get_db() -> AsyncGenerator[AsyncSession, None]:
    async with TestSession() as session:
        try:
            yield session
            await session.commit()
        except Exception:
            await session.rollback()
            raise


# ── Fake user for auth bypass ─────────────────────────────
_fake_user = User(
    id=1,
    firebase_uid="test_uid",
    name="Test User",
    email="test@yallatrip.com",
    phone="+201000000000",
    role=UserRole.guest,
    is_verified=True,
    is_active=True,
)

_fake_owner = User(
    id=2,
    firebase_uid="owner_uid",
    name="Test Owner",
    email="owner@yallatrip.com",
    phone="+201111111111",
    role=UserRole.owner,
    is_verified=True,
    is_active=True,
)

_fake_admin = User(
    id=3,
    firebase_uid="admin_uid",
    name="Admin",
    email="admin@yallatrip.com",
    phone="+201222222222",
    role=UserRole.admin,
    is_verified=True,
    is_active=True,
)


@pytest.fixture(scope="session")
def event_loop():
    loop = asyncio.new_event_loop()
    yield loop
    loop.close()


@pytest_asyncio.fixture(autouse=True)
async def setup_db():
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    yield
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.drop_all)


def _override_auth(user: User):
    async def _dep():
        return user
    return _dep


@pytest_asyncio.fixture
async def guest_client() -> AsyncGenerator[AsyncClient, None]:
    app.dependency_overrides[get_db] = _override_get_db
    app.dependency_overrides[get_current_user] = _override_auth(_fake_user)
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as c:
        yield c
    app.dependency_overrides.clear()


@pytest_asyncio.fixture
async def owner_client() -> AsyncGenerator[AsyncClient, None]:
    app.dependency_overrides[get_db] = _override_get_db
    app.dependency_overrides[get_current_user] = _override_auth(_fake_owner)
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as c:
        yield c
    app.dependency_overrides.clear()


@pytest_asyncio.fixture
async def admin_client() -> AsyncGenerator[AsyncClient, None]:
    app.dependency_overrides[get_db] = _override_get_db
    app.dependency_overrides[get_current_user] = _override_auth(_fake_admin)
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as c:
        yield c
    app.dependency_overrides.clear()
