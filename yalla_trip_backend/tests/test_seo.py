"""Tests for Wave 20 – SEO, deep links & social-sharing pages."""

import pytest
from httpx import AsyncClient


@pytest.fixture
def anyio_backend():
    return "asyncio"


# ── robots.txt ────────────────────────────────────────────────

@pytest.mark.asyncio
async def test_robots_txt(guest_client: AsyncClient):
    resp = await guest_client.get("/robots.txt")
    assert resp.status_code == 200
    assert "text/plain" in resp.headers["content-type"]
    body = resp.text
    assert "User-agent: *" in body
    assert "Sitemap:" in body
    assert "sitemap.xml" in body


# ── sitemap.xml ───────────────────────────────────────────────

@pytest.mark.asyncio
async def test_sitemap_xml_valid(guest_client: AsyncClient):
    resp = await guest_client.get("/sitemap.xml")
    assert resp.status_code == 200
    assert "xml" in resp.headers["content-type"]
    body = resp.text
    assert body.startswith('<?xml')
    assert "<urlset" in body
    assert "</urlset>" in body
    # At least the static home URL should be there
    assert "<loc>" in body


@pytest.mark.asyncio
async def test_sitemap_contains_approved_property(
    owner_client: AsyncClient, admin_client: AsyncClient, guest_client: AsyncClient
):
    # Create + approve a property
    create = await owner_client.post("/properties", json={
        "name": "فيلا Sitemap",
        "area": "الجونة",
        "category": "فيلا",
        "price_per_night": 2000,
        "bedrooms": 3,
        "max_guests": 6,
    })
    assert create.status_code == 201
    pid = create.json()["id"]
    approve = await admin_client.put(f"/admin/properties/{pid}/approve")
    assert approve.status_code == 200

    resp = await guest_client.get("/sitemap.xml")
    assert resp.status_code == 200
    assert f"/p/{pid}" in resp.text


# ── /p/{id} landing page ──────────────────────────────────────

@pytest.mark.asyncio
async def test_property_landing_not_found(guest_client: AsyncClient):
    resp = await guest_client.get("/p/999999")
    assert resp.status_code == 404


@pytest.mark.asyncio
async def test_property_landing_approved(
    owner_client: AsyncClient, admin_client: AsyncClient, guest_client: AsyncClient
):
    create = await owner_client.post("/properties", json={
        "name": "شاليه للمشاركة",
        "description": "إطلالة على البحر مباشرة",
        "area": "الساحل الشمالي",
        "category": "شاليه",
        "price_per_night": 1200,
        "bedrooms": 2,
        "max_guests": 4,
    })
    pid = create.json()["id"]
    await admin_client.put(f"/admin/properties/{pid}/approve")

    resp = await guest_client.get(f"/p/{pid}")
    assert resp.status_code == 200
    assert "text/html" in resp.headers["content-type"]
    html = resp.text

    # OG tags
    assert 'property="og:title"' in html
    assert 'property="og:image"' in html
    assert 'property="og:url"' in html
    # Twitter card
    assert 'name="twitter:card"' in html
    # Deep-link scheme
    assert f"talaa://properties/{pid}" in html
    # JSON-LD structured data
    assert '"@type": "LodgingBusiness"' in html
    # Property-specific content
    assert "شاليه للمشاركة" in html


@pytest.mark.asyncio
async def test_property_landing_pending_not_indexed(
    owner_client: AsyncClient, guest_client: AsyncClient
):
    """A non-approved property must not be publicly accessible (prevents
    leaking pending/rejected listings via sharing)."""
    create = await owner_client.post("/properties", json={
        "name": "Draft",
        "area": "الغردقة",
        "category": "فندق",
        "price_per_night": 500,
        "bedrooms": 1,
        "max_guests": 2,
    })
    pid = create.json()["id"]
    resp = await guest_client.get(f"/p/{pid}")
    assert resp.status_code == 404


# ── Deep-link manifests ───────────────────────────────────────

@pytest.mark.asyncio
async def test_assetlinks_json_returns_array(guest_client: AsyncClient):
    resp = await guest_client.get("/.well-known/assetlinks.json")
    assert resp.status_code == 200
    data = resp.json()
    assert isinstance(data, list)


@pytest.mark.asyncio
async def test_apple_app_site_association(guest_client: AsyncClient):
    resp = await guest_client.get("/.well-known/apple-app-site-association")
    assert resp.status_code == 200
    assert "application/json" in resp.headers["content-type"]
    data = resp.json()
    assert "applinks" in data
    assert "details" in data["applinks"]
