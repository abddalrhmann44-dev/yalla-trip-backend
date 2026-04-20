"""Talaa – FastAPI application entry point."""

from __future__ import annotations

from contextlib import asynccontextmanager

import structlog
from fastapi import FastAPI, Request, status
from fastapi.exceptions import RequestValidationError
from fastapi.responses import ORJSONResponse

from app.config import get_settings
from app.logging_config import configure_logging
from app.middleware.cors_middleware import add_cors
from app.middleware.rate_limit import register as register_rate_limit
from app.middleware.request_id import register as register_request_id
from app.routers import (
    admin,
    analytics,
    audit_log,
    auth,
    availability,
    bookings,
    calendar,
    campaigns,
    chat,
    devices,
    favorites,
    health,
    notifications,
    offers,
    payments,
    payouts,
    pricing,
    promo_codes,
    wallet,
    properties,
    reports,
    reviews,
    phone_otp,
    seo,
    trip_posts,
    users,
    user_verifications,
    verifications,
)

configure_logging()
logger = structlog.get_logger(__name__)
settings = get_settings()

# Initialise Sentry BEFORE the FastAPI app is created so the SDK
# installs its Starlette integration during app construction.
from app.services.sentry_service import init_sentry  # noqa: E402

init_sentry()


# ── Lifespan (startup / shutdown) ─────────────────────────
@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info("app_startup", env=settings.APP_ENV)
    yield
    logger.info("app_shutdown")


# ── App factory ───────────────────────────────────────────
app = FastAPI(
    title="Talaa API",
    description="Production REST API for the Talaa travel & property booking platform – Egyptian market.",
    version="1.0.0",
    docs_url="/docs",
    redoc_url="/redoc",
    default_response_class=ORJSONResponse,
    lifespan=lifespan,
)

# ── Middleware ────────────────────────────────────────────
# Order matters — the last `add_middleware` runs FIRST on the way in
# (ASGI onion).  We want: request_id (outermost) → rate_limit → CORS.
add_cors(app)
register_rate_limit(app)
register_request_id(app)


# ── Global exception handlers ─────────────────────────────
def _sanitize_errors(errors: list[dict]) -> list[dict]:
    """Pydantic attaches the original exception object under ``ctx`` —
    those are not always JSON-serialisable (e.g. ``ValueError``).
    Strip them down to plain strings."""
    clean: list[dict] = []
    for err in errors:
        ctx = err.get("ctx")
        if isinstance(ctx, dict):
            err = {**err, "ctx": {k: str(v) for k, v in ctx.items()}}
        clean.append(err)
    return clean


@app.exception_handler(RequestValidationError)
async def validation_handler(request: Request, exc: RequestValidationError):
    errors = _sanitize_errors(exc.errors())
    messages = "; ".join(
        f"{'.'.join(str(part) for part in e.get('loc', []))}: {e.get('msg', '')}"
        for e in errors
    )
    return ORJSONResponse(
        status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
        content={
            "detail": f"Validation error – {messages}",
            "detail_ar": "خطأ في البيانات المدخلة",
            "errors": errors,
        },
    )


@app.exception_handler(Exception)
async def generic_handler(request: Request, exc: Exception):
    logger.error("unhandled_exception", path=request.url.path, error=str(exc))
    return ORJSONResponse(
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        content={
            "detail": "Internal server error",
            "detail_ar": "حدث خطأ في الخادم",
        },
    )


# ── Routers ───────────────────────────────────────────────
app.include_router(auth.router)
app.include_router(users.router)
app.include_router(properties.router)
app.include_router(bookings.router)
app.include_router(reviews.router)
app.include_router(reports.router)
app.include_router(promo_codes.router)
app.include_router(wallet.router)
app.include_router(payouts.router)
app.include_router(payments.router)
app.include_router(calendar.router)
app.include_router(availability.router)
app.include_router(pricing.router)
app.include_router(campaigns.router)
app.include_router(verifications.router)
app.include_router(user_verifications.router)
app.include_router(admin.router)
app.include_router(audit_log.router)
app.include_router(analytics.router)
app.include_router(notifications.router)
app.include_router(devices.router)
app.include_router(offers.router)
app.include_router(favorites.router)
app.include_router(chat.router)
app.include_router(phone_otp.router)
app.include_router(health.router)
app.include_router(seo.router)
app.include_router(trip_posts.router)
