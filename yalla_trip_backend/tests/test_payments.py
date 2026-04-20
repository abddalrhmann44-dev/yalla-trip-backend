"""Payment endpoint tests."""

import pytest
from httpx import AsyncClient


async def _create_booking(guest: AsyncClient, owner: AsyncClient) -> int:
    """Create a property (as owner) + booking (as guest) and return booking id."""
    resp = await owner.post("/properties", json={
        "name": "شاليه اختبار",
        "area": "الساحل الشمالي",
        "category": "شاليه",
        "price_per_night": 500,
        "bedrooms": 2,
        "max_guests": 4,
    })
    assert resp.status_code == 201, resp.text
    pid = resp.json()["id"]

    resp = await guest.post("/bookings", json={
        "property_id": pid,
        "check_in": "2027-01-01",
        "check_out": "2027-01-03",
        "guests_count": 2,
    })
    assert resp.status_code == 201, resp.text
    return resp.json()["id"]


@pytest.mark.asyncio
async def test_my_payments_empty(guest_client: AsyncClient):
    resp = await guest_client.get("/payments/my")
    assert resp.status_code == 200
    assert resp.json() == []


@pytest.mark.asyncio
async def test_initiate_cod_payment(
    guest_client: AsyncClient, owner_client: AsyncClient
):
    booking_id = await _create_booking(guest_client, owner_client)

    resp = await guest_client.post("/payments/initiate", json={
        "booking_id": booking_id,
        "provider": "cod",
        "method": "cod",
    })
    assert resp.status_code == 201, resp.text
    body = resp.json()
    assert body["provider"] == "cod"
    assert body["method"] == "cod"
    assert body["state"] == "pending"
    assert body["amount"] > 0
    payment_id = body["payment_id"]

    # Single payment fetch
    resp = await guest_client.get(f"/payments/{payment_id}")
    assert resp.status_code == 200
    assert resp.json()["id"] == payment_id

    # Payments list now has 1 row
    resp = await guest_client.get("/payments/my")
    assert resp.status_code == 200
    assert len(resp.json()) == 1


@pytest.mark.asyncio
async def test_initiate_rejects_other_users_booking(
    guest_client: AsyncClient, owner_client: AsyncClient, admin_client: AsyncClient
):
    booking_id = await _create_booking(guest_client, owner_client)

    # Admin tries to pay for guest's booking → 403
    resp = await admin_client.post("/payments/initiate", json={
        "booking_id": booking_id,
        "provider": "cod",
        "method": "cod",
    })
    assert resp.status_code == 403


@pytest.mark.asyncio
async def test_initiate_rejects_mismatched_method(
    guest_client: AsyncClient, owner_client: AsyncClient
):
    booking_id = await _create_booking(guest_client, owner_client)

    # Fawry doesn't support wallet
    resp = await guest_client.post("/payments/initiate", json={
        "booking_id": booking_id,
        "provider": "fawry",
        "method": "wallet",
    })
    assert resp.status_code == 400
