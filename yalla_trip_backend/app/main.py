"""Yalla Trip – FastAPI application entry point."""

from __future__ import annotations

from contextlib import asynccontextmanager

import structlog
from fastapi import FastAPI, Request, status
from fastapi.exceptions import RequestValidationError
from fastapi.responses import ORJSONResponse

from app.config import get_settings
from app.middleware.cors_middleware import add_cors
from app.routers import auth, users, properties, bookings, reviews, payments, admin

logger = structlog.get_logger(__name__)
settings = get_settings()


# ── Lifespan (startup / shutdown) ─────────────────────────
@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info("app_startup", env=settings.APP_ENV)
    yield
    logger.info("app_shutdown")


# ── App factory ───────────────────────────────────────────
app = FastAPI(
    title="Yalla Trip API",
    description="Production REST API for the Yalla Trip travel & property booking platform – Egyptian market.",
    version="1.0.0",
    docs_url="/docs",
    redoc_url="/redoc",
    default_response_class=ORJSONResponse,
    lifespan=lifespan,
)

# ── Middleware ────────────────────────────────────────────
add_cors(app)


# ── Rate limiting (simple in-memory, use Redis in production) ─
from collections import defaultdict
import time

_hits: dict[str, list[float]] = defaultdict(list)


@app.middleware("http")
async def rate_limit_middleware(request: Request, call_next):
    client_ip = request.client.host if request.client else "unknown"
    now = time.time()
    window = 60.0

    # prune old entries
    _hits[client_ip] = [t for t in _hits[client_ip] if now - t < window]

    if len(_hits[client_ip]) >= settings.RATE_LIMIT_PER_MINUTE:
        return ORJSONResponse(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            content={
                "detail": "تم تجاوز حد الطلبات / Rate limit exceeded",
                "detail_ar": "تم تجاوز حد الطلبات",
            },
        )

    _hits[client_ip].append(now)
    response = await call_next(request)
    return response


# ── Global exception handlers ─────────────────────────────
@app.exception_handler(RequestValidationError)
async def validation_handler(request: Request, exc: RequestValidationError):
    errors = exc.errors()
    messages = "; ".join(
        f"{'.'.join(str(l) for l in e.get('loc', []))}: {e.get('msg', '')}"
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
app.include_router(payments.router)
app.include_router(admin.router)


# ── Health check ──────────────────────────────────────────
@app.get("/health", tags=["Health"])
async def health_check():
    return {
        "status": "healthy",
        "version": "1.0.0",
        "service": "Yalla Trip API",
    }
