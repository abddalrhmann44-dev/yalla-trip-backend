"""Sanitiser for free-form chat messages (Wave 23, extended Wave 31).

Purpose: prevent guests and owners from exchanging raw contact info
in plain text before a booking is *confirmed*.  Talaa reveals each
party's full phone only after a successful booking + payment.

Strategy
--------
The sanitiser runs the input through a normalisation pipeline so
both *direct* and *indirect* contact-sharing attempts are caught:

  1. Arabic-Indic / Eastern-Arabic digits → ASCII digits.
  2. Spelled-out digits in Arabic ("صفر واحد صفر …") and English
     ("zero one zero …") are folded to their numeric form when ≥ 3
     consecutive number-words appear (the threshold keeps casual
     prose like "كنا اتنين بس" or "two days" intact).
  3. Common homoglyphs (``O``→0, ``o``→0, ``l``→1, ``I``→1) are
     swapped *only inside an alphanumeric run that already contains
     ≥ 2 ASCII digits*, so we don't mangle ordinary words.
  4. Between-digit connectors (spaces, dashes, dots, bullets, even
     emoji separators) are collapsed so ``010 - 1234 - 5678`` becomes
     one contiguous run.
  5. Any remaining digit run of ≥ 6 chars is redacted with ``•••``.
  6. Emails and ``@handle`` mentions next to a social-network keyword
     (whatsapp, telegram, instagram, snapchat, tiktok, signal, viber,
     facebook, messenger, discord, twitter / X) get redacted too.

The sanitiser is intentionally *lossy*: preserving the user's intent
isn't the goal — denying them a way to bypass the platform is.

The companion ``detect_contact_attempt`` helper returns a short
Arabic reason describing what the moderator should care about so the
chat-monitor UI can show "محاولة مشاركة رقم تليفون" / "محاولة
مشاركة حساب واتساب" instead of a generic flag.
"""

from __future__ import annotations

import re
from typing import Optional

# ── Digit normalisation ──────────────────────────────────
# Arabic-Indic (U+0660..0669) and Extended Arabic-Indic (U+06F0..06F9)
# digit → ASCII.
_DIGIT_TRANSLATE = str.maketrans(
    {
        **{chr(0x0660 + i): str(i) for i in range(10)},
        **{chr(0x06F0 + i): str(i) for i in range(10)},
    }
)

# Between-digit connectors that shouldn't defeat detection.  Notice
# we include ``_`` and zero-width joiners so ``010_1234_5678`` and
# similarly obfuscated strings still collapse to one run.
_CONNECTOR_SPLIT = re.compile(
    r"(?<=[\d])[\s\-.·•/_\\|\u200c\u200d\u200e\u200f]+(?=[\d])"
)

# Any run of ≥ 6 digits → mask.  6 covers iban / bank chunks too.
_DIGIT_RUN = re.compile(r"\d{6,}")

# Basic email detection.
_EMAIL = re.compile(r"\S+@\S+\.\S+")

_MASK = "•••"

# ── Spelled-out digits (Arabic + English) ────────────────
# Each entry maps a word (lowercased) to its digit.  We accept a few
# common dialect variants for Arabic ("اتنين"/"إثنين", "تلاتة"/"ثلاثة",
# "سبعة"/"سبع", etc).  English includes both "naught/nought" and the
# casual "oh" for 0.
_NUMBER_WORDS: dict[str, str] = {
    # Arabic — formal
    "صفر": "0",
    "واحد": "1", "واحدة": "1",
    "اثنان": "2", "إثنان": "2", "اثنين": "2", "إثنين": "2",
    "ثلاثة": "3", "ثلاث": "3",
    "أربعة": "4", "اربعة": "4", "أربع": "4", "اربع": "4",
    "خمسة": "5", "خمس": "5",
    "ستة": "6", "ست": "6",
    "سبعة": "7", "سبع": "7",
    "ثمانية": "8", "ثماني": "8",
    "تسعة": "9", "تسع": "9",
    # Arabic — colloquial Egyptian variants
    "اتنين": "2", "إتنين": "2",
    "تلاتة": "3", "تلات": "3",
    "تمنية": "8", "تمانية": "8",
    # English
    "zero": "0", "naught": "0", "nought": "0", "oh": "0",
    "one": "1",
    "two": "2",
    "three": "3",
    "four": "4",
    "five": "5",
    "six": "6",
    "seven": "7",
    "eight": "8",
    "nine": "9",
}

# Tokeniser that yields runs of "word" or "non-word".  We treat
# Arabic letters + ASCII letters + ASCII digits as word characters,
# everything else as a separator we preserve when re-stitching.
_TOKEN = re.compile(r"[A-Za-z\u0600-\u06FF\d]+|[^A-Za-z\u0600-\u06FF\d]+")

# Minimum consecutive spelled digit-words before we treat them as
# part of a phone number.  3 strikes a good balance: "two friends"
# stays alive, "zero one zero one two three four five six seven
# eight" collapses to ``01012345678``.
_MIN_SPELLED_RUN = 3

# ── Homoglyph rescue ─────────────────────────────────────
# Map characters that *look* like digits to their digit.  Applied only
# inside alphanumeric runs that already contain ≥ 2 ASCII digits to
# avoid mangling words like "police" or "look".
_HOMOGLYPH = str.maketrans({
    "O": "0", "o": "0",
    "I": "1", "l": "1",
    "S": "5", "s": "5",
    "B": "8",
    "Z": "2", "z": "2",
})
_ALNUM_RUN = re.compile(r"[A-Za-z\d]{3,}")
_HAS_TWO_DIGITS = re.compile(r"\d.*\d")

# ── Social handles ───────────────────────────────────────
# Platform keywords (lowercased) that, when followed by an ``@handle``
# or a likely username token, indicate off-platform contact exchange.
_SOCIAL_KEYWORDS: tuple[str, ...] = (
    # English
    "whatsapp", "whats", "wa", "telegram", "tg",
    "instagram", "insta", "ig",
    "snapchat", "snap",
    "tiktok", "tik tok",
    "signal", "viber", "imo", "wechat", "line",
    "facebook", "fb", "messenger",
    "discord", "twitter", " x ", "youtube",
    # Arabic
    "واتس", "واتساب", "واتس آب", "واتساپ",
    "تلجرام", "تليجرام", "تيليجرام",
    "انستا", "إنستا", "انستجرام", "إنستجرام", "انستغرام",
    "سناب", "سناپ",
    "تيك توك", "تيكتوك",
    "فيس", "فيسبوك", "ماسنجر",
    "ديسكورد", "تويتر",
    "ايمو", "إيمو",
)

# ``@user_name123`` style handle.
_AT_HANDLE = re.compile(r"@[A-Za-z0-9_.]{3,}")


# ══════════════════════════════════════════════════════════
#  Pipeline helpers
# ══════════════════════════════════════════════════════════

def _fold_spelled_digits(text: str) -> str:
    """Replace runs of ≥ 3 consecutive digit-words with their digits.

    Tokens between words may be whitespace, dashes, commas, dots or
    Arabic punctuation — they are *consumed* so the resulting digit
    string is one contiguous run (and therefore caught by the digit
    redactor downstream).

    Crucially, runs *below* the threshold are restored verbatim using
    the original token spellings, so prose like ``two friends`` or
    ``كنا اتنين بس`` is preserved untouched.
    """
    tokens = _TOKEN.findall(text)
    if not tokens:
        return text

    out: list[str] = []
    # Each buffered run-entry keeps both the digit equivalent and the
    # original token (or literal digit string) plus any in-run
    # separator that *follows* it.  This lets us restore prose
    # verbatim when the run never reaches the threshold.
    buf: list[tuple[str, str]] = []  # (digit, original_token)
    sep_buf: list[str] = []           # separator *after* each entry

    def flush_buf(trailing_sep: str = "") -> None:
        if len(buf) >= _MIN_SPELLED_RUN:
            # Replace the spelled run with its digits, dropping any
            # in-run separators so it forms one contiguous number.
            out.append("".join(d for d, _ in buf))
        else:
            # Restore the original token spellings + separators.
            for i, (_digit, orig) in enumerate(buf):
                out.append(orig)
                if i < len(sep_buf):
                    out.append(sep_buf[i])
        buf.clear()
        sep_buf.clear()
        if trailing_sep:
            out.append(trailing_sep)

    pending_sep: Optional[str] = None
    for tok in tokens:
        first = tok[0] if tok else ""
        is_word = first.isalpha() or first in _ARABIC_LETTERS_FIRST
        is_digit = first.isdigit()
        if is_word:
            digit = _NUMBER_WORDS.get(tok.lower())
            if digit is not None:
                if buf:
                    if pending_sep is not None:
                        sep_buf.append(pending_sep)
                else:
                    # Brand-new run: emit any leading separator
                    # straight to the output so prose isn't lost
                    # when the run later falls below the threshold.
                    if pending_sep:
                        out.append(pending_sep)
                buf.append((digit, tok))
                pending_sep = None
            else:
                # Non-number word breaks the run.
                flush_buf(pending_sep or "")
                out.append(tok)
                pending_sep = None
        elif is_digit:
            if buf:
                if pending_sep is not None:
                    sep_buf.append(pending_sep)
            else:
                if pending_sep:
                    out.append(pending_sep)
            buf.append((tok, tok))
            pending_sep = None
        else:
            # Separator — defer; flushed if next is a non-number word.
            pending_sep = (pending_sep or "") + tok
    flush_buf(pending_sep or "")
    return "".join(out)


# Set of leading characters that the simple ``isalpha`` check misses
# for word tokens because of the alpha test on the first code point.
_ARABIC_LETTERS_FIRST = set(chr(c) for c in range(0x0600, 0x06FF + 1))


def _apply_homoglyphs(text: str) -> str:
    """Replace digit-look-alikes inside mixed alphanumeric runs."""
    def _repl(m: re.Match[str]) -> str:
        chunk = m.group(0)
        if not _HAS_TWO_DIGITS.search(chunk):
            return chunk
        return chunk.translate(_HOMOGLYPH)
    return _ALNUM_RUN.sub(_repl, text)


def _redact_social_handles(text: str) -> str:
    """Mask ``@handles`` that appear near a social-platform keyword.

    We only redact when the handle is *contextually* a social-media
    handle (i.e. close to a platform mention) to avoid swallowing
    things like email-style mentions or ``@everyone`` in casual chat.
    """
    if "@" not in text:
        return text
    lowered = text.lower()
    if not any(k in lowered for k in _SOCIAL_KEYWORDS):
        return text
    return _AT_HANDLE.sub(_MASK, text)


# ══════════════════════════════════════════════════════════
#  Public API
# ══════════════════════════════════════════════════════════

def _normalise(text: str) -> str:
    """Run every pre-redaction transform.  Idempotent."""
    cleaned = text.translate(_DIGIT_TRANSLATE)
    cleaned = _fold_spelled_digits(cleaned)
    cleaned = _apply_homoglyphs(cleaned)
    cleaned = _CONNECTOR_SPLIT.sub("", cleaned)
    return cleaned


def sanitize_chat_text(text: str) -> str:
    """Return ``text`` with phone-like info redacted.

    Handles direct numbers, spelled-out numbers (AR + EN), homoglyph
    obfuscation, emails and social-media @handles.
    """
    if not text:
        return text
    cleaned = _normalise(text)
    cleaned = _DIGIT_RUN.sub(_MASK, cleaned)
    cleaned = _EMAIL.sub(_MASK, cleaned)
    cleaned = _redact_social_handles(cleaned)
    return cleaned


def contains_phone_like(text: str) -> bool:
    """Return True if ``text`` looks like it tried to share a phone."""
    if not text:
        return False
    return bool(_DIGIT_RUN.search(_normalise(text)))


def detect_contact_attempt(text: str) -> Optional[str]:
    """Classify the *kind* of contact-exchange attempt, if any.

    Returns a short Arabic reason suited for the admin chat-monitor
    list, or ``None`` if the message looks clean to this layer.  The
    moderation service composes this with its own profanity / off-
    platform checks before deciding whether to flag.
    """
    if not text:
        return None
    norm = _normalise(text)
    if _DIGIT_RUN.search(norm):
        return "محاولة مشاركة رقم تليفون"
    if _EMAIL.search(text):
        return "محاولة مشاركة بريد إلكتروني"
    lowered = text.lower()
    if "@" in text and any(k in lowered for k in _SOCIAL_KEYWORDS):
        if _AT_HANDLE.search(text):
            return "محاولة مشاركة حساب على منصة أخرى"
    return None
