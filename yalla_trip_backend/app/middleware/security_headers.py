"""Security-headers middleware.

Adds the baseline set of response headers every hardened HTTP service
should send.  None of these affect functional behaviour for a
JSON-only API consumed by the Flutter client — they're purely
defense-in-depth against browsers that accidentally load the API
(e.g. via /docs) and against downgrade / sniffing attacks.

Headers set:
    * ``Strict-Transport-Security`` — only in production, since local
      dev typically runs plain HTTP.  Tells browsers to refuse HTTP
      for the next 2 years and enables preload / subdomains.
    * ``X-Content-Type-Options: nosniff`` — stops the browser from
      second-guessing our Content-Type (mitigates MIME-confusion XSS).
    * ``X-Frame-Options: DENY`` — forbids framing of any page we
      serve (clickjacking).
    * ``Referrer-Policy: strict-origin-when-cross-origin`` — don't
      leak full URLs to third parties.
    * ``Permissions-Policy`` — disables legacy features the API
      never needs (camera, microphone, geolocation in the browser
      response scope).
    * ``X-Permitted-Cross-Domain-Policies: none`` — locks out Flash
      / legacy Adobe readers that honour crossdomain.xml.
"""

from __future__ import annotations

from fastapi import FastAPI, Request
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.responses import Response

from app.config import get_settings


class SecurityHeadersMiddleware(BaseHTTPMiddleware):
    """Attach a hardened set of security headers to every response."""

    def __init__(self, app, *, enable_hsts: bool) -> None:
        super().__init__(app)
        self._enable_hsts = enable_hsts

    async def dispatch(self, request: Request, call_next) -> Response:
        response = await call_next(request)

        # Defaults — always safe to set.
        response.headers.setdefault("X-Content-Type-Options", "nosniff")
        response.headers.setdefault("X-Frame-Options", "DENY")
        response.headers.setdefault(
            "Referrer-Policy", "strict-origin-when-cross-origin"
        )
        response.headers.setdefault(
            "Permissions-Policy",
            "accelerometer=(), camera=(), geolocation=(), gyroscope=(), "
            "magnetometer=(), microphone=(), payment=(), usb=()",
        )
        response.headers.setdefault(
            "X-Permitted-Cross-Domain-Policies", "none"
        )

        # HSTS must only be enabled once we're confident the host is
        # HTTPS-only — browsers cache the directive for the given
        # ``max-age`` and will refuse plain-HTTP access for that long.
        if self._enable_hsts:
            response.headers.setdefault(
                "Strict-Transport-Security",
                "max-age=63072000; includeSubDomains; preload",
            )

        return response


def register(app: FastAPI) -> None:
    """Install the security-headers middleware.

    HSTS is enabled only when ``APP_ENV=="production"`` to keep local
    dev on plain HTTP comfortable.
    """
    settings = get_settings()
    app.add_middleware(
        SecurityHeadersMiddleware,
        enable_hsts=settings.APP_ENV == "production",
    )
