"""Phone OTP + booking contact reveal tests (Wave 23)."""

from datetime import date, timedelta

import pytest
from httpx import AsyncClient

from app.models.phone_otp import PhoneOtp
from app.services.chat_sanitizer import (
    contains_phone_like,
    sanitize_chat_text,
)
from app.services import phone_otp_service


# ══════════════════════════════════════════════════════════
#  Unit tests — sanitizer
# ══════════════════════════════════════════════════════════

def test_sanitizer_masks_egyptian_mobile():
    out = sanitize_chat_text("اتصل على 01012345678")
    assert "01012345678" not in out
    assert "•••" in out


def test_sanitizer_masks_arabic_indic_digits():
    # Arabic-Indic digits for 01012345678
    raw = "تواصل معي ٠١٠١٢٣٤٥٦٧٨"
    assert contains_phone_like(raw)
    out = sanitize_chat_text(raw)
    # After normalisation + masking the digit run is gone
    assert "٠١٠١٢٣٤٥٦٧٨" not in out
    assert "•••" in out


def test_sanitizer_defeats_connectors():
    # Separated by spaces / dashes — the sanitizer collapses and masks.
    for variant in ("010 - 1234 - 5678", "010.1234.5678", "010 1234 5678"):
        assert contains_phone_like(variant)
        out = sanitize_chat_text(variant)
        # Target digit chunks no longer appear intact.
        assert "1234" not in out
        assert "5678" not in out


def test_sanitizer_leaves_short_numbers_alone():
    # Less-than-6 digit runs aren't phones (room number, guest count…)
    out = sanitize_chat_text("أنا جاي بـ 4 أفراد")
    assert "4" in out


def test_sanitizer_masks_email():
    out = sanitize_chat_text("ايميل info@talaa.com")
    assert "info@talaa.com" not in out
    assert "•••" in out


# ══════════════════════════════════════════════════════════
#  Phone-OTP service (unit) + HTTP endpoints
# ══════════════════════════════════════════════════════════

@pytest.mark.asyncio
async def test_start_and_verify_otp_roundtrip(owner_client: AsyncClient):
    # 1. Request OTP
    resp = await owner_client.post(
        "/me/phone/start-otp", json={"phone": "01098765432"},
    )
    assert resp.status_code == 200, resp.text
    assert resp.json()["phone"] == "+201098765432"

    # 2. Read the issued code directly from the DB (simulates the
    # SMS gateway callback).
    from tests.conftest import TestSession
    from sqlalchemy import select
    async with TestSession() as s:
        row = (await s.execute(
            select(PhoneOtp).order_by(PhoneOtp.id.desc())
        )).scalars().first()
        assert row is not None
        expected_hash = row.code_hash

    # Brute-force match — we know the alphabet is 6 digits.
    import hashlib
    for n in range(1_000_000):
        candidate = f"{n:06d}"
        if hashlib.sha256(candidate.encode()).hexdigest() == expected_hash:
            break
    else:  # pragma: no cover
        raise AssertionError("unable to reverse test OTP")

    # 3. Verify it
    resp = await owner_client.post(
        "/me/phone/verify-otp",
        json={"phone": "01098765432", "code": candidate},
    )
    assert resp.status_code == 200, resp.text
    body = resp.json()
    assert body["phone_verified"] is True
    assert body["phone"] == "+201098765432"


@pytest.mark.asyncio
async def test_verify_wrong_code_is_rejected(owner_client: AsyncClient):
    await owner_client.post(
        "/me/phone/start-otp", json={"phone": "01098765432"},
    )
    resp = await owner_client.post(
        "/me/phone/verify-otp",
        json={"phone": "01098765432", "code": "000000"},
    )
    # Almost certainly the wrong code (1/1M chance of collision).
    assert resp.status_code == 400
    assert "wrong" in resp.json()["detail"].lower() or \
           "صحيح" in resp.json()["detail"]


def test_normalize_phone_accepts_common_formats():
    target = "+201012345678"
    assert phone_otp_service.normalize_phone("01012345678") == target
    assert phone_otp_service.normalize_phone("201012345678") == target
    assert phone_otp_service.normalize_phone("+201012345678") == target
    assert phone_otp_service.normalize_phone("(010) 1234-5678") == target


def test_normalize_phone_rejects_junk():
    with pytest.raises(ValueError):
        phone_otp_service.normalize_phone("abc")
    with pytest.raises(ValueError):
        phone_otp_service.normalize_phone("12345")


# ══════════════════════════════════════════════════════════
#  Contact reveal after booking confirmation
# ══════════════════════════════════════════════════════════

@pytest.mark.asyncio
async def test_booking_contact_hidden_until_confirmed(
    guest_client: AsyncClient, owner_client: AsyncClient,
):
    # Owner creates chalet + guest books it (normal booking flow).
    resp = await owner_client.post("/properties", json={
        "name": "شاليه التواصل",
        "area": "الساحل الشمالي",
        "category": "شاليه",
        "price_per_night": 1000,
        "bedrooms": 2,
        "max_guests": 4,
    })
    assert resp.status_code == 201, resp.text
    pid = resp.json()["id"]

    start = date.today() + timedelta(days=20)
    resp = await guest_client.post("/bookings", json={
        "property_id": pid,
        "check_in": start.isoformat(),
        "check_out": (start + timedelta(days=2)).isoformat(),
        "guests_count": 2,
    })
    assert resp.status_code == 201, resp.text
    booking = resp.json()
    bid = booking["id"]

    # Pending → contact is hidden.
    resp = await guest_client.get(f"/bookings/{bid}/contact")
    assert resp.status_code == 409

    # Owner confirms the booking (simulating payment / approval).
    resp = await owner_client.put(f"/bookings/{bid}/confirm")
    assert resp.status_code == 200, resp.text

    # Guest now sees the owner's phone; owner sees the guest's phone.
    resp = await guest_client.get(f"/bookings/{bid}/contact")
    assert resp.status_code == 200, resp.text
    data = resp.json()
    assert data["role"] == "owner"
    assert data["phone"] == "+201111111111"

    resp = await owner_client.get(f"/bookings/{bid}/contact")
    assert resp.status_code == 200, resp.text
    data = resp.json()
    assert data["role"] == "guest"
    assert data["phone"] == "+201000000000"
