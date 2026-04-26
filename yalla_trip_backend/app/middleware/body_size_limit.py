"""Global request body size limit.

FastAPI / Starlette don't cap request bodies by default — an attacker
can send a multi-gigabyte JSON payload and pin a worker's RAM for the
whole parse.  This middleware rejects anything larger than
``MAX_REQUEST_BYTES`` **before** the body is consumed.

Two checks run in sequence:

1. **Content-Length header** — the cheap case: if the client is
   honest about the size, we fail fast with 413 and never read a
   byte.
2. **Streaming guard** — some clients omit Content-Length (chunked
   transfer) so we also wrap ``receive()`` to count bytes as they
   arrive and abort mid-stream if the limit is exceeded.

Multipart file uploads have their own per-file ceiling inside the
S3 upload service, but this middleware provides the global belt-
and-braces so no endpoint can be surprised.
"""

from __future__ import annotations

from fastapi import FastAPI, Request, status
from fastapi.responses import ORJSONResponse
from starlette.middleware.base import BaseHTTPMiddleware


# Per-request ceiling — 25 MB covers a batch of photos for a
# property listing (the heaviest legit payload we currently accept)
# with comfortable headroom.
MAX_REQUEST_BYTES: int = 25 * 1024 * 1024


class BodySizeLimitMiddleware(BaseHTTPMiddleware):
    def __init__(self, app, *, max_bytes: int = MAX_REQUEST_BYTES) -> None:
        super().__init__(app)
        self._max_bytes = max_bytes

    async def dispatch(self, request: Request, call_next):
        # 1. Fast path — trust the client's Content-Length.
        cl = request.headers.get("content-length")
        if cl is not None:
            try:
                if int(cl) > self._max_bytes:
                    return _too_large(self._max_bytes)
            except ValueError:
                return ORJSONResponse(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    content={"detail": "Malformed Content-Length header"},
                )

        # 2. Streaming guard — wrap ``receive`` so we cut off chunked
        #    uploads that lie about their size.
        received = 0
        original_receive = request.receive

        async def guarded_receive():
            nonlocal received
            message = await original_receive()
            if message["type"] == "http.request":
                body = message.get("body") or b""
                received += len(body)
                if received > self._max_bytes:
                    # Drain the rest so the client sees a clean 413
                    # rather than a reset connection.
                    raise _BodyTooLarge()
            return message

        # Rebind the scope's receive callable.  Starlette's
        # ``Request`` is immutable so we mutate the underlying
        # ``_receive`` slot via the public attribute.
        request._receive = guarded_receive  # type: ignore[attr-defined]

        try:
            return await call_next(request)
        except _BodyTooLarge:
            return _too_large(self._max_bytes)


class _BodyTooLarge(Exception):
    """Internal signal raised by the streaming guard."""


def _too_large(limit: int) -> ORJSONResponse:
    return ORJSONResponse(
        status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
        content={
            "detail": (
                f"الطلب أكبر من الحد المسموح ({limit // (1024 * 1024)} MB) / "
                f"Request body exceeds the {limit // (1024 * 1024)} MB limit"
            ),
        },
    )


def register(app: FastAPI) -> None:
    app.add_middleware(BodySizeLimitMiddleware)
