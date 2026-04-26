"""AWS S3 image upload / delete service.

Supported folders: properties/, avatars/, categories/
URL format: https://<bucket>.s3.<region>.amazonaws.com/<folder>/<filename>
"""

from __future__ import annotations

import os
import uuid
from typing import BinaryIO, Optional

import boto3
import structlog
from botocore.exceptions import BotoCoreError, ClientError, NoCredentialsError

from app.config import get_settings

logger = structlog.get_logger(__name__)

# ── Constants ──────────────────────────────────────────────────────────────
ALLOWED_FOLDERS = {"properties", "avatars", "categories"}
ALLOWED_CONTENT_TYPES = {
    "image/jpeg": "jpg",
    "image/png": "png",
    "image/webp": "webp",
    "image/gif": "gif",
}
MAX_FILE_SIZE_BYTES = 10 * 1024 * 1024  # 10 MB

# ── Lazy singleton client ──────────────────────────────────────────────────
_client = None


def _get_client():
    """Return a cached boto3 S3 client, creating it on first call."""
    global _client
    if _client is None:
        settings = get_settings()
        _client = boto3.client(
            "s3",
            aws_access_key_id=settings.AWS_ACCESS_KEY,
            aws_secret_access_key=settings.AWS_SECRET_KEY,
            region_name=settings.AWS_REGION,
        )
    return _client


def _build_url(key: str) -> str:
    """Build the full public URL for an S3 object key."""
    settings = get_settings()
    return (
        f"https://{settings.AWS_BUCKET_NAME}"
        f".s3.{settings.AWS_REGION}.amazonaws.com/{key}"
    )


def _extract_key(url: str) -> Optional[str]:
    """Extract the S3 object key from a full public URL.

    Returns None if the URL does not match the expected bucket/region prefix.
    """
    settings = get_settings()
    prefix = (
        f"https://{settings.AWS_BUCKET_NAME}"
        f".s3.{settings.AWS_REGION}.amazonaws.com/"
    )
    if not url.startswith(prefix):
        return None
    return url[len(prefix):]


# ── Public API ─────────────────────────────────────────────────────────────

async def upload_image(
    file: BinaryIO,
    folder: str = "properties",
    content_type: str = "image/jpeg",
) -> Optional[str]:
    """Upload an image to S3 and return its public URL.

    Args:
        file: A file-like object (readable binary stream).
        folder: One of ``properties``, ``avatars``, ``categories``.
        content_type: MIME type – must be in ``ALLOWED_CONTENT_TYPES``.

    Returns:
        The public URL on success, or ``None`` on failure.
    """
    # ── Validate folder ────────────────────────────────────────────────
    root_folder = folder.split("/")[0]
    if root_folder not in ALLOWED_FOLDERS:
        logger.error("s3_upload_invalid_folder", folder=folder, allowed=ALLOWED_FOLDERS)
        return None

    # ── Validate content type ──────────────────────────────────────────
    if content_type not in ALLOWED_CONTENT_TYPES:
        logger.error(
            "s3_upload_invalid_content_type",
            content_type=content_type,
            allowed=list(ALLOWED_CONTENT_TYPES),
        )
        return None

    # ── Validate file size ─────────────────────────────────────────────
    try:
        file.seek(0, os.SEEK_END)
        size = file.tell()
        file.seek(0)
        if size > MAX_FILE_SIZE_BYTES:
            logger.error(
                "s3_upload_file_too_large",
                size=size,
                max_size=MAX_FILE_SIZE_BYTES,
            )
            return None
        if size == 0:
            logger.error("s3_upload_empty_file")
            return None
    except (OSError, AttributeError) as exc:
        logger.warning("s3_upload_size_check_skipped", reason=str(exc))

    # ── Upload ─────────────────────────────────────────────────────────
    ext = ALLOWED_CONTENT_TYPES[content_type]
    key = f"{folder}/{uuid.uuid4().hex}.{ext}"

    try:
        client = _get_client()
        # NOTE: do NOT set ``ACL=public-read`` here.  Buckets created
        # after April 2023 default to ``BucketOwnerEnforced`` ownership
        # which rejects every per-object ACL with
        # ``AccessControlListNotSupported``.  Public read is granted
        # via the bucket policy instead (see deployment docs).
        client.upload_fileobj(
            file,
            get_settings().AWS_BUCKET_NAME,
            key,
            ExtraArgs={"ContentType": content_type},
        )
        url = _build_url(key)
        logger.info("s3_upload_success", key=key, url=url)
        return url
    except NoCredentialsError:
        logger.error("s3_upload_no_credentials")
        return None
    except ClientError as exc:
        logger.error("s3_upload_client_error", error=str(exc), key=key)
        return None
    except BotoCoreError as exc:
        logger.error("s3_upload_botocore_error", error=str(exc), key=key)
        return None
    except Exception as exc:  # noqa: BLE001
        logger.error("s3_upload_unexpected_error", error=str(exc), key=key)
        return None


async def delete_image(url: str) -> bool:
    """Delete an image from S3 by its full public URL.

    Returns:
        ``True`` if the object was deleted (or did not exist),
        ``False`` on error.
    """
    key = _extract_key(url)
    if key is None:
        logger.error("s3_delete_invalid_url", url=url)
        return False

    try:
        client = _get_client()
        client.delete_object(Bucket=get_settings().AWS_BUCKET_NAME, Key=key)
        logger.info("s3_delete_success", key=key)
        return True
    except NoCredentialsError:
        logger.error("s3_delete_no_credentials")
        return False
    except ClientError as exc:
        logger.error("s3_delete_client_error", error=str(exc), key=key)
        return False
    except BotoCoreError as exc:
        logger.error("s3_delete_botocore_error", error=str(exc), key=key)
        return False
    except Exception as exc:  # noqa: BLE001
        logger.error("s3_delete_unexpected_error", error=str(exc), key=key)
        return False
