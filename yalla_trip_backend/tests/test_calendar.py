"""iCal export + import tests (Wave 13)."""

from __future__ import annotations

from datetime import date
from unittest.mock import patch

import pytest
from httpx import AsyncClient
from sqlalchemy import select, update

from app.models.calendar import CalendarBlock, CalendarImport, BlockSource
from app.models.property import Property, PropertyStatus
from app.services import ical_service


# ── helpers ───────────────────────────────────────────────
async def _seed_prop(owner: AsyncClient) -> int:
    r = await owner.post("/properties", json={
        "name": "كال سينك",
        "description": "شاليه اختبار",
        "area": "الساحل الشمالي",
        "category": "شاليه",
        "price_per_night": 500,
        "bedrooms": 1,
        "max_guests": 2,
    })
    assert r.status_code in (200, 201), r.text
    pid = r.json()["id"]
    from tests.conftest import TestSession
    async with TestSession() as db:
        await db.execute(
            update(Property)
            .where(Property.id == pid)
            .values(status=PropertyStatus.approved)
        )
        await db.commit()
    return pid


# ══════════════════════════════════════════════════════════════
#  Export
# ══════════════════════════════════════════════════════════════
@pytest.mark.asyncio
async def test_feed_token_generated_and_feed_accessible(
    owner_client: AsyncClient,
):
    pid = await _seed_prop(owner_client)
    r = await owner_client.get(f"/calendar/{pid}/token")
    assert r.status_code == 200
    data = r.json()
    assert data["property_id"] == pid
    assert data["token"]
    assert data["feed_url"].endswith(f"/calendar/{pid}/{data['token']}.ics")

    # Fetch the public feed (no auth).
    from tests.conftest import app as _app
    from httpx import ASGITransport, AsyncClient as AC
    async with AC(
        transport=ASGITransport(app=_app),
        base_url="http://test",
    ) as anon:
        feed = await anon.get(f"/calendar/{pid}/{data['token']}.ics")
    assert feed.status_code == 200
    assert "text/calendar" in feed.headers["content-type"]
    assert "BEGIN:VCALENDAR" in feed.text
    assert "END:VCALENDAR" in feed.text


@pytest.mark.asyncio
async def test_feed_rejects_bad_token(owner_client: AsyncClient):
    pid = await _seed_prop(owner_client)
    from tests.conftest import app as _app
    from httpx import ASGITransport, AsyncClient as AC
    async with AC(
        transport=ASGITransport(app=_app),
        base_url="http://test",
    ) as anon:
        feed = await anon.get(f"/calendar/{pid}/bogus.ics")
    assert feed.status_code == 404


@pytest.mark.asyncio
async def test_feed_token_rotation_invalidates_old(
    owner_client: AsyncClient,
):
    pid = await _seed_prop(owner_client)
    t1 = (await owner_client.get(f"/calendar/{pid}/token")).json()["token"]
    t2 = (await owner_client.post(f"/calendar/{pid}/token")).json()["token"]
    assert t1 != t2

    from tests.conftest import app as _app
    from httpx import ASGITransport, AsyncClient as AC
    async with AC(
        transport=ASGITransport(app=_app),
        base_url="http://test",
    ) as anon:
        old = await anon.get(f"/calendar/{pid}/{t1}.ics")
        new = await anon.get(f"/calendar/{pid}/{t2}.ics")
    assert old.status_code == 404
    assert new.status_code == 200


# ══════════════════════════════════════════════════════════════
#  Manual blocks
# ══════════════════════════════════════════════════════════════
@pytest.mark.asyncio
async def test_manual_block_blocks_booking(
    owner_client: AsyncClient, guest_client: AsyncClient,
):
    pid = await _seed_prop(owner_client)

    r = await owner_client.post("/calendar/blocks", json={
        "property_id": pid,
        "start_date": "2027-06-01",
        "end_date": "2027-06-05",
        "summary": "host away",
    })
    assert r.status_code == 201

    # Booking in the blocked window → 409.
    r2 = await guest_client.post("/bookings", json={
        "property_id": pid,
        "check_in": "2027-06-02",
        "check_out": "2027-06-04",
        "guests_count": 1,
    })
    assert r2.status_code == 409
    assert "blocked" in r2.json()["detail"].lower()


@pytest.mark.asyncio
async def test_manual_block_excluded_from_search(
    owner_client: AsyncClient, guest_client: AsyncClient,
):
    pid = await _seed_prop(owner_client)
    await owner_client.post("/calendar/blocks", json={
        "property_id": pid,
        "start_date": "2027-07-10",
        "end_date": "2027-07-15",
    })

    r = await guest_client.get(
        "/properties",
        params={"check_in": "2027-07-12", "check_out": "2027-07-14"},
    )
    ids = [p["id"] for p in r.json()["items"]]
    assert pid not in ids


@pytest.mark.asyncio
async def test_block_validation_rejects_inverted_range(
    owner_client: AsyncClient,
):
    pid = await _seed_prop(owner_client)
    r = await owner_client.post("/calendar/blocks", json={
        "property_id": pid,
        "start_date": "2027-08-05",
        "end_date": "2027-08-05",
    })
    assert r.status_code == 400


# ══════════════════════════════════════════════════════════════
#  Imports + sync
# ══════════════════════════════════════════════════════════════
_SAMPLE_ICAL = """BEGIN:VCALENDAR
VERSION:2.0
PRODID:-//Airbnb//Hosting Calendar//EN
BEGIN:VEVENT
UID:aaa-111@airbnb
DTSTART;VALUE=DATE:20270901
DTEND;VALUE=DATE:20270905
SUMMARY:Airbnb Reservation
END:VEVENT
BEGIN:VEVENT
UID:bbb-222@airbnb
DTSTART;VALUE=DATE:20270920
DTEND;VALUE=DATE:20270922
SUMMARY:Not available
END:VEVENT
END:VCALENDAR
"""


def test_ical_roundtrip():
    """Feed we emit must parse back into identical events."""
    events = [
        ical_service.ICalEvent(
            uid="test-1", start=date(2027, 5, 1),
            end=date(2027, 5, 5), summary="Booked",
        ),
        ical_service.ICalEvent(
            uid="test-2", start=date(2027, 5, 10),
            end=date(2027, 5, 12), summary="Blocked, note",
        ),
    ]
    feed = ical_service.build_feed(events=events, cal_name="My Cal")
    parsed = ical_service.parse_feed(feed)
    assert len(parsed) == 2
    assert parsed[0].uid == "test-1"
    assert parsed[0].start == date(2027, 5, 1)
    assert parsed[0].end == date(2027, 5, 5)
    assert parsed[1].summary == "Blocked, note"


@pytest.mark.asyncio
async def test_create_and_sync_import_creates_blocks(
    owner_client: AsyncClient, guest_client: AsyncClient,
):
    pid = await _seed_prop(owner_client)

    r = await owner_client.post("/calendar/imports", json={
        "property_id": pid,
        "name": "Airbnb",
        "url": "https://example.com/cal.ics",
    })
    assert r.status_code == 201, r.text
    import_id = r.json()["id"]

    async def _fake_fetch(url: str) -> str:  # noqa: ANN001
        return _SAMPLE_ICAL

    with patch(
        "app.routers.calendar._fetch_ical", side_effect=_fake_fetch,
    ):
        r = await owner_client.post(f"/calendar/imports/{import_id}/sync")
    assert r.status_code == 200, r.text
    data = r.json()
    assert data["imported"] == 2
    assert data["removed"] == 0
    assert data["last_error"] is None

    # The two VEVENTs should appear as CalendarBlocks.
    from tests.conftest import TestSession
    async with TestSession() as db:
        rows = (await db.execute(
            select(CalendarBlock).where(CalendarBlock.property_id == pid)
        )).scalars().all()
    assert len(rows) == 2
    assert all(b.source == BlockSource.imported for b in rows)

    # Guest can't book in the imported window.
    r = await guest_client.post("/bookings", json={
        "property_id": pid,
        "check_in": "2027-09-02",
        "check_out": "2027-09-04",
        "guests_count": 1,
    })
    assert r.status_code == 409


@pytest.mark.asyncio
async def test_sync_prunes_stale_entries(owner_client: AsyncClient):
    pid = await _seed_prop(owner_client)
    import_id = (await owner_client.post("/calendar/imports", json={
        "property_id": pid,
        "name": "Airbnb",
        "url": "https://example.com/cal.ics",
    })).json()["id"]

    async def _fake_fetch_full(url: str) -> str:
        return _SAMPLE_ICAL

    async def _fake_fetch_small(url: str) -> str:
        # Keep only the first event — second should be pruned.
        return """BEGIN:VCALENDAR
VERSION:2.0
BEGIN:VEVENT
UID:aaa-111@airbnb
DTSTART;VALUE=DATE:20270901
DTEND;VALUE=DATE:20270905
SUMMARY:Airbnb Reservation
END:VEVENT
END:VCALENDAR
"""

    with patch("app.routers.calendar._fetch_ical", side_effect=_fake_fetch_full):
        await owner_client.post(f"/calendar/imports/{import_id}/sync")
    with patch("app.routers.calendar._fetch_ical", side_effect=_fake_fetch_small):
        r = await owner_client.post(f"/calendar/imports/{import_id}/sync")
    data = r.json()
    assert data["imported"] == 0
    assert data["removed"] == 1

    from tests.conftest import TestSession
    async with TestSession() as db:
        rows = (await db.execute(
            select(CalendarBlock).where(CalendarBlock.import_id == import_id)
        )).scalars().all()
    assert len(rows) == 1


@pytest.mark.asyncio
async def test_delete_import_cascades_blocks(owner_client: AsyncClient):
    pid = await _seed_prop(owner_client)
    import_id = (await owner_client.post("/calendar/imports", json={
        "property_id": pid,
        "name": "Airbnb",
        "url": "https://example.com/cal.ics",
    })).json()["id"]

    async def _fake(url: str) -> str:
        return _SAMPLE_ICAL

    with patch("app.routers.calendar._fetch_ical", side_effect=_fake):
        await owner_client.post(f"/calendar/imports/{import_id}/sync")

    await owner_client.delete(f"/calendar/imports/{import_id}")

    from tests.conftest import TestSession
    async with TestSession() as db:
        imp = await db.get(CalendarImport, import_id)
        rows = (await db.execute(
            select(CalendarBlock).where(CalendarBlock.import_id == import_id)
        )).scalars().all()
    assert imp is None
    assert rows == []


@pytest.mark.asyncio
async def test_other_owner_cannot_access_import(
    owner_client: AsyncClient, guest_client: AsyncClient,
):
    pid = await _seed_prop(owner_client)
    import_id = (await owner_client.post("/calendar/imports", json={
        "property_id": pid,
        "name": "Airbnb",
        "url": "https://example.com/cal.ics",
    })).json()["id"]
    r = await guest_client.delete(f"/calendar/imports/{import_id}")
    # Guest doesn't own the property → 403 (or 404 if property not found).
    assert r.status_code in (403, 404)
