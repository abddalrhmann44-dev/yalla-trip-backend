"""Review endpoint tests – creation, host reply, pending, reporting."""

import pytest
from httpx import AsyncClient
from sqlalchemy import select

from app.models.booking import Booking, BookingStatus
from tests.conftest import TestSession


async def _setup_booking_and_complete(
    guest: AsyncClient, owner: AsyncClient
) -> int:
    """Create property → booking → mark completed directly in DB.

    Returns the booking id. We can't use the public
    ``/bookings/{id}/complete`` endpoint because that requires the
    booking to already be confirmed; the escrow path isn't fully
    exercised by this fixture.
    """
    resp = await owner.post("/properties", json={
        "name": "شاليه اختبار",
        "area": "الساحل الشمالي",
        "category": "شاليه",
        "price_per_night": 500,
        "bedrooms": 2,
        "max_guests": 4,
    })
    assert resp.status_code == 201, resp.text

    resp = await guest.post("/bookings", json={
        "property_id": resp.json()["id"],
        "check_in": "2027-01-01",
        "check_out": "2027-01-03",
        "guests_count": 2,
    })
    assert resp.status_code == 201, resp.text
    booking_id = resp.json()["id"]

    # Jump straight to ``completed`` so we can post a review.
    async with TestSession() as session:
        b = (await session.execute(
            select(Booking).where(Booking.id == booking_id)
        )).scalar_one()
        b.status = BookingStatus.completed
        await session.commit()

    return booking_id


@pytest.mark.asyncio
async def test_pending_reviews_initially_empty(guest_client: AsyncClient):
    resp = await guest_client.get("/reviews/my/pending")
    assert resp.status_code == 200
    assert resp.json() == []


@pytest.mark.asyncio
async def test_full_review_flow(
    guest_client: AsyncClient, owner_client: AsyncClient
):
    booking_id = await _setup_booking_and_complete(guest_client, owner_client)

    # Pending list now shows 1 booking waiting for review.
    resp = await guest_client.get("/reviews/my/pending")
    assert resp.status_code == 200
    pending = resp.json()
    assert len(pending) == 1
    assert pending[0]["booking_id"] == booking_id

    # Post the review.
    resp = await guest_client.post("/reviews", json={
        "booking_id": booking_id,
        "rating": 5,
        "comment": "مكان رائع",
    })
    assert resp.status_code == 201, resp.text
    review_id = resp.json()["id"]
    assert resp.json()["rating"] == 5
    assert resp.json()["owner_response"] is None

    # Pending list is empty again.
    resp = await guest_client.get("/reviews/my/pending")
    assert resp.json() == []

    # Duplicate review → 409
    resp = await guest_client.post("/reviews", json={
        "booking_id": booking_id,
        "rating": 4,
    })
    assert resp.status_code == 409

    # Owner responds.
    resp = await owner_client.post(
        f"/reviews/{review_id}/respond",
        json={"response": "شكراً جزيلاً"},
    )
    assert resp.status_code == 200
    assert resp.json()["owner_response"] == "شكراً جزيلاً"

    # Double reply rejected.
    resp = await owner_client.post(
        f"/reviews/{review_id}/respond",
        json={"response": "مرة تانية"},
    )
    assert resp.status_code == 409


@pytest.mark.asyncio
async def test_non_owner_cannot_respond(
    guest_client: AsyncClient, owner_client: AsyncClient, admin_client: AsyncClient
):
    booking_id = await _setup_booking_and_complete(guest_client, owner_client)
    resp = await guest_client.post("/reviews", json={
        "booking_id": booking_id,
        "rating": 5,
    })
    review_id = resp.json()["id"]

    # Admin is not the property owner → 403
    resp = await admin_client.post(
        f"/reviews/{review_id}/respond",
        json={"response": "nope"},
    )
    assert resp.status_code == 403


@pytest.mark.asyncio
async def test_review_reporting_hides_after_three(
    guest_client: AsyncClient,
    owner_client: AsyncClient,
    admin_client: AsyncClient,
):
    booking_id = await _setup_booking_and_complete(guest_client, owner_client)
    resp = await guest_client.post("/reviews", json={
        "booking_id": booking_id,
        "rating": 1,
        "comment": "inappropriate",
    })
    review_id = resp.json()["id"]
    prop_id = resp.json()["property_id"]

    # Reviewer can't report their own review.
    resp = await guest_client.post(f"/reviews/{review_id}/report")
    assert resp.status_code == 400

    # Two reports → still visible.
    for _ in range(2):
        resp = await owner_client.post(f"/reviews/{review_id}/report")
        assert resp.status_code == 200

    # Third report → auto-hidden.
    resp = await admin_client.post(f"/reviews/{review_id}/report")
    assert resp.status_code == 200

    # Public listing no longer returns the review.
    resp = await guest_client.get(f"/reviews/property/{prop_id}")
    assert resp.status_code == 200
    assert resp.json()["items"] == []
