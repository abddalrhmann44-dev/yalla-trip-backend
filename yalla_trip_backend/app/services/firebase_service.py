"""Firebase Admin SDK integration – token verification."""

from __future__ import annotations

import json
import structlog
import firebase_admin
from firebase_admin import auth as firebase_auth, credentials

from app.config import get_settings

logger = structlog.get_logger(__name__)
settings = get_settings()

_app: firebase_admin.App | None = None


def _init_firebase() -> None:
    """Lazy-initialise Firebase Admin SDK."""
    global _app
    if _app is not None:
        return
    try:
        cred_dict = json.loads(settings.FIREBASE_CREDENTIALS_JSON)
        cred = credentials.Certificate(cred_dict)
        _app = firebase_admin.initialize_app(cred)
        logger.info("firebase_initialized")
    except Exception as exc:
        logger.warning("firebase_init_skipped", reason=str(exc))


async def verify_firebase_token(token: str) -> dict | None:
    """Verify a Firebase ID token and return decoded claims.

    Returns ``None`` when verification fails.
    """
    _init_firebase()
    if _app is None:
        logger.error("firebase_not_initialized")
        return None
    try:
        decoded = firebase_auth.verify_id_token(token, check_revoked=True)
        logger.info("firebase_token_verified", uid=decoded.get("uid"))
        return decoded
    except firebase_auth.RevokedIdTokenError:
        logger.warning("firebase_token_revoked")
        return None
    except firebase_auth.InvalidIdTokenError:
        logger.warning("firebase_token_invalid")
        return None
    except Exception as exc:
        logger.error("firebase_verify_error", error=str(exc))
        return None


async def get_firebase_user(uid: str) -> dict | None:
    """Fetch user record from Firebase by UID."""
    _init_firebase()
    if _app is None:
        return None
    try:
        user = firebase_auth.get_user(uid)
        return {
            "uid": user.uid,
            "email": user.email,
            "phone_number": user.phone_number,
            "display_name": user.display_name,
            "photo_url": user.photo_url,
        }
    except Exception as exc:
        logger.error("firebase_get_user_error", error=str(exc))
        return None
