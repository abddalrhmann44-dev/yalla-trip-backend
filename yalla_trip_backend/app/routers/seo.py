"""SEO & social-sharing endpoints (Wave 20).

Exposes:

- ``GET /sitemap.xml`` – All approved properties + static pages (for
  Google / Bing indexing).
- ``GET /robots.txt`` – Points crawlers at the sitemap.
- ``GET /p/{property_id}`` – Lightweight HTML landing page with Open
  Graph, Twitter Cards, JSON-LD structured data, a Smart App Banner,
  and a ``talaa://properties/<id>`` deep-link fallback.  The page
  auto-redirects mobile browsers into the app via the universal link.
- ``GET /.well-known/assetlinks.json`` – Android App Links verification.
- ``GET /.well-known/apple-app-site-association`` – iOS Universal Links.

All routes are public, cacheable, and never touch auth.
"""

from __future__ import annotations

import html
import json
from datetime import datetime, timezone
from typing import Optional

from fastapi import APIRouter, Depends, Request, Response
from fastapi.responses import HTMLResponse, JSONResponse, PlainTextResponse
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import get_settings
from app.database import get_db
from app.models.property import Property, PropertyStatus

router = APIRouter(tags=["SEO"])


def _public_url(path: str = "") -> str:
    base = get_settings().PUBLIC_APP_URL.rstrip("/")
    if not path:
        return base
    return f"{base}/{path.lstrip('/')}"


# ══════════════════════════════════════════════════════════════
#  robots.txt
# ══════════════════════════════════════════════════════════════

@router.get("/robots.txt", response_class=PlainTextResponse)
async def robots_txt() -> str:
    """Allow everything, point crawlers at our sitemap."""
    sitemap = _public_url("sitemap.xml")
    return (
        "User-agent: *\n"
        "Allow: /\n"
        "Disallow: /admin\n"
        "Disallow: /auth\n"
        f"Sitemap: {sitemap}\n"
    )


# ══════════════════════════════════════════════════════════════
#  sitemap.xml
# ══════════════════════════════════════════════════════════════

@router.get("/sitemap.xml")
async def sitemap_xml(db: AsyncSession = Depends(get_db)) -> Response:
    """Return a sitemap of all approved properties + key static pages."""
    # Static URLs
    static_pages = [
        ("", 1.0, "daily"),
        ("about", 0.6, "monthly"),
        ("terms", 0.3, "yearly"),
        ("privacy", 0.3, "yearly"),
    ]

    # Approved properties only
    stmt = (
        select(Property.id, Property.updated_at)
        .where(Property.status == PropertyStatus.approved)
        .order_by(Property.updated_at.desc())
        .limit(50_000)  # hard cap per sitemap spec
    )
    rows = (await db.execute(stmt)).all()

    xml_parts = [
        '<?xml version="1.0" encoding="UTF-8"?>',
        '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">',
    ]

    for slug, priority, changefreq in static_pages:
        xml_parts.append("  <url>")
        xml_parts.append(f"    <loc>{html.escape(_public_url(slug))}</loc>")
        xml_parts.append(f"    <changefreq>{changefreq}</changefreq>")
        xml_parts.append(f"    <priority>{priority:.1f}</priority>")
        xml_parts.append("  </url>")

    for pid, updated in rows:
        loc = html.escape(_public_url(f"p/{pid}"))
        lastmod = (updated or datetime.now(timezone.utc)).date().isoformat()
        xml_parts.append("  <url>")
        xml_parts.append(f"    <loc>{loc}</loc>")
        xml_parts.append(f"    <lastmod>{lastmod}</lastmod>")
        xml_parts.append("    <changefreq>weekly</changefreq>")
        xml_parts.append("    <priority>0.8</priority>")
        xml_parts.append("  </url>")

    xml_parts.append("</urlset>")
    return Response(
        content="\n".join(xml_parts),
        media_type="application/xml",
        headers={"Cache-Control": "public, max-age=3600"},
    )


# ══════════════════════════════════════════════════════════════
#  /p/{id} – HTML landing page with OG + deep-link
# ══════════════════════════════════════════════════════════════

_LANDING_TEMPLATE = """\
<!DOCTYPE html>
<html lang="ar" dir="rtl">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>{title}</title>
  <meta name="description" content="{description}">

  <!-- Open Graph / Facebook -->
  <meta property="og:type" content="product">
  <meta property="og:url" content="{canonical}">
  <meta property="og:title" content="{title}">
  <meta property="og:description" content="{description}">
  <meta property="og:image" content="{image}">
  <meta property="og:locale" content="ar_EG">
  <meta property="og:site_name" content="Talaa — طلعة">

  <!-- Twitter -->
  <meta name="twitter:card" content="summary_large_image">
  <meta name="twitter:url" content="{canonical}">
  <meta name="twitter:title" content="{title}">
  <meta name="twitter:description" content="{description}">
  <meta name="twitter:image" content="{image}">

  {ios_meta}

  <!-- JSON-LD structured data -->
  <script type="application/ld+json">
{jsonld}
  </script>

  <link rel="canonical" href="{canonical}">
  <style>
    body {{ font-family: -apple-system, Segoe UI, Roboto, Cairo, sans-serif;
           margin: 0; background: #f5f5f7; color: #1c1c1e; }}
    .hero {{ max-width: 700px; margin: 40px auto; padding: 24px;
             background: #fff; border-radius: 20px;
             box-shadow: 0 4px 24px rgba(0,0,0,.06); }}
    .hero img {{ width: 100%; border-radius: 16px; aspect-ratio: 16/9;
                 object-fit: cover; }}
    h1 {{ margin: 16px 0 4px; font-size: 24px; }}
    .price {{ color: #0a7cff; font-weight: 700; font-size: 20px; }}
    .cta {{ display: inline-block; margin-top: 16px; padding: 14px 28px;
            background: #0a7cff; color: #fff; border-radius: 999px;
            text-decoration: none; font-weight: 600; }}
  </style>
</head>
<body>
  <main class="hero">
    <img src="{image}" alt="{title}">
    <h1>{title}</h1>
    <p class="price">{price_line}</p>
    <p>{description}</p>
    <a class="cta" href="{deeplink}" id="open-app">افتح في تطبيق Talaa</a>
  </main>

  <script>
    // Try to open the native app via the custom scheme; fall back to the
    // universal link (current page).  Desktop users just see the HTML.
    (function() {{
      const ua = navigator.userAgent || "";
      const isMobile = /iPhone|iPad|iPod|Android/i.test(ua);
      if (isMobile) {{
        window.location.href = "{deeplink}";
      }}
    }})();
  </script>
</body>
</html>
"""


@router.get("/p/{property_id}", response_class=HTMLResponse)
async def property_landing(
    property_id: int,
    db: AsyncSession = Depends(get_db),
) -> HTMLResponse:
    """SEO/shareable landing page for a single property."""
    prop = (await db.execute(
        select(Property).where(Property.id == property_id)
    )).scalar_one_or_none()

    if prop is None or prop.status != PropertyStatus.approved:
        return HTMLResponse(
            "<h1>404 — not found</h1>",
            status_code=404,
            headers={"Cache-Control": "public, max-age=60"},
        )

    settings = get_settings()
    canonical = _public_url(f"p/{prop.id}")
    deeplink = f"talaa://properties/{prop.id}"

    title_raw = f"{prop.name} — {prop.area.value}"
    desc_raw = (
        (prop.description or "")[:160]
        or f"{prop.category.value} في {prop.area.value} بسعر {int(prop.price_per_night)} ج.م/ليلة"
    )
    image = (prop.images or [""])[0] if prop.images else ""
    if not image:
        image = _public_url("static/og-fallback.jpg")

    price_line = f"{int(prop.price_per_night)} ج.م / ليلة"

    # iOS Smart App Banner (only if IOS_APP_ID is set)
    ios_meta = ""
    if settings.IOS_APP_ID:
        ios_meta = (
            f'<meta name="apple-itunes-app" '
            f'content="app-id={settings.IOS_APP_ID}, app-argument={deeplink}">'
        )

    jsonld = json.dumps({
        "@context": "https://schema.org",
        "@type": "LodgingBusiness",
        "name": prop.name,
        "description": prop.description or "",
        "image": image,
        "address": {"@type": "PostalAddress", "addressRegion": prop.area.value},
        "priceRange": f"EGP {int(prop.price_per_night)}/night",
        "aggregateRating": {
            "@type": "AggregateRating",
            "ratingValue": round(prop.rating or 0, 1),
            "reviewCount": prop.review_count or 0,
        } if (prop.review_count or 0) > 0 else None,
    }, ensure_ascii=False, indent=2)

    html_body = _LANDING_TEMPLATE.format(
        title=html.escape(title_raw),
        description=html.escape(desc_raw),
        canonical=html.escape(canonical),
        image=html.escape(image),
        price_line=html.escape(price_line),
        deeplink=html.escape(deeplink),
        ios_meta=ios_meta,
        jsonld=jsonld,
    )
    return HTMLResponse(
        html_body,
        headers={"Cache-Control": "public, max-age=600"},
    )


# ══════════════════════════════════════════════════════════════
#  Deep-link ownership proofs
# ══════════════════════════════════════════════════════════════

@router.get("/.well-known/assetlinks.json")
async def assetlinks_json() -> Response:
    """Android App Links verification file."""
    settings = get_settings()
    fingerprints = [
        f.strip().upper()
        for f in (settings.ANDROID_SHA256_FINGERPRINTS or "").split(",")
        if f.strip()
    ]
    if not fingerprints or not settings.ANDROID_PACKAGE_NAME:
        # Return an empty array so the path still resolves without 404.
        return JSONResponse([], headers={"Cache-Control": "public, max-age=3600"})

    payload = [{
        "relation": ["delegate_permission/common.handle_all_urls"],
        "target": {
            "namespace": "android_app",
            "package_name": settings.ANDROID_PACKAGE_NAME,
            "sha256_cert_fingerprints": fingerprints,
        },
    }]
    return JSONResponse(payload, headers={"Cache-Control": "public, max-age=3600"})


@router.get("/.well-known/apple-app-site-association")
async def apple_app_site_association() -> Response:
    """iOS Universal Links verification file.

    Must be served with ``Content-Type: application/json`` and without a
    ``.json`` extension.  Apple is strict: returning 404 breaks deep
    links app-wide, so we always produce a valid JSON body even when
    unconfigured.
    """
    settings = get_settings()
    if not settings.IOS_TEAM_ID or not settings.IOS_BUNDLE_ID:
        body = {"applinks": {"apps": [], "details": []}}
    else:
        app_id = f"{settings.IOS_TEAM_ID}.{settings.IOS_BUNDLE_ID}"
        body = {
            "applinks": {
                "apps": [],
                "details": [{
                    "appID": app_id,
                    "paths": ["/p/*", "/signup", "/", "NOT /admin/*"],
                }],
            },
        }
    return Response(
        content=json.dumps(body),
        media_type="application/json",
        headers={"Cache-Control": "public, max-age=3600"},
    )
