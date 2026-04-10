"""Application settings loaded from environment / .env file."""

from __future__ import annotations

from functools import lru_cache
from typing import List

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
    )

    # ── App ───────────────────────────────────────────────────
    APP_ENV: str = "development"
    DEBUG: bool = True
    SECRET_KEY: str = "change-me"
    ALLOWED_ORIGINS: List[str] = ["*"]

    # ── Database ──────────────────────────────────────────────
    DATABASE_URL: str = "postgresql+asyncpg://yalla:yalla_secret@localhost:5432/yalla_trip"
    DATABASE_URL_SYNC: str = "postgresql://yalla:yalla_secret@localhost:5432/yalla_trip"

    # ── Redis ─────────────────────────────────────────────────
    REDIS_URL: str = "redis://localhost:6379/0"

    # ── Firebase ──────────────────────────────────────────────
    FIREBASE_CREDENTIALS_JSON: str = "{}"

    # ── AWS S3 ────────────────────────────────────────────────
    AWS_ACCESS_KEY: str = ""
    AWS_SECRET_KEY: str = ""
    AWS_BUCKET_NAME: str = "yalla-trip-media"
    AWS_REGION: str = "eu-south-1"

    # ── Fawry ─────────────────────────────────────────────────
    FAWRY_MERCHANT_CODE: str = ""
    FAWRY_SECRET_KEY: str = ""
    FAWRY_BASE_URL: str = "https://atfawry.fawrystaging.com"

    # ── FCM ───────────────────────────────────────────────────
    FCM_SERVER_KEY: str = ""

    # ── JWT ───────────────────────────────────────────────────
    JWT_ALGORITHM: str = "HS256"
    JWT_EXPIRE_MINUTES: int = 1440  # 24 h
    JWT_REFRESH_EXPIRE_DAYS: int = 30

    # ── Rate Limit ────────────────────────────────────────────
    RATE_LIMIT_PER_MINUTE: int = 100

    # ── Platform ──────────────────────────────────────────────
    PLATFORM_FEE_PERCENT: float = 8.0


@lru_cache
def get_settings() -> Settings:
    return Settings()
