"""Tests for Best-Trip public feed (Wave 21)."""

from datetime import date, timedelta

import pytest
from httpx import AsyncClient
from sqlalchemy import update

from app.models.booking import Booking, BookingStatus, PaymentStatus
from tests.conftest import TestSession


@pytest.fixture
def anyio_backend():
    return "asyncio"


async def _setup_completed_booking(
    owner_client: AsyncClient, guest_client: AsyncClient,
) -> tuple[int, int]:
    """Create property → booking → force it to completed. Returns (pid, bid)."""
    prop = await owner_client.post("/properties", json={
        "name": "شاليه للبوست",
        "area": "الجونة",
        "category": "شاليه",
        "price_per_night": 1000,
        "bedrooms": 2,
        "max_guests": 4,
    })
    assert prop.status_code == 201, prop.text
    pid = prop.json()["id"]

    book = await guest_client.post("/bookings", json={
        "property_id": pid,
        "check_in": (date.today() - timedelta(days=10)).isoformat(),
        "check_out": (date.today() - timedelta(days=7)).isoformat(),
        "guests_count": 2,
    })
    assert book.status_code == 201, book.text
    bid = book.json()["id"]

    # Force the booking to completed + paid directly in DB
    async with TestSession() as s:
        await s.execute(
            update(Booking)
            .where(Booking.id == bid)
            .values(
                status=BookingStatus.completed,
                payment_status=PaymentStatus.paid,
            )
        )
        await s.commit()
    return pid, bid


# ── Eligible bookings ─────────────────────────────────────────

@pytest.mark.asyncio
async def test_eligible_lists_completed_bookings(
    owner_client: AsyncClient, guest_client: AsyncClient,
):
    pid, bid = await _setup_completed_booking(
        owner_client, guest_client,
    )
    resp = await guest_client.get("/trip-posts/eligible-bookings")
    assert resp.status_code == 200
    items = resp.json()
    assert any(it["booking_id"] == bid for it in items)


@pytest.mark.asyncio
async def test_eligible_excludes_pending_bookings(
    owner_client: AsyncClient, guest_client: AsyncClient
):
    prop = await owner_client.post("/properties", json={
        "name": "Not completed",
        "area": "الغردقة",
        "category": "فندق",
        "price_per_night": 500,
        "bedrooms": 1,
        "max_guests": 2,
    })
    pid = prop.json()["id"]
    await guest_client.post("/bookings", json={
        "property_id": pid,
        "check_in": (date.today() + timedelta(days=5)).isoformat(),
        "check_out": (date.today() + timedelta(days=8)).isoformat(),
        "guests_count": 2,
    })
    resp = await guest_client.get("/trip-posts/eligible-bookings")
    assert resp.status_code == 200
    assert resp.json() == []


# ── Create / feed ─────────────────────────────────────────────

@pytest.mark.asyncio
async def test_create_post_and_appears_in_feed(
    owner_client: AsyncClient, guest_client: AsyncClient,
):
    pid, bid = await _setup_completed_booking(
        owner_client, guest_client,
    )
    create = await guest_client.post("/trip-posts", json={
        "booking_id": bid,
        "verdict": "loved",
        "caption": "أحلى رحلة عملناها السنة دي 😍",
        "image_urls": ["https://s3.example/p1.jpg"],
    })
    assert create.status_code == 201
    post = create.json()
    assert post["verdict"] == "loved"
    assert post["property_id"] == pid
    assert post["author"]["name"]

    feed = await guest_client.get("/trip-posts")
    assert feed.status_code == 200
    items = feed.json()["items"]
    assert any(p["id"] == post["id"] for p in items)


@pytest.mark.asyncio
async def test_cannot_post_about_other_users_booking(
    owner_client: AsyncClient, guest_client: AsyncClient,
    admin_client: AsyncClient,
):
    _, bid = await _setup_completed_booking(
        owner_client, guest_client,
    )
    # Owner tries to post about guest's booking
    resp = await owner_client.post("/trip-posts", json={
        "booking_id": bid,
        "verdict": "loved",
    })
    assert resp.status_code == 403


@pytest.mark.asyncio
async def test_cannot_post_about_incomplete_booking(
    owner_client: AsyncClient, guest_client: AsyncClient
):
    prop = await owner_client.post("/properties", json={
        "name": "Future stay",
        "area": "الساحل الشمالي",
        "category": "شاليه",
        "price_per_night": 700,
        "bedrooms": 1,
        "max_guests": 2,
    })
    pid = prop.json()["id"]
    book = await guest_client.post("/bookings", json={
        "property_id": pid,
        "check_in": (date.today() + timedelta(days=5)).isoformat(),
        "check_out": (date.today() + timedelta(days=8)).isoformat(),
        "guests_count": 2,
    })
    bid = book.json()["id"]
    resp = await guest_client.post("/trip-posts", json={
        "booking_id": bid,
        "verdict": "loved",
    })
    assert resp.status_code == 409


@pytest.mark.asyncio
async def test_cannot_post_twice_for_same_booking(
    owner_client: AsyncClient, guest_client: AsyncClient,
):
    _, bid = await _setup_completed_booking(
        owner_client, guest_client,
    )
    r1 = await guest_client.post("/trip-posts", json={
        "booking_id": bid, "verdict": "loved",
    })
    assert r1.status_code == 201
    r2 = await guest_client.post("/trip-posts", json={
        "booking_id": bid, "verdict": "disliked",
    })
    assert r2.status_code == 409


# ── Filters ───────────────────────────────────────────────────

@pytest.mark.asyncio
async def test_feed_filter_by_verdict(
    owner_client: AsyncClient, guest_client: AsyncClient,
):
    _, bid = await _setup_completed_booking(
        owner_client, guest_client,
    )
    await guest_client.post("/trip-posts", json={
        "booking_id": bid, "verdict": "disliked",
        "caption": "مش عجبتنا",
    })
    loved = await guest_client.get("/trip-posts?verdict=loved")
    disliked = await guest_client.get("/trip-posts?verdict=disliked")
    assert loved.status_code == 200 and disliked.status_code == 200
    assert all(it["verdict"] == "disliked" for it in disliked.json()["items"])
    assert not any(
        it["booking_id"] == bid for it in loved.json()["items"]
    )


# ── Moderation ────────────────────────────────────────────────

@pytest.mark.asyncio
async def test_admin_can_hide_post(
    owner_client: AsyncClient, guest_client: AsyncClient,
    admin_client: AsyncClient,
):
    _, bid = await _setup_completed_booking(
        owner_client, guest_client,
    )
    create = await guest_client.post("/trip-posts", json={
        "booking_id": bid, "verdict": "loved",
    })
    post_id = create.json()["id"]

    hide = await admin_client.post(f"/trip-posts/admin/{post_id}/hide")
    assert hide.status_code == 200

    # Feed should not include the hidden post
    feed = await guest_client.get("/trip-posts")
    assert not any(p["id"] == post_id for p in feed.json()["items"])

    # Un-hide brings it back
    unhide = await admin_client.post(f"/trip-posts/admin/{post_id}/unhide")
    assert unhide.status_code == 200
    feed2 = await guest_client.get("/trip-posts")
    assert any(p["id"] == post_id for p in feed2.json()["items"])


# ── Delete ────────────────────────────────────────────────────

@pytest.mark.asyncio
async def test_delete_own_post(
    owner_client: AsyncClient, guest_client: AsyncClient,
):
    _, bid = await _setup_completed_booking(
        owner_client, guest_client,
    )
    create = await guest_client.post("/trip-posts", json={
        "booking_id": bid, "verdict": "loved",
    })
    post_id = create.json()["id"]
    resp = await guest_client.delete(f"/trip-posts/{post_id}")
    assert resp.status_code == 204


@pytest.mark.asyncio
async def test_cannot_delete_others_post(
    owner_client: AsyncClient, guest_client: AsyncClient,
):
    _, bid = await _setup_completed_booking(
        owner_client, guest_client,
    )
    create = await guest_client.post("/trip-posts", json={
        "booking_id": bid, "verdict": "loved",
    })
    post_id = create.json()["id"]
    resp = await owner_client.delete(f"/trip-posts/{post_id}")
    assert resp.status_code == 403
