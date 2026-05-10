"""Lightweight chat moderation heuristics.

Runs on every outbound chat ``Message`` and flags anything that:

  - tries to share a phone number / email pre-confirmation
  - solicits an off-platform payment (typical scam pattern)
  - contains profanity / abusive language

We do *not* block the message — the platform's policy is to deliver
everything but raise a flag for the admin chat-monitor page so a
human can decide.  The original message body is preserved verbatim;
the message just gains ``is_flagged=True`` and a short
``flag_reason``.

This is intentionally a tiny pure-python regex check.  We keep it
in a separate module so it can be:

  - swapped for a smarter ML model later without touching the chat
    router;
  - unit-tested in isolation.
"""

from __future__ import annotations

import re
from typing import Iterable

# ── Phone-number patterns (Egypt + International) ────────
_PHONE_PATTERNS: tuple[re.Pattern[str], ...] = (
    re.compile(r"(?:\+?20|0)?1[0-2,5]\d{8}"),  # Egyptian mobile
    re.compile(r"\+?\d[\d\s\-]{8,}\d"),        # generic international
)
# Fast path: any digit run of 8+ characters is suspicious.
_DIGIT_RUN = re.compile(r"\d{8,}")

# ── Email pattern (lenient) ──────────────────────────────
_EMAIL = re.compile(r"[\w.+-]+@[\w-]+\.[a-z]{2,}", re.IGNORECASE)

# ── Off-platform payment vocabulary ──────────────────────
# Arabic + English keywords that historically correlate with users
# trying to dodge the platform fee.  Add to this list whenever ops
# spots a new pattern in production logs.
_OFF_PLATFORM = (
    # Arabic
    "فودافون كاش", "فودافون", "إنستاباي", "انستاباي", "instapay",
    "محفظة الكترونية", "محفظه الكترونيه", "تحويل بنكي", "تحويل بنكى",
    "حساب بنك", "خارج التطبيق", "خارج المنصة",
    "كاش بدون", "كاش مباشر", "تحويل اتصالات", "اتصالات كاش",
    "we cash", "بنكي مباشر", "ايبان", "iban",
    # English
    "vodafone cash", "etisalat cash", "bank transfer", "wire transfer",
    "off platform", "off-platform", "paypal", "western union",
    "outside the app", "venmo",
)

# ── Profanity (small starter list) ───────────────────────
_PROFANITY = (
    # Arabic (very common offensive terms)
    "ابن كلب", "كلب", "حيوان", "حقير", "وسخ", "غبي", "احمق",
    "اخرس", "زبالة", "زباله",
    # English
    "fuck", "shit", "asshole", "bitch", "idiot", "stupid",
)


def _normalise(text: str) -> str:
    """Lowercase + strip diacritics-friendly normalisation."""
    return text.lower()


def _matches_any(text: str, words: Iterable[str]) -> str | None:
    """Return the first matching word (lowercased) or None."""
    norm = _normalise(text)
    for w in words:
        if w in norm:
            return w
    return None


def scan(body: str) -> tuple[bool, str | None]:
    """Inspect a message body and return ``(is_flagged, reason)``.

    The reason is a short Arabic phrase suitable for showing in the
    admin's chat-monitor list; ``None`` means the message looked
    clean.
    """
    if not body or not body.strip():
        return False, None
    text = body.strip()

    # Phone numbers — anything resembling a long digit run.
    if _DIGIT_RUN.search(text) or any(p.search(text) for p in _PHONE_PATTERNS):
        return True, "محاولة مشاركة رقم هاتف"

    # Emails — same intent as phones.
    if _EMAIL.search(text):
        return True, "محاولة مشاركة بريد إلكتروني"

    # Off-platform payment language.
    hit = _matches_any(text, _OFF_PLATFORM)
    if hit is not None:
        return True, f"إشارة لدفع خارج المنصة ({hit})"

    # Profanity.
    hit = _matches_any(text, _PROFANITY)
    if hit is not None:
        return True, f"لغة مسيئة ({hit})"

    return False, None
