"""Tests for Wave 14 – Host availability editor.

Covers:
- CRUD for availability rules
- Bulk create / delete
- Calendar grid endpoint
- Pricing overrides affect booking total
- Min-stay enforcement
- Closed-day enforcement (booking + search)
"""

from datetime import date, timedelta

import pytest
from httpx import ASGITransport, AsyncClient

from app.main import app as _app


@pytest.fixture
def anyio_backend():
    return "asyncio"


# ── Helpers ──────────────────────────────────────────────────
TODAY = date.today()
FUTURE_START = TODAY + timedelta(days=30)
FUTURE_END = FUTURE_START + timedelta(days=10)


async def _create_property(owner_client: AsyncClient) -> int:
    resp = await owner_client.post("/properties", json={
        "name": "فيلا التوفر",
        "area": "الساحل الشمالي",
        "category": "فيلا",
        "price_per_night": 1000,
        "bedrooms": 3,
        "max_guests": 6,
    })
    assert resp.status_code == 201
    return resp.json()["id"]


# ══════════════════════════════════════════════════════════════
#  CRUD tests
# ══════════════════════════════════════════════════════════════

@pytest.mark.asyncio
async def test_create_pricing_rule(owner_client: AsyncClient):
    pid = await _create_property(owner_client)
    resp = await owner_client.post(f"/availability/{pid}/rules", json={
        "rule_type": "pricing",
        "start_date": FUTURE_START.isoformat(),
        "end_date": FUTURE_END.isoformat(),
        "price_override": 1500,
        "label": "عيد الأضحى",
    })
    assert resp.status_code == 201
    data = resp.json()
    assert data["rule_type"] == "pricing"
    assert data["price_override"] == 1500
    assert data["label"] == "عيد الأضحى"
    assert data["property_id"] == pid


@pytest.mark.asyncio
async def test_create_min_stay_rule(owner_client: AsyncClient):
    pid = await _create_property(owner_client)
    resp = await owner_client.post(f"/availability/{pid}/rules", json={
        "rule_type": "min_stay",
        "start_date": FUTURE_START.isoformat(),
        "end_date": FUTURE_END.isoformat(),
        "min_nights": 3,
    })
    assert resp.status_code == 201
    assert resp.json()["min_nights"] == 3


@pytest.mark.asyncio
async def test_create_closed_rule(owner_client: AsyncClient):
    pid = await _create_property(owner_client)
    resp = await owner_client.post(f"/availability/{pid}/rules", json={
        "rule_type": "closed",
        "start_date": FUTURE_START.isoformat(),
        "end_date": (FUTURE_START + timedelta(days=3)).isoformat(),
        "label": "صيانة",
    })
    assert resp.status_code == 201
    assert resp.json()["rule_type"] == "closed"


@pytest.mark.asyncio
async def test_list_rules_filters(owner_client: AsyncClient):
    pid = await _create_property(owner_client)
    # Create two different rule types
    await owner_client.post(f"/availability/{pid}/rules", json={
        "rule_type": "pricing",
        "start_date": FUTURE_START.isoformat(),
        "end_date": FUTURE_END.isoformat(),
        "price_override": 2000,
    })
    await owner_client.post(f"/availability/{pid}/rules", json={
        "rule_type": "closed",
        "start_date": (FUTURE_END + timedelta(days=1)).isoformat(),
        "end_date": (FUTURE_END + timedelta(days=5)).isoformat(),
    })

    # List all
    resp = await owner_client.get(f"/availability/{pid}/rules")
    assert resp.status_code == 200
    assert len(resp.json()) == 2

    # Filter by type
    resp = await owner_client.get(f"/availability/{pid}/rules?rule_type=pricing")
    assert resp.status_code == 200
    assert len(resp.json()) == 1
    assert resp.json()[0]["rule_type"] == "pricing"


@pytest.mark.asyncio
async def test_update_rule(owner_client: AsyncClient):
    pid = await _create_property(owner_client)
    resp = await owner_client.post(f"/availability/{pid}/rules", json={
        "rule_type": "pricing",
        "start_date": FUTURE_START.isoformat(),
        "end_date": FUTURE_END.isoformat(),
        "price_override": 1500,
    })
    rule_id = resp.json()["id"]

    resp = await owner_client.put(f"/availability/{pid}/rules/{rule_id}", json={
        "price_override": 1800,
        "label": "Updated",
    })
    assert resp.status_code == 200
    assert resp.json()["price_override"] == 1800
    assert resp.json()["label"] == "Updated"


@pytest.mark.asyncio
async def test_delete_rule(owner_client: AsyncClient):
    pid = await _create_property(owner_client)
    resp = await owner_client.post(f"/availability/{pid}/rules", json={
        "rule_type": "closed",
        "start_date": FUTURE_START.isoformat(),
        "end_date": FUTURE_END.isoformat(),
    })
    rule_id = resp.json()["id"]

    resp = await owner_client.delete(f"/availability/{pid}/rules/{rule_id}")
    assert resp.status_code == 204

    # Verify gone
    resp = await owner_client.get(f"/availability/{pid}/rules")
    assert resp.status_code == 200
    assert len(resp.json()) == 0


@pytest.mark.asyncio
async def test_guest_cannot_manage_rules(
    owner_client: AsyncClient, guest_client: AsyncClient
):
    pid = await _create_property(owner_client)
    resp = await guest_client.post(f"/availability/{pid}/rules", json={
        "rule_type": "pricing",
        "start_date": FUTURE_START.isoformat(),
        "end_date": FUTURE_END.isoformat(),
        "price_override": 1500,
    })
    assert resp.status_code == 403


# ══════════════════════════════════════════════════════════════
#  Bulk operations
# ══════════════════════════════════════════════════════════════

@pytest.mark.asyncio
async def test_bulk_create_rules(owner_client: AsyncClient):
    pid = await _create_property(owner_client)
    resp = await owner_client.post(f"/availability/{pid}/rules/bulk", json={
        "rules": [
            {
                "rule_type": "pricing",
                "start_date": FUTURE_START.isoformat(),
                "end_date": (FUTURE_START + timedelta(days=5)).isoformat(),
                "price_override": 1200,
            },
            {
                "rule_type": "min_stay",
                "start_date": FUTURE_START.isoformat(),
                "end_date": (FUTURE_START + timedelta(days=5)).isoformat(),
                "min_nights": 2,
            },
        ]
    })
    assert resp.status_code == 201
    assert len(resp.json()) == 2


@pytest.mark.asyncio
async def test_bulk_delete_rules(owner_client: AsyncClient):
    pid = await _create_property(owner_client)
    # Create two rules
    r1 = await owner_client.post(f"/availability/{pid}/rules", json={
        "rule_type": "pricing",
        "start_date": FUTURE_START.isoformat(),
        "end_date": FUTURE_END.isoformat(),
        "price_override": 1200,
    })
    r2 = await owner_client.post(f"/availability/{pid}/rules", json={
        "rule_type": "closed",
        "start_date": (FUTURE_END + timedelta(days=1)).isoformat(),
        "end_date": (FUTURE_END + timedelta(days=5)).isoformat(),
    })
    ids = [r1.json()["id"], r2.json()["id"]]

    resp = await owner_client.post(f"/availability/{pid}/rules/bulk-delete", json={
        "ids": ids,
    })
    assert resp.status_code == 204

    resp = await owner_client.get(f"/availability/{pid}/rules")
    assert len(resp.json()) == 0


# ══════════════════════════════════════════════════════════════
#  Calendar grid
# ══════════════════════════════════════════════════════════════

@pytest.mark.asyncio
async def test_calendar_grid_shows_overrides(owner_client: AsyncClient):
    pid = await _create_property(owner_client)
    # Set a pricing override for 5 days
    override_start = FUTURE_START
    override_end = FUTURE_START + timedelta(days=5)
    await owner_client.post(f"/availability/{pid}/rules", json={
        "rule_type": "pricing",
        "start_date": override_start.isoformat(),
        "end_date": override_end.isoformat(),
        "price_override": 2000,
    })

    resp = await owner_client.get(
        f"/availability/{pid}/calendar",
        params={"start": override_start.isoformat(), "end": override_end.isoformat()},
    )
    assert resp.status_code == 200
    days = resp.json()
    assert len(days) == 5
    # All days should have effective_price == 2000
    for d in days:
        assert d["effective_price"] == 2000


@pytest.mark.asyncio
async def test_calendar_grid_shows_closed(owner_client: AsyncClient):
    pid = await _create_property(owner_client)
    closed_start = FUTURE_START
    closed_end = FUTURE_START + timedelta(days=2)
    await owner_client.post(f"/availability/{pid}/rules", json={
        "rule_type": "closed",
        "start_date": closed_start.isoformat(),
        "end_date": closed_end.isoformat(),
    })

    resp = await owner_client.get(
        f"/availability/{pid}/calendar",
        params={"start": closed_start.isoformat(), "end": closed_end.isoformat()},
    )
    assert resp.status_code == 200
    days = resp.json()
    assert all(d["is_closed"] for d in days)


# ══════════════════════════════════════════════════════════════
#  Booking integration
# ══════════════════════════════════════════════════════════════

@pytest.mark.asyncio
async def test_pricing_override_affects_booking_total(
    owner_client: AsyncClient, guest_client: AsyncClient
):
    """Booking price should use the override (2000/night) not base (1000)."""
    pid = await _create_property(owner_client)
    ci = FUTURE_START
    co = ci + timedelta(days=3)

    # Set pricing override
    await owner_client.post(f"/availability/{pid}/rules", json={
        "rule_type": "pricing",
        "start_date": ci.isoformat(),
        "end_date": co.isoformat(),
        "price_override": 2000,
    })

    resp = await guest_client.post("/bookings", json={
        "property_id": pid,
        "check_in": ci.isoformat(),
        "check_out": co.isoformat(),
        "guests_count": 2,
    })
    assert resp.status_code == 201
    booking = resp.json()
    # Villa: no cleaning/utility/deposit fees. Total = 3 nights × 2000 = 6000
    assert booking["total_price"] == 6000


@pytest.mark.asyncio
async def test_min_stay_blocks_short_booking(
    owner_client: AsyncClient, guest_client: AsyncClient
):
    """A 2-night booking should fail when min_stay is 3."""
    pid = await _create_property(owner_client)
    ci = FUTURE_START
    co = ci + timedelta(days=2)

    await owner_client.post(f"/availability/{pid}/rules", json={
        "rule_type": "min_stay",
        "start_date": ci.isoformat(),
        "end_date": (ci + timedelta(days=10)).isoformat(),
        "min_nights": 3,
    })

    resp = await guest_client.post("/bookings", json={
        "property_id": pid,
        "check_in": ci.isoformat(),
        "check_out": co.isoformat(),
        "guests_count": 2,
    })
    assert resp.status_code == 422
    assert "3" in resp.json()["detail"]


@pytest.mark.asyncio
async def test_min_stay_allows_long_booking(
    owner_client: AsyncClient, guest_client: AsyncClient
):
    """A 4-night booking should pass when min_stay is 3."""
    pid = await _create_property(owner_client)
    ci = FUTURE_START
    co = ci + timedelta(days=4)

    await owner_client.post(f"/availability/{pid}/rules", json={
        "rule_type": "min_stay",
        "start_date": ci.isoformat(),
        "end_date": (ci + timedelta(days=10)).isoformat(),
        "min_nights": 3,
    })

    resp = await guest_client.post("/bookings", json={
        "property_id": pid,
        "check_in": ci.isoformat(),
        "check_out": co.isoformat(),
        "guests_count": 2,
    })
    assert resp.status_code == 201


@pytest.mark.asyncio
async def test_closed_days_block_booking(
    owner_client: AsyncClient, guest_client: AsyncClient
):
    """Booking into closed dates should be rejected."""
    pid = await _create_property(owner_client)
    ci = FUTURE_START
    co = ci + timedelta(days=3)

    await owner_client.post(f"/availability/{pid}/rules", json={
        "rule_type": "closed",
        "start_date": ci.isoformat(),
        "end_date": (ci + timedelta(days=5)).isoformat(),
    })

    resp = await guest_client.post("/bookings", json={
        "property_id": pid,
        "check_in": ci.isoformat(),
        "check_out": co.isoformat(),
        "guests_count": 2,
    })
    assert resp.status_code == 409
    assert "مغلقة" in resp.json()["detail"] or "closed" in resp.json()["detail"].lower()


@pytest.mark.asyncio
async def test_validation_end_before_start(owner_client: AsyncClient):
    """end_date <= start_date should be rejected."""
    pid = await _create_property(owner_client)
    resp = await owner_client.post(f"/availability/{pid}/rules", json={
        "rule_type": "pricing",
        "start_date": FUTURE_END.isoformat(),
        "end_date": FUTURE_START.isoformat(),
        "price_override": 1500,
    })
    assert resp.status_code == 422


@pytest.mark.asyncio
async def test_pricing_rule_requires_price_override(owner_client: AsyncClient):
    """pricing rule without price_override should fail validation."""
    pid = await _create_property(owner_client)
    resp = await owner_client.post(f"/availability/{pid}/rules", json={
        "rule_type": "pricing",
        "start_date": FUTURE_START.isoformat(),
        "end_date": FUTURE_END.isoformat(),
    })
    assert resp.status_code == 422
