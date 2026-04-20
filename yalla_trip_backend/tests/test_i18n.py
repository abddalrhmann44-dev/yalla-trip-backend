"""Tests for Wave 16 – backend i18n helper."""

import pytest
from starlette.requests import Request
from starlette.datastructures import Headers

from app.services.i18n import bilingual, resolve_locale, t


def _make_request(accept_language: str | None) -> Request:
    headers = Headers(
        {"accept-language": accept_language} if accept_language else {}
    )
    scope = {
        "type": "http",
        "method": "GET",
        "path": "/",
        "headers": headers.raw,
    }
    return Request(scope)


def test_resolve_locale_arabic():
    assert resolve_locale(_make_request("ar")) == "ar"
    assert resolve_locale(_make_request("ar-EG,en;q=0.9")) == "ar"


def test_resolve_locale_english():
    assert resolve_locale(_make_request("en")) == "en"
    assert resolve_locale(_make_request("en-US,ar;q=0.5")) == "en"


def test_resolve_locale_default():
    assert resolve_locale(_make_request(None)) == "ar"
    assert resolve_locale(_make_request("fr")) == "ar"  # unsupported → default
    assert resolve_locale(None) == "ar"


def test_translate_arabic():
    r = _make_request("ar")
    assert t(r, "property.not_found") == "العقار غير موجود"
    assert t(r, "booking.dates_conflict") == "التواريخ غير متاحة"


def test_translate_english():
    r = _make_request("en")
    assert t(r, "property.not_found") == "Property not found"
    assert t(r, "booking.dates_conflict") == "Dates not available"


def test_translate_unknown_key_returns_key():
    r = _make_request("ar")
    assert t(r, "some.unknown.key") == "some.unknown.key"


def test_bilingual_format():
    text = bilingual("property.not_found")
    assert "العقار غير موجود" in text
    assert "Property not found" in text
    assert "/" in text
