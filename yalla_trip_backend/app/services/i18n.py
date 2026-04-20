"""Backend i18n helper – resolve bilingual messages based on request locale.

Usage in routers::

    from fastapi import Request
    from app.services.i18n import t

    raise HTTPException(status_code=404, detail=t(request, "property.not_found"))

The preferred language is taken from the ``Accept-Language`` HTTP header
(first 2-letter code).  Falls back to Arabic if unknown.

All strings live in the ``_MESSAGES`` dictionary below, keyed by dotted
namespace.  Add new keys here, never in the routers.
"""

from __future__ import annotations

from typing import Optional

from fastapi import Request


# ── Supported locales ────────────────────────────────────────
DEFAULT_LOCALE = "ar"
SUPPORTED_LOCALES = ("ar", "en")


# ── Message catalogue ───────────────────────────────────────
_MESSAGES: dict[str, dict[str, str]] = {
    # Auth / users
    "auth.invalid_credentials": {
        "ar": "بيانات الدخول غير صحيحة",
        "en": "Invalid credentials",
    },
    "auth.account_disabled": {
        "ar": "الحساب معطل",
        "en": "Account disabled",
    },
    "auth.email_taken": {
        "ar": "البريد الإلكتروني مستخدم بالفعل",
        "en": "Email already registered",
    },
    "auth.otp_invalid": {
        "ar": "رمز التحقق غير صحيح",
        "en": "Invalid verification code",
    },
    # Property
    "property.not_found": {
        "ar": "العقار غير موجود",
        "en": "Property not found",
    },
    "property.not_owner": {
        "ar": "ليس لديك صلاحية على هذا العقار",
        "en": "You do not own this property",
    },
    "property.not_available": {
        "ar": "العقار غير متاح للحجز",
        "en": "Property is not available",
    },
    # Booking
    "booking.not_found": {
        "ar": "الحجز غير موجود",
        "en": "Booking not found",
    },
    "booking.dates_conflict": {
        "ar": "التواريخ غير متاحة",
        "en": "Dates not available",
    },
    "booking.dates_blocked": {
        "ar": "التواريخ مغلقة من قبل المالك",
        "en": "Dates blocked by host",
    },
    "booking.cannot_cancel": {
        "ar": "لا يمكن إلغاء هذا الحجز",
        "en": "Cannot cancel this booking",
    },
    "booking.invalid_dates": {
        "ar": "تواريخ غير صحيحة",
        "en": "Invalid dates",
    },
    # Generic
    "generic.forbidden": {
        "ar": "ليس لديك صلاحية",
        "en": "Forbidden",
    },
    "generic.not_found": {
        "ar": "غير موجود",
        "en": "Not found",
    },
    "generic.server_error": {
        "ar": "خطأ في الخادم",
        "en": "Server error",
    },
    "generic.rate_limited": {
        "ar": "عدد محاولاتك كبير، جرّب لاحقًا",
        "en": "Too many requests, try again later",
    },
    # Payments / wallet
    "payment.insufficient_funds": {
        "ar": "رصيد غير كافٍ",
        "en": "Insufficient funds",
    },
    "payment.invalid_promo": {
        "ar": "كود الخصم غير صحيح",
        "en": "Invalid promo code",
    },
    # Verification
    "verification.pending": {
        "ar": "التحقق قيد المراجعة",
        "en": "Verification pending",
    },
    "verification.rejected": {
        "ar": "التحقق مرفوض",
        "en": "Verification rejected",
    },
    "verification.required": {
        "ar": "يجب توثيق حسابك أولاً",
        "en": "Account verification required",
    },
}


# ── Public API ───────────────────────────────────────────────

def resolve_locale(request: Optional[Request]) -> str:
    """Extract the preferred locale from the request, default ``ar``."""
    if request is None:
        return DEFAULT_LOCALE
    header = request.headers.get("accept-language", "")
    for chunk in header.split(","):
        code = chunk.strip().split(";")[0].split("-")[0].lower()
        if code in SUPPORTED_LOCALES:
            return code
    return DEFAULT_LOCALE


def t(request: Optional[Request], key: str, **kwargs: object) -> str:
    """Translate ``key`` using the request's locale.

    If the key or locale is missing, falls back to Arabic, then to the
    raw key as a last resort.  ``kwargs`` are substituted into the
    resulting string with ``str.format``.
    """
    locale = resolve_locale(request)
    entry = _MESSAGES.get(key)
    if entry is None:
        return key
    text = entry.get(locale) or entry.get(DEFAULT_LOCALE) or key
    if kwargs:
        try:
            return text.format(**kwargs)
        except (KeyError, IndexError):
            return text
    return text


def bilingual(key: str) -> str:
    """Return an ``"AR / EN"`` string – useful when no request context exists."""
    entry = _MESSAGES.get(key)
    if entry is None:
        return key
    ar = entry.get("ar", key)
    en = entry.get("en", key)
    return f"{ar} / {en}"
