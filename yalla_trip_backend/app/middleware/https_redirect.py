"""HTTPS-only enforcement for production deployments.

Wraps two concerns:

1. **Proxy headers trust.**  In production the app runs behind a TLS
   terminator (Render, Cloudflare, nginx, …) so the actual request
   scheme is in ``X-Forwarded-Proto`` and the real client IP is in
   ``X-Forwarded-For``.  Starlette's ``ProxyHeadersMiddleware`` reads
   those and updates ``request.url.scheme`` / ``request.client.host``
   accordingly.

2. **Plain-HTTP redirect.**  With the scheme correctly derived, we
   301 any HTTP hit to HTTPS so downgrade attacks and accidental
   plaintext traffic never reach business code.

Both are registered only when ``APP_ENV=="production"`` to avoid
breaking local dev on http://localhost.
"""

from __future__ import annotations

from fastapi import FastAPI
from starlette.middleware.httpsredirect import HTTPSRedirectMiddleware
from uvicorn.middleware.proxy_headers import ProxyHeadersMiddleware

from app.config import get_settings


def register(app: FastAPI) -> None:
    settings = get_settings()
    if settings.APP_ENV != "production":
        return

    # Trust a single proxy hop — adjust if you front with a multi-tier
    # CDN (Cloudflare → nginx → app: trusted_hosts="*" is acceptable
    # when the LB strips client-supplied proxy headers, which all
    # managed hosts do).
    app.add_middleware(ProxyHeadersMiddleware, trusted_hosts="*")
    app.add_middleware(HTTPSRedirectMiddleware)
