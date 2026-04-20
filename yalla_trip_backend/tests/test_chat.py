"""Chat endpoint tests (Wave 23).

Chat is now a *price-negotiation* channel limited to chalets + boats,
with mandatory trip intent (check_in / check_out / guests) and an
auto-booking path once an offer is accepted.
"""

from datetime import date, timedelta

import pytest
from httpx import AsyncClient


def _trip_window(days_ahead: int = 30, nights: int = 2) -> dict:
    start = date.today() + timedelta(days=days_ahead)
    return {
        "check_in": start.isoformat(),
        "check_out": (start + timedelta(days=nights)).isoformat(),
        "guests": 4,
    }


async def _make_chalet(owner_client: AsyncClient) -> int:
    resp = await owner_client.post("/properties", json={
        "name": "شاليه الاختبار",
        "area": "الساحل الشمالي",
        "category": "شاليه",
        "price_per_night": 1200,
        "bedrooms": 4,
        "max_guests": 8,
    })
    assert resp.status_code == 201, resp.text
    return resp.json()["id"]


@pytest.mark.asyncio
async def test_list_conversations_empty(guest_client: AsyncClient):
    resp = await guest_client.get("/chats")
    assert resp.status_code == 200
    assert resp.json() == []


@pytest.mark.asyncio
async def test_cannot_chat_with_self_about_own_property(
    owner_client: AsyncClient,
):
    pid = await _make_chalet(owner_client)
    resp = await owner_client.post(
        "/chats", json={"property_id": pid, **_trip_window()},
    )
    assert resp.status_code == 400


@pytest.mark.asyncio
async def test_chat_only_for_chalet_or_boat(
    guest_client: AsyncClient, owner_client: AsyncClient,
):
    # Villa is NOT chat-eligible under Wave 23.
    resp = await owner_client.post("/properties", json={
        "name": "فيلا فاخرة",
        "area": "الجونة",
        "category": "فيلا",
        "price_per_night": 3000,
        "bedrooms": 5,
        "max_guests": 10,
    })
    assert resp.status_code == 201, resp.text
    pid = resp.json()["id"]

    resp = await guest_client.post(
        "/chats", json={"property_id": pid, **_trip_window()},
    )
    assert resp.status_code == 409
    assert "chalets and boats" in resp.json()["detail"]


@pytest.mark.asyncio
async def test_text_messages_are_sanitised(
    guest_client: AsyncClient, owner_client: AsyncClient,
):
    pid = await _make_chalet(owner_client)
    resp = await guest_client.post(
        "/chats", json={"property_id": pid, **_trip_window()},
    )
    cid = resp.json()["id"]

    # Guest tries to leak an Egyptian mobile number.  It should be
    # redacted before being persisted.
    resp = await guest_client.post(
        f"/chats/{cid}/messages",
        json={"body": "اتصل بيا على 01012345678 أو info@test.com"},
    )
    assert resp.status_code == 201
    body = resp.json()["body"]
    assert "01012345678" not in body
    assert "info@test.com" not in body
    assert "•••" in body


@pytest.mark.asyncio
async def test_negotiation_flow_creates_booking(
    guest_client: AsyncClient, owner_client: AsyncClient,
):
    pid = await _make_chalet(owner_client)
    window = _trip_window(days_ahead=10, nights=3)

    # Guest opens the thread with booking intent.
    resp = await guest_client.post("/chats", json={"property_id": pid, **window})
    assert resp.status_code == 201, resp.text
    conv = resp.json()
    cid = conv["id"]
    assert conv["status"] == "open"
    assert conv["check_in"] == window["check_in"]
    assert conv["guests"] == window["guests"]

    # Owner posts an opening offer of 1000.
    resp = await owner_client.post(
        f"/chats/{cid}/offer", json={"amount": 1000},
    )
    assert resp.status_code == 201, resp.text
    assert resp.json()["kind"] == "offer"
    assert resp.json()["offer_amount"] == 1000

    # Guest cannot accept their own side's offer — wait, it's the owner's.
    # Guest counters with a lower price.
    resp = await guest_client.post(
        f"/chats/{cid}/offer", json={"amount": 800},
    )
    assert resp.status_code == 201
    assert resp.json()["offer_amount"] == 800

    # Guest cannot accept their *own* offer.
    resp = await guest_client.post(f"/chats/{cid}/accept")
    assert resp.status_code == 400

    # Owner accepts the guest's counter → booking is auto-created.
    resp = await owner_client.post(f"/chats/{cid}/accept")
    assert resp.status_code == 201, resp.text
    data = resp.json()
    booking_id = data["booking_id"]
    assert booking_id > 0
    assert data["booking_code"]
    assert data["total_price"] > 0
    assert data["conversation"]["status"] == "accepted"
    assert data["conversation"]["booking_id"] == booking_id

    # Further messages are rejected on a sealed thread.
    resp = await guest_client.post(
        f"/chats/{cid}/messages", json={"body": "شكرا"},
    )
    assert resp.status_code == 409


@pytest.mark.asyncio
async def test_decline_keeps_thread_open(
    guest_client: AsyncClient, owner_client: AsyncClient,
):
    pid = await _make_chalet(owner_client)
    resp = await guest_client.post(
        "/chats", json={"property_id": pid, **_trip_window()},
    )
    cid = resp.json()["id"]

    await owner_client.post(f"/chats/{cid}/offer", json={"amount": 1500})
    resp = await guest_client.post(f"/chats/{cid}/decline")
    assert resp.status_code == 201
    assert resp.json()["kind"] == "decline"

    # Latest offer is cleared so nobody can accept the stale price.
    resp = await guest_client.post(f"/chats/{cid}/accept")
    assert resp.status_code == 400

    # Thread is still open — guest can send a fresh counter-offer.
    resp = await guest_client.post(
        f"/chats/{cid}/offer", json={"amount": 1200},
    )
    assert resp.status_code == 201


@pytest.mark.asyncio
async def test_non_participant_forbidden(
    guest_client: AsyncClient,
    owner_client: AsyncClient,
    admin_client: AsyncClient,
):
    pid = await _make_chalet(owner_client)
    resp = await guest_client.post(
        "/chats", json={"property_id": pid, **_trip_window()},
    )
    assert resp.status_code == 201, resp.text
    cid = resp.json()["id"]

    # Admin (not a participant) cannot read it.
    resp = await admin_client.get(f"/chats/{cid}")
    assert resp.status_code == 403
