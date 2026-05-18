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

from typing import Iterable

from app.services.chat_sanitizer import detect_contact_attempt

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

# ── Phone-request / hand-off vocabulary ──────────────────
# Even when the message contains *no* digits, certain phrases reliably
# indicate the user is asking for or offering an off-platform contact
# channel.  Catching this layer lets the chat-monitor team intervene
# before the next message exchange completes the leak.
_CONTACT_REQUEST = (
    # Arabic — phone request / offer
    "ابعتلي رقم", "ابعتلى رقم", "ابعتلي نمرت", "ابعتلى نمرت",
    "ابعتلي تليفون", "ابعتلى تليفون",
    "اديني رقم", "ادينى رقم", "اديني نمرت", "ادينى نمرت",
    "ادينى تليفون", "اديني تليفون",
    "هتبعت رقم", "هبعتلك رقم", "هبعت رقم",
    "خد رقمي", "خد رقمى", "خدي رقمي", "خدى رقمى",
    "كلمني على", "كلمنى على", "اتصل بيا", "اتصل بى",
    "كلمني واتس", "كلمنى واتس", "كلمني على واتس",
    "رقمي يبدأ", "رقمى يبدأ", "نمرتي تبدأ", "نمرتى تبدا",
    "ابعت رقمك", "ابعتلي تليجرام", "ابعتلي انستا",
    # English
    "send me your number", "give me your number",
    "your phone number", "your whatsapp", "your telegram",
    "text me on", "call me on", "dm me on",
    "my number is", "my number starts",
    "reach me on", "contact me on",
)

# ── Profanity (small starter list) ───────────────────────
_PROFANITY = (
    # Arabic (very common offensive terms)
    "ابن كلب", "كلب", "حيوان", "حقير", "وسخ", "غبي", "احمق",
    "اخرس", "زبالة", "زباله",
    # English
    "fuck", "shit", "asshole", "bitch", "idiot", "stupid",
)


def _matches_any(text: str, words: Iterable[str]) -> str | None:
    """Return the first matching word (lowercased) or None."""
    norm = text.lower()
    for w in words:
        if w in norm:
            return w
    return None


def scan(body: str) -> tuple[bool, str | None]:
    """Inspect a message body and return ``(is_flagged, reason)``.

    The reason is a short Arabic phrase suitable for showing in the
    admin's chat-monitor list; ``None`` means the message looked
    clean.

    Detection priority (first match wins):
      1. Phone / email / social-handle leak — delegated to the smart
         ``chat_sanitizer.detect_contact_attempt`` so spelled-out
         digits, homoglyph obfuscation and ``@handle`` mentions are
         all caught.
      2. Indirect contact-request phrases (Arabic + English).
      3. Off-platform payment language.
      4. Profanity.
    """
    if not body or not body.strip():
        return False, None
    text = body.strip()

    # 1. Direct + obfuscated phone / email / social leaks.
    direct = detect_contact_attempt(text)
    if direct is not None:
        return True, direct

    # 2. Indirect contact-request language ("ابعتلي رقمك", ...).
    hit = _matches_any(text, _CONTACT_REQUEST)
    if hit is not None:
        return True, "طلب أو عرض تواصل خارج المنصة"

    # 3. Off-platform payment language.
    hit = _matches_any(text, _OFF_PLATFORM)
    if hit is not None:
        return True, f"إشارة لدفع خارج المنصة ({hit})"

    # 4. Profanity.
    hit = _matches_any(text, _PROFANITY)
    if hit is not None:
        return True, f"لغة مسيئة ({hit})"

    return False, None
