"""Application settings loaded from environment / .env file."""

from __future__ import annotations

from functools import lru_cache
from typing import List

from pydantic import model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
        extra="ignore",
    )

    # ── App ───────────────────────────────────────────────────
    APP_ENV: str = "development"
    DEBUG: bool = True
    SECRET_KEY: str = "change-me"
    ALLOWED_ORIGINS: List[str] = ["*"]

    # ── Database ──────────────────────────────────────────────
    # ``DATABASE_URL`` may arrive in any of the common shapes:
    #   * ``postgres://…``                 – legacy Heroku/Railway
    #   * ``postgresql://…``               – modern, psycopg/psycopg2
    #   * ``postgresql+asyncpg://…``       – fully qualified async driver
    # ``_normalize_db_urls`` below upgrades it to the async form used
    # by the FastAPI engine and derives the sync form for Alembic.
    DATABASE_URL: str = "postgresql+asyncpg://yalla:yalla_secret@localhost:5432/yalla_trip"
    DATABASE_URL_SYNC: str = ""

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

    # ── Paymob ────────────────────────────────────────────────
    PAYMOB_API_KEY: str = ""
    PAYMOB_HMAC_SECRET: str = ""
    PAYMOB_IFRAME_ID: str = ""
    PAYMOB_INTEGRATION_CARD: str = ""
    PAYMOB_INTEGRATION_WALLET: str = ""

    # ── Payments mock mode ────────────────────────────────────
    # Allows the app to ship to the stores BEFORE we have a signed
    # contract with a real gateway (Paymob / Kashier).  When this is
    # ``True``, every provider returns a hosted "mock checkout" page
    # served by this same backend at ``/payments/mock-checkout/{ref}``
    # — the page lets the tester pick Success / Failure / Cancel and
    # mutates the payment state directly so the full booking flow can
    # be exercised end-to-end without any external API call.
    #
    # Flip to ``False`` once real gateway credentials are in place;
    # the Flutter app does NOT need a new build, the registry picks
    # the real ``PaymobGateway`` automatically.
    PAYMENTS_MOCK_MODE: bool = False
    # Public base URL used to build absolute checkout URLs (the WebView
    # cannot follow relative paths).  Falls back to the request host
    # when empty, but should be set explicitly in production.
    APP_BASE_URL: str = ""

    # ── Wallet top-up safety gate ─────────────────────────────
    # Direct calls to ``POST /wallet/me/topup`` credit the wallet
    # immediately — this was the original MVP behaviour and is
    # unsafe in production (anyone with a valid JWT could spoof
    # a top-up).  Defaults to ``False``: the endpoint then
    # refuses non-admin callers and the real money flow must go
    # through the Paymob iframe + webhook path.  Set to ``True``
    # in local dev / CI where the test-suite still relies on the
    # old trust-the-client behaviour.
    ALLOW_UNVERIFIED_WALLET_TOPUP: bool = False

    # ── FCM ───────────────────────────────────────────────────
    FCM_SERVER_KEY: str = ""

    # ── Sentry ────────────────────────────────────────────────
    # Leave empty to disable. When set, unhandled exceptions and
    # structured log errors are forwarded to the configured project.
    SENTRY_DSN: str = ""
    # 0.0 disables performance tracing. 0.1 = 10% sample.
    SENTRY_TRACES_SAMPLE_RATE: float = 0.0
    SENTRY_RELEASE: str = ""

    # ── JWT ───────────────────────────────────────────────────
    JWT_ALGORITHM: str = "HS256"
    JWT_EXPIRE_MINUTES: int = 1440  # 24 h
    JWT_REFRESH_EXPIRE_DAYS: int = 30

    # ── Rate Limit ────────────────────────────────────────────
    RATE_LIMIT_PER_MINUTE: int = 100

    # ── Platform ──────────────────────────────────────────────
    PLATFORM_FEE_PERCENT: float = 10.0
    # Days between booking check-out and payout eligibility.  Gives
    # the guest a window to dispute before money leaves the platform.
    PAYOUT_HOLD_DAYS: int = 1

    # ── Disbursement (Wave 26) ────────────────────────────────
    # ``mock`` runs an in-process simulator so dev / CI exercise the
    # full state machine without burning real money.  Flip to
    # ``kashier`` once the contract is signed and the credentials
    # below are populated.
    DISBURSE_PROVIDER: str = "mock"
    # Kashier credentials — only used when DISBURSE_PROVIDER == "kashier".
    # Keep these out of the repo: load from Railway / docker secrets.
    KASHIER_DISBURSE_BASE_URL: str = "https://api.kashier.io"
    KASHIER_DISBURSE_MERCHANT_ID: str = ""
    KASHIER_DISBURSE_API_KEY: str = ""
    KASHIER_DISBURSE_SECRET: str = ""
    # 48 h is the SLA Kashier publishes for IBAN transfers.  After
    # this many hours in ``processing`` the reconciliation cron will
    # poll the gateway and (eventually) flag the payout for admin
    # attention.
    DISBURSE_SLA_HOURS: int = 48
    # How often to run the reconciliation sweep (minutes).  Hourly
    # is a good default — fast enough to keep the host's "stuck"
    # window short, slow enough to avoid polling abuse against the
    # gateway.
    DISBURSE_RECONCILE_INTERVAL_MIN: int = 60

    # ── Referrals / Wallet ────────────────────────────────────
    # Fixed EGP credit dropped into the referrer's wallet once the
    # invitee completes their first paid booking.  Set to 0 to
    # disable the programme entirely.
    REFERRAL_REWARD_AMOUNT: float = 100.0
    # Maximum number of referral rewards a single user can earn in
    # total.  After hitting this cap, further invitees still sign up and
    # their pending Referral rows transition to ``rewarded`` status, but
    # no wallet credit is paid.  Set to 0 to disable the cap.
    REFERRAL_REWARD_MAX_COUNT: int = 3
    # Optional newcomer bonus credited on signup (pre-any-booking).
    SIGNUP_BONUS_AMOUNT: float = 0.0
    # Percentage of a booking's subtotal that may be paid from wallet
    # credit.  Capped so fees + payouts cover the checkout cost.
    WALLET_MAX_REDEEM_PERCENT: float = 50.0
    # Public base URL used to build shareable referral links
    # (e.g. https://yalla-trip.com/signup?ref=ABC123).
    PUBLIC_APP_URL: str = "https://talaa.app"

    # ── Deep links / SEO (Wave 20) ────────────────────────────
    # Android app package (for assetlinks.json) and iOS App Store id
    # (for apple-app-site-association / Smart App Banner meta).  Leave
    # empty to omit the corresponding tags.
    ANDROID_PACKAGE_NAME: str = "com.yallatrip.app"
    ANDROID_SHA256_FINGERPRINTS: str = ""  # comma-separated hex SHA-256
    IOS_APP_ID: str = ""       # numeric App Store id, e.g. "1234567890"
    IOS_TEAM_ID: str = ""      # e.g. "ABCDE12345"
    IOS_BUNDLE_ID: str = "com.yallatrip.app"

    # ── Admin bootstrap ───────────────────────────────────────
    # Comma-separated list of emails that become admin on first login
    # and are auto-promoted on subsequent logins. Works with ANY Firebase
    # auth provider (Google Sign-In, email/password, phone-linked email).
    #
    # The defaults below are the Talaa founding team — override in .env
    # for different deployments. Case-insensitive.
    ADMIN_EMAILS: str = "qaran12121@gmail.com,abdalrhamnmohamed4@gmail.com"

    @property
    def admin_emails_set(self) -> set[str]:
        return {
            e.strip().lower()
            for e in self.ADMIN_EMAILS.split(",")
            if e.strip()
        }

    # ── Database URL normalisation ────────────────────────────
    # Runs after the BaseSettings has loaded env vars / defaults.
    # Handles the three real-world shapes of ``DATABASE_URL`` so
    # dropping into Railway / Heroku / local-Docker all "just works".
    @model_validator(mode="after")
    def _normalize_db_urls(self) -> "Settings":
        url = self.DATABASE_URL or ""

        # 1) Legacy ``postgres://`` → canonical ``postgresql://``.
        #    SQLAlchemy 2 rejects the old scheme outright.
        if url.startswith("postgres://"):
            url = "postgresql://" + url[len("postgres://"):]

        # 2) Inject the asyncpg driver for the FastAPI engine if the
        #    URL arrived in plain ``postgresql://`` form.
        if url.startswith("postgresql://") and "+asyncpg" not in url:
            url = url.replace("postgresql://", "postgresql+asyncpg://", 1)

        self.DATABASE_URL = url

        # 3) Alembic / psycopg2 want the plain scheme — auto-derive
        #    from the async URL whenever the operator hasn't set it.
        if not self.DATABASE_URL_SYNC:
            self.DATABASE_URL_SYNC = url.replace("+asyncpg", "", 1)

        return self

    # ── Production safety gate ───────────────────────────────
    # Refuses to boot when APP_ENV=="production" and any of the
    # well-known insecure defaults are still in place.  Catching
    # these at startup beats discovering them after a breach.
    @model_validator(mode="after")
    def _guard_production(self) -> "Settings":
        if self.APP_ENV != "production":
            return self

        problems: list[str] = []

        bad_keys = {"", "change-me", "changeme", "secret", "dev"}
        if (self.SECRET_KEY or "").strip().lower() in bad_keys:
            problems.append(
                "SECRET_KEY is set to an insecure default — "
                "generate at least 32 random bytes (e.g. "
                "`python -c 'import secrets; print(secrets.token_urlsafe(48))'`) "
                "and set it in the environment."
            )
        elif len(self.SECRET_KEY) < 32:
            problems.append(
                f"SECRET_KEY is only {len(self.SECRET_KEY)} chars — "
                "use at least 32."
            )

        if self.DEBUG:
            problems.append("DEBUG must be False in production.")

        if "*" in self.ALLOWED_ORIGINS:
            problems.append(
                "ALLOWED_ORIGINS contains the wildcard '*' — list the "
                "exact origin(s) (e.g. https://talaa.app) instead."
            )

        if self.ALLOW_UNVERIFIED_WALLET_TOPUP:
            problems.append(
                "ALLOW_UNVERIFIED_WALLET_TOPUP must be False in "
                "production — wallet top-ups must go through the "
                "Paymob webhook."
            )

        if problems:
            raise ValueError(
                "Refusing to start with insecure production config:\n  - "
                + "\n  - ".join(problems)
            )
        return self


@lru_cache
def get_settings() -> Settings:
    return Settings()
