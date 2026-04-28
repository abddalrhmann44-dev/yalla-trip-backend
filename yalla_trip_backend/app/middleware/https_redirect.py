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
from starlette.types import ASGIApp, Receive, Scope, Send

from app.config import get_settings


# Probe paths that the platform load balancer hits on the internal
# network over plain HTTP without X-Forwarded-Proto.  Redirecting
# them to HTTPS makes the LB see a 3xx and mark the replica
# unhealthy, which Railway then refuses to promote — observed in
# production as "Network › Healthcheck failure" with the LB never
# routing traffic to the new container.
_HEALTHCHECK_PATHS: frozenset[str] = frozenset({
    "/health",
    "/health/",
    "/health/live",
    "/health/ready",
})


class HealthAwareHTTPSRedirect(HTTPSRedirectMiddleware):
    """``HTTPSRedirectMiddleware`` that lets healthcheck probes through.

    Behaviour is identical to the upstream middleware for every path
    except the small whitelist above, which is allowed to respond on
    plain HTTP so internal LB probes succeed.  External clients still
    can't reach those paths over HTTP because the platform terminator
    upgrades them to HTTPS before the request hits this app.
    """

    def __init__(self, app: ASGIApp) -> None:
        super().__init__(app)
        self._app = app

    async def __call__(self, scope: Scope, receive: Receive, send: Send) -> None:
        if scope.get("type") == "http" and scope.get("path") in _HEALTHCHECK_PATHS:
            await self._app(scope, receive, send)
            return
        await super().__call__(scope, receive, send)


def register(app: FastAPI) -> None:
    settings = get_settings()
    if settings.APP_ENV != "production":
        return

    # Proxy header handling lives at the uvicorn transport layer now —
    # ``--proxy-headers --forwarded-allow-ips=*`` in the start command
    # rewrites ``scope["scheme"]`` from ``X-Forwarded-Proto`` before
    # any ASGI middleware sees the request.  That sidesteps the
    # ordering trap where ``HTTPSRedirectMiddleware`` would otherwise
    # inspect the raw uvicorn scheme ("http") and 307 every external
    # request back to itself in a redirect loop.
    app.add_middleware(HealthAwareHTTPSRedirect)
