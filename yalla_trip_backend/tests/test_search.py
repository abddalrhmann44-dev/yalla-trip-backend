"""Property search / filter / sort + autocomplete tests.

Exercises the Wave 12 improvements:

* Approved-only default inclusion.
* Description-level full-text matching.
* Date-range availability filter.
* ``best_match``, ``popularity``, ``distance`` sorting.
* ``/properties/suggest`` autocomplete.
* Amenities AND filter.
"""

from __future__ import annotations

from datetime import date, timedelta

import pytest
from httpx import AsyncClient
from sqlalchemy import update

from app.models.booking import Booking, BookingStatus, PaymentStatus
from app.models.property import (
    Area, Category, Property, PropertyStatus,
)


# ── helpers ───────────────────────────────────────────────
async def _seed_props(owner: AsyncClient, n: int = 1) -> list[int]:
    ids: list[int] = []
    for i in range(n):
        resp = await owner.post("/properties", json={
            "name": f"عقار اختبار {i}",
            "description": "شاليه على البحر مباشرة مع مسبح خاص وكراج",
            "area": "الساحل الشمالي",
            "category": "شاليه",
            "price_per_night": 500 + i * 100,
            "bedrooms": 2,
            "max_guests": 6,
            "amenities": ["pool", "wifi", "ac"] if i % 2 == 0 else ["wifi"],
            "latitude": 31.0 + i * 0.01,
            "longitude": 30.0 + i * 0.01,
        })
        assert resp.status_code in (200, 201), resp.text
        ids.append(resp.json()["id"])
    return ids


async def _approve(ids: list[int]) -> None:
    """Bypass the admin approval flow by flipping state directly."""
    from tests.conftest import TestSession
    async with TestSession() as db:
        await db.execute(
            update(Property)
            .where(Property.id.in_(ids))
            .values(status=PropertyStatus.approved)
        )
        await db.commit()


# ══════════════════════════════════════════════════════════════
#  Approved-only default
# ══════════════════════════════════════════════════════════════
@pytest.mark.asyncio
async def test_list_hides_unapproved_by_default(
    owner_client: AsyncClient, guest_client: AsyncClient,
):
    [pid] = await _seed_props(owner_client, n=1)
    # Still pending — guest must not see it.
    r = await guest_client.get("/properties", params={"search": "اختبار"})
    assert r.status_code == 200
    ids = [p["id"] for p in r.json()["items"]]
    assert pid not in ids

    # Approve, now it appears.
    await _approve([pid])
    r = await guest_client.get("/properties", params={"search": "اختبار"})
    ids = [p["id"] for p in r.json()["items"]]
    assert pid in ids


# ══════════════════════════════════════════════════════════════
#  Description-level full-text search
# ══════════════════════════════════════════════════════════════
@pytest.mark.asyncio
async def test_search_matches_description(
    owner_client: AsyncClient, guest_client: AsyncClient,
):
    ids = await _seed_props(owner_client, n=1)
    await _approve(ids)
    # "مسبح" appears in description only.
    r = await guest_client.get("/properties", params={"search": "مسبح"})
    assert r.status_code == 200
    returned = [p["id"] for p in r.json()["items"]]
    assert ids[0] in returned


# ══════════════════════════════════════════════════════════════
#  Date-range availability
# ══════════════════════════════════════════════════════════════
@pytest.mark.asyncio
async def test_date_range_excludes_conflict(
    owner_client: AsyncClient, guest_client: AsyncClient,
):
    from tests.conftest import TestSession

    [pid] = await _seed_props(owner_client, n=1)
    await _approve([pid])

    # Fake a confirmed booking in the Apr 1–5 range.
    async with TestSession() as db:
        b = Booking(
            booking_code="SRCH0001",
            property_id=pid,
            guest_id=1, owner_id=2,
            check_in=date(2027, 4, 1),
            check_out=date(2027, 4, 5),
            total_price=2000, platform_fee=160, owner_payout=1840,
            status=BookingStatus.confirmed,
            payment_status=PaymentStatus.paid,
        )
        db.add(b)
        await db.commit()

    # Overlapping range → excluded.
    r = await guest_client.get(
        "/properties",
        params={
            "check_in": "2027-04-03",
            "check_out": "2027-04-07",
        },
    )
    assert pid not in [p["id"] for p in r.json()["items"]]

    # Non-overlapping range → visible.
    r = await guest_client.get(
        "/properties",
        params={
            "check_in": "2027-04-10",
            "check_out": "2027-04-12",
        },
    )
    assert pid in [p["id"] for p in r.json()["items"]]


# ══════════════════════════════════════════════════════════════
#  Sorting
# ══════════════════════════════════════════════════════════════
@pytest.mark.asyncio
async def test_sort_price_asc(
    owner_client: AsyncClient, guest_client: AsyncClient,
):
    ids = await _seed_props(owner_client, n=3)
    await _approve(ids)

    r = await guest_client.get(
        "/properties",
        params={"sort_by": "price_asc", "search": "اختبار"},
    )
    prices = [p["price_per_night"] for p in r.json()["items"]]
    assert prices == sorted(prices)


@pytest.mark.asyncio
async def test_sort_distance_requires_coords(guest_client: AsyncClient):
    r = await guest_client.get(
        "/properties",
        params={"sort_by": "distance"},
    )
    assert r.status_code == 400
    assert "latitude" in r.json()["detail"]


@pytest.mark.asyncio
async def test_sort_distance_orders_by_proximity(
    owner_client: AsyncClient, guest_client: AsyncClient,
):
    ids = await _seed_props(owner_client, n=3)
    await _approve(ids)

    # Query anchored at the first property's coords – it should win.
    r = await guest_client.get(
        "/properties",
        params={
            "sort_by": "distance",
            "latitude": 31.0, "longitude": 30.0,
            "search": "اختبار",
        },
    )
    items = r.json()["items"]
    assert items[0]["id"] == ids[0]


# ══════════════════════════════════════════════════════════════
#  Amenities AND filter
# ══════════════════════════════════════════════════════════════
@pytest.mark.asyncio
async def test_amenities_filter_and_semantics(
    owner_client: AsyncClient, guest_client: AsyncClient,
):
    ids = await _seed_props(owner_client, n=3)
    await _approve(ids)

    # Only even-index properties have "pool"; odd-only have "wifi".
    r = await guest_client.get(
        "/properties", params={"amenities": ["pool"], "search": "اختبار"},
    )
    returned = [p["id"] for p in r.json()["items"]]
    # ids[0] and ids[2] have pool, ids[1] does not.
    assert ids[0] in returned
    assert ids[2] in returned
    assert ids[1] not in returned


# ══════════════════════════════════════════════════════════════
#  Autocomplete
# ══════════════════════════════════════════════════════════════
@pytest.mark.asyncio
async def test_suggest_returns_property_and_area(
    owner_client: AsyncClient, guest_client: AsyncClient,
):
    ids = await _seed_props(owner_client, n=1)
    await _approve(ids)

    r = await guest_client.get(
        "/properties/suggest", params={"q": "اختبار"}
    )
    assert r.status_code == 200
    data = r.json()
    assert data["query"] == "اختبار"
    kinds = {s["type"] for s in data["suggestions"]}
    assert "property" in kinds

    # Area query — matches an enum value.
    r = await guest_client.get(
        "/properties/suggest", params={"q": "الساحل"}
    )
    data = r.json()
    assert any(s["type"] == "area" for s in data["suggestions"])


@pytest.mark.asyncio
async def test_suggest_requires_query(guest_client: AsyncClient):
    r = await guest_client.get("/properties/suggest", params={"q": ""})
    assert r.status_code == 422
