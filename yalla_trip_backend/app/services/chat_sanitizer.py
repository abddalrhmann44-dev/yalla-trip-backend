"""Sanitiser for free-form chat messages (Wave 23).

Purpose: prevent guests and owners from exchanging raw phone numbers
in plain text before a booking is *confirmed*.  Talaa reveals each
party's full phone only after a successful booking + payment.

Strategy
--------
- Normalise Arabic-Indic and Eastern-Arabic digits to ASCII digits
  (so ``٠١٠١٢٣٤٥٦٧٨`` is detected just like ``01012345678``).
- Collapse whitespace/hyphens/dots *between* digit runs so tricks
  like ``010 - 1234 - 5678`` don't slip through.
- Redact any remaining contiguous digit run of ≥ 6 digits — Egyptian
  mobile / landline numbers need at least 7.  6 is a conservative
  floor that also catches bank / iban chunks.
- Email addresses get redacted too (``\\S+@\\S+``) as a mild defence
  against side-channel contact exchange.

The sanitiser is intentionally *lossy*: preserving the user's intent
isn't the goal — denying them a way to bypass the platform is.
"""

from __future__ import annotations

import re

# Arabic-Indic (U+0660..0669) and Extended Arabic-Indic (U+06F0..06F9)
# digit → ASCII.
_DIGIT_TRANSLATE = str.maketrans(
    {
        **{chr(0x0660 + i): str(i) for i in range(10)},
        **{chr(0x06F0 + i): str(i) for i in range(10)},
    }
)

# Between-digit connectors that shouldn't defeat detection.
_CONNECTOR_SPLIT = re.compile(r"(?<=\d)[\s\-.·•]+(?=\d)")

# Any run of ≥ 6 digits → mask.
_DIGIT_RUN = re.compile(r"\d{6,}")

# Basic email detection.
_EMAIL = re.compile(r"\S+@\S+\.\S+")

_MASK = "•••"


def sanitize_chat_text(text: str) -> str:
    """Return ``text`` with phone-like digit runs + emails redacted."""
    if not text:
        return text
    # 1. Normalise Arabic digits
    cleaned = text.translate(_DIGIT_TRANSLATE)
    # 2. Collapse between-digit connectors so split numbers become one run
    cleaned = _CONNECTOR_SPLIT.sub("", cleaned)
    # 3. Redact long digit runs
    cleaned = _DIGIT_RUN.sub(_MASK, cleaned)
    # 4. Redact emails
    cleaned = _EMAIL.sub(_MASK, cleaned)
    return cleaned


def contains_phone_like(text: str) -> bool:
    """Return True if ``text`` looks like it tried to share a phone."""
    if not text:
        return False
    normalized = text.translate(_DIGIT_TRANSLATE)
    normalized = _CONNECTOR_SPLIT.sub("", normalized)
    return bool(_DIGIT_RUN.search(normalized))
