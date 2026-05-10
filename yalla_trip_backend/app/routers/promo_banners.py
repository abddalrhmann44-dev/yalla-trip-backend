"""Public ``/promo-banners`` endpoints — homepage carousel feed.

Two responsibilities:

1. ``GET /promo-banners/active`` — return the banners the public app
   should render *right now*.  Active means the row has
   ``is_active=True`` *and* the current time falls inside its
   optional ``start_at`` / ``end_at`` schedule window.  Anonymous
   access is allowed because the homepage hits this endpoint before
   the user logs in.

2. ``POST /promo-banners/{id}/impression`` and
   ``POST /promo-banners/{id}/click`` — best-effort engagement
   counters.  Public, idempotent-ish (we just increment), and rate-
   limited at the global middleware level — abuse here just inflates
   the metrics, not anything dangerous.
"""

from __future__ import annotations

from datetime import datetime
from typing import Optional

import structlog
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from sqlalchemy import and_, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.models.promo_banner import PromoBanner

logger = structlog.get_logger(__name__)
router = APIRouter(prefix="/promo-banners", tags=["PromoBanners"])


class PromoBannerPublic(BaseModel):
    """Slimmer public DTO — only the fields the homepage needs."""
    id: int
    title_ar: Optional[str] = None
    title_en: Optional[str] = None
    subtitle_ar: Optional[str] = None
    subtitle_en: Optional[str] = None
    image_url: str
    accent_color: Optional[str] = None
    cta_kind: str
    cta_target: Optional[str] = None
    priority: int


@router.get("/active", response_model=list[PromoBannerPublic])
async def active_banners(db: AsyncSession = Depends(get_db)):
    """Return the banners that should appear on the homepage right now.

    Filtering rules:

      - ``is_active`` must be ``true``.
      - ``start_at IS NULL OR start_at <= now()``
      - ``end_at   IS NULL OR end_at   >= now()``

    Sorted by ``priority DESC, created_at DESC`` so the admin's
    explicit ordering wins over insertion order.
    """
    now = datetime.now()
    rows = (await db.execute(
        select(PromoBanner)
        .where(
            and_(
                PromoBanner.is_active.is_(True),
                or_(
                    PromoBanner.start_at.is_(None),
                    PromoBanner.start_at <= now,
                ),
                or_(
                    PromoBanner.end_at.is_(None),
                    PromoBanner.end_at >= now,
                ),
            )
        )
        .order_by(
            PromoBanner.priority.desc(),
            PromoBanner.created_at.desc(),
        )
        .limit(10)
    )).scalars().all()
    return [
        PromoBannerPublic(
            id=r.id,
            title_ar=r.title_ar, title_en=r.title_en,
            subtitle_ar=r.subtitle_ar, subtitle_en=r.subtitle_en,
            image_url=r.image_url,
            accent_color=r.accent_color,
            cta_kind=r.cta_kind.value,
            cta_target=r.cta_target,
            priority=r.priority,
        )
        for r in rows
    ]


@router.post("/{banner_id}/impression")
async def log_impression(
    banner_id: int,
    db: AsyncSession = Depends(get_db),
):
    """Increment the impression counter (best-effort)."""
    row = await db.get(PromoBanner, banner_id)
    if row is None:
        raise HTTPException(status_code=404, detail="Banner not found")
    row.impressions = (row.impressions or 0) + 1
    await db.flush()
    return {"ok": True, "impressions": row.impressions}


@router.post("/{banner_id}/click")
async def log_click(
    banner_id: int,
    db: AsyncSession = Depends(get_db),
):
    """Increment the click counter (best-effort)."""
    row = await db.get(PromoBanner, banner_id)
    if row is None:
        raise HTTPException(status_code=404, detail="Banner not found")
    row.clicks = (row.clicks or 0) + 1
    await db.flush()
    return {"ok": True, "clicks": row.clicks}
