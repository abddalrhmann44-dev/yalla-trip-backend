"""Fawry payment gateway integration (Egyptian market)."""

from __future__ import annotations

import hashlib
import time
from typing import Any

import httpx
import structlog

from app.config import get_settings

logger = structlog.get_logger(__name__)
settings = get_settings()


def _fawry_signature(*parts: str) -> str:
    """SHA-256 signature expected by Fawry."""
    raw = "".join(parts)
    return hashlib.sha256(raw.encode()).hexdigest()


async def initiate_payment(
    merchant_ref: str,
    amount: float,
    customer_email: str,
    customer_phone: str,
    description: str = "Talaa Booking",
) -> dict[str, Any]:
    """Create a Fawry charge request and return the response payload.

    Returns a dict with ``referenceNumber``, ``statusCode``, etc.
    """
    signature = _fawry_signature(
        settings.FAWRY_MERCHANT_CODE,
        merchant_ref,
        customer_phone,
        f"{amount:.2f}",
        settings.FAWRY_SECRET_KEY,
    )

    payload = {
        "merchantCode": settings.FAWRY_MERCHANT_CODE,
        "merchantRefNum": merchant_ref,
        "customerMobile": customer_phone,
        "customerEmail": customer_email,
        "customerProfileId": customer_phone,
        "amount": round(amount, 2),
        "currencyCode": "EGP",
        "description": description,
        "paymentExpiry": int(time.time() * 1000) + 24 * 60 * 60 * 1000,  # +24 h
        "chargeItems": [
            {
                "itemId": merchant_ref,
                "description": description,
                "price": round(amount, 2),
                "quantity": 1,
            }
        ],
        "signature": signature,
        "paymentMethod": "PAYATFAWRY",
    }

    url = f"{settings.FAWRY_BASE_URL}/ECommerceWeb/Fawry/payments/charge"
    async with httpx.AsyncClient(timeout=30) as client:
        resp = await client.post(url, json=payload)
        data = resp.json()
        logger.info("fawry_charge_response", ref=merchant_ref, status=data.get("statusCode"))
        return data


async def check_payment_status(merchant_ref: str) -> dict[str, Any]:
    """Query Fawry for payment status."""
    signature = _fawry_signature(
        settings.FAWRY_MERCHANT_CODE,
        merchant_ref,
        settings.FAWRY_SECRET_KEY,
    )
    url = (
        f"{settings.FAWRY_BASE_URL}/ECommerceWeb/Fawry/payments/status/v2"
        f"?merchantCode={settings.FAWRY_MERCHANT_CODE}"
        f"&merchantRefNumber={merchant_ref}"
        f"&signature={signature}"
    )
    async with httpx.AsyncClient(timeout=30) as client:
        resp = await client.get(url)
        data = resp.json()
        logger.info("fawry_status_response", ref=merchant_ref, status=data.get("paymentStatus"))
        return data


def verify_webhook_signature(payload: dict) -> bool:
    """Verify Fawry callback signature."""
    expected = _fawry_signature(
        payload.get("fawryRefNumber", ""),
        payload.get("merchantRefNum", ""),
        str(payload.get("paymentAmount", "")),
        str(payload.get("orderAmount", "")),
        payload.get("orderStatus", ""),
        payload.get("paymentMethod", ""),
        settings.FAWRY_SECRET_KEY,
    )
    return expected == payload.get("messageSignature", "")
