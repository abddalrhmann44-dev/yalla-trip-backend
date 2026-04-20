"""Calendar export / import endpoints (Wave 13).

Owners use this to plug external calendar feeds (Airbnb, Booking.com,
VRBO, Expedia) into a property so concurrent bookings are prevented,
and to share a read-only iCal feed of our bookings with those same
platforms — standard two-way channel-manager flow.

All mutating endpoints require the caller to own the property (or be
an admin).  The public feed URL embeds an opaque token on the property
row, rotatable by the owner, so feed sharing doesn't require an API
key while still being unguessable.
"""

from __future__ import annotations

import secrets
from datetime import datetime, timezone
from typing import List

import httpx
import structlog
from fastapi import (
    APIRouter, Depends, HTTPException, Request, Response, status,
)
from sqlalchemy import delete, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.middleware.auth_middleware import (
    get_current_active_user, require_role,
)
from app.models.booking import Booking, BookingStatus
from app.models.calendar import BlockSource, CalendarBlock, CalendarImport
from app.models.property import Property
from app.models.user import User, UserRole
from app.schemas.calendar import (
    CalendarBlockCreate, CalendarBlockOut,
    CalendarImportCreate, CalendarImportOut, CalendarImportUpdate,
    FeedTokenOut, SyncResult,
)
from app.services import ical_service

logger = structlog.get_logger(__name__)
router = APIRouter(prefix="/calendar", tags=["Calendar"])


# ── Helpers ──────────────────────────────────────────────
async def _load_property_or_403(
    db: AsyncSession, property_id: int, user: User,
) -> Property:
    prop = await db.get(Property, property_id)
    if prop is None:
        raise HTTPException(status_code=404, detail="Property not found")
    if user.role != UserRole.admin and prop.owner_id != user.id:
        raise HTTPException(status_code=403, detail="Not your property")
    return prop


async def _ensure_ical_token(db: AsyncSession, prop: Property) -> str:
    """Return the property's iCal token, generating one on first access."""
    if prop.ical_token:
        return prop.ical_token
    prop.ical_token = secrets.token_urlsafe(32)
    await db.flush()
    return prop.ical_token


def _feed_url(request: Request, property_id: int, token: str) -> str:
    base = str(request.base_url).rstrip("/")
    return f"{base}/calendar/{property_id}/{token}.ics"


# ══════════════════════════════════════════════════════════════
#  Export – public iCal feed
# ══════════════════════════════════════════════════════════════
@router.get(
    "/{property_id}/{token}.ics",
    response_class=Response,
    # Keep the route out of the JSON schema – it's consumed by bots.
    include_in_schema=False,
)
async def ical_feed(
    property_id: int,
    token: str,
    db: AsyncSession = Depends(get_db),
):
    """Return the property's bookings + manual blocks as an iCal feed.

    Authentication is via the opaque ``token`` in the URL — the owner
    can rotate it if it leaks.  No user header is required because the
    consumers are third-party calendar services with no TALAA account.
    """
    prop = (
        await db.execute(
            select(Property).where(
                Property.id == property_id,
                Property.ical_token == token,
            )
        )
    ).scalar_one_or_none()
    if prop is None:
        # Never reveal whether the property exists – just 404 uniformly.
        raise HTTPException(status_code=404, detail="Feed not found")

    # Bookings on our platform → CONFIRMED events.
    bookings = (
        await db.execute(
            select(Booking)
            .where(
                Booking.property_id == prop.id,
                Booking.status.in_(
                    [BookingStatus.pending, BookingStatus.confirmed]
                ),
            )
            .order_by(Booking.check_in.asc())
        )
    ).scalars().all()

    events: list[ical_service.ICalEvent] = []
    for b in bookings:
        events.append(ical_service.ICalEvent(
            uid=f"booking-{b.id}@talaa",
            start=b.check_in,
            end=b.check_out,
            summary="TALAA Reserved",
            description=f"Booking #{b.booking_code}",
        ))

    # Manual + imported blocks — re-export them too so a parent calendar
    # that subscribes to us sees a union of everything.
    blocks = (
        await db.execute(
            select(CalendarBlock)
            .where(CalendarBlock.property_id == prop.id)
            .order_by(CalendarBlock.start_date.asc())
        )
    ).scalars().all()
    for blk in blocks:
        events.append(ical_service.ICalEvent(
            uid=f"block-{blk.id}@talaa",
            start=blk.start_date,
            end=blk.end_date,
            summary=blk.summary or "Blocked",
        ))

    body = ical_service.build_feed(
        events=events,
        cal_name=f"TALAA – {prop.name}",
    )
    return Response(
        content=body,
        media_type="text/calendar; charset=utf-8",
        headers={
            "Content-Disposition":
                f'attachment; filename="talaa-{prop.id}.ics"',
            "Cache-Control": "private, max-age=300",
        },
    )


@router.post("/{property_id}/token", response_model=FeedTokenOut)
async def rotate_feed_token(
    property_id: int,
    request: Request,
    user: User = Depends(
        require_role(UserRole.owner, UserRole.admin)
    ),
    db: AsyncSession = Depends(get_db),
):
    """Generate (or rotate) the public iCal token for a property."""
    prop = await _load_property_or_403(db, property_id, user)
    prop.ical_token = secrets.token_urlsafe(32)
    await db.flush()
    return FeedTokenOut(
        property_id=prop.id,
        token=prop.ical_token,
        feed_url=_feed_url(request, prop.id, prop.ical_token),
    )


@router.get("/{property_id}/token", response_model=FeedTokenOut)
async def get_feed_token(
    property_id: int,
    request: Request,
    user: User = Depends(
        require_role(UserRole.owner, UserRole.admin)
    ),
    db: AsyncSession = Depends(get_db),
):
    """Return the current feed URL, generating a token on first call."""
    prop = await _load_property_or_403(db, property_id, user)
    token = await _ensure_ical_token(db, prop)
    return FeedTokenOut(
        property_id=prop.id,
        token=token,
        feed_url=_feed_url(request, prop.id, token),
    )


# ══════════════════════════════════════════════════════════════
#  Manual blocks – host UI for "I'm not renting this weekend"
# ══════════════════════════════════════════════════════════════
@router.get(
    "/blocks/mine/{property_id}",
    response_model=List[CalendarBlockOut],
)
async def list_blocks(
    property_id: int,
    user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db),
):
    await _load_property_or_403(db, property_id, user)
    rows = (
        await db.execute(
            select(CalendarBlock)
            .where(CalendarBlock.property_id == property_id)
            .order_by(CalendarBlock.start_date.asc())
        )
    ).scalars().all()
    return [CalendarBlockOut.model_validate(r) for r in rows]


@router.post(
    "/blocks",
    response_model=CalendarBlockOut,
    status_code=status.HTTP_201_CREATED,
)
async def create_block(
    body: CalendarBlockCreate,
    user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db),
):
    prop = await _load_property_or_403(db, body.property_id, user)
    if body.end_date <= body.start_date:
        raise HTTPException(
            status_code=400,
            detail="end_date must be after start_date",
        )
    block = CalendarBlock(
        property_id=prop.id,
        start_date=body.start_date,
        end_date=body.end_date,
        source=BlockSource.manual,
        summary=body.summary,
    )
    db.add(block)
    await db.flush()
    await db.refresh(block)
    return CalendarBlockOut.model_validate(block)


@router.delete("/blocks/{block_id}")
async def delete_block(
    block_id: int,
    user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db),
):
    block = await db.get(CalendarBlock, block_id)
    if block is None:
        raise HTTPException(status_code=404, detail="Block not found")
    if block.source != BlockSource.manual:
        raise HTTPException(
            status_code=400,
            detail="Only manual blocks can be removed here; delete the import instead.",
        )
    await _load_property_or_403(db, block.property_id, user)
    await db.delete(block)
    return {"ok": True}


# ══════════════════════════════════════════════════════════════
#  External calendar imports – CRUD + sync
# ══════════════════════════════════════════════════════════════
@router.get(
    "/imports/mine/{property_id}",
    response_model=List[CalendarImportOut],
)
async def list_imports(
    property_id: int,
    user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db),
):
    await _load_property_or_403(db, property_id, user)
    rows = (
        await db.execute(
            select(CalendarImport)
            .where(CalendarImport.property_id == property_id)
            .order_by(CalendarImport.created_at.desc())
        )
    ).scalars().all()
    return [CalendarImportOut.model_validate(r) for r in rows]


@router.post(
    "/imports",
    response_model=CalendarImportOut,
    status_code=status.HTTP_201_CREATED,
)
async def create_import(
    body: CalendarImportCreate,
    user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db),
):
    prop = await _load_property_or_403(db, body.property_id, user)
    imp = CalendarImport(
        property_id=prop.id,
        name=body.name,
        url=str(body.url),
        is_active=True,
    )
    db.add(imp)
    await db.flush()
    await db.refresh(imp)
    return CalendarImportOut.model_validate(imp)


@router.patch(
    "/imports/{import_id}",
    response_model=CalendarImportOut,
)
async def update_import(
    import_id: int,
    body: CalendarImportUpdate,
    user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db),
):
    imp = await db.get(CalendarImport, import_id)
    if imp is None:
        raise HTTPException(status_code=404, detail="Import not found")
    await _load_property_or_403(db, imp.property_id, user)

    if body.name is not None:
        imp.name = body.name
    if body.url is not None:
        imp.url = str(body.url)
    if body.is_active is not None:
        imp.is_active = body.is_active
    await db.flush()
    await db.refresh(imp)
    return CalendarImportOut.model_validate(imp)


@router.delete("/imports/{import_id}")
async def delete_import(
    import_id: int,
    user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db),
):
    imp = await db.get(CalendarImport, import_id)
    if imp is None:
        raise HTTPException(status_code=404, detail="Import not found")
    await _load_property_or_403(db, imp.property_id, user)
    await db.delete(imp)            # cascades to its calendar_blocks
    return {"ok": True}


# ── Sync (fetch + parse + upsert) ────────────────────────
async def _fetch_ical(url: str) -> str:
    """Download an iCalendar resource.  Split out so tests can patch it."""
    async with httpx.AsyncClient(
        timeout=15.0,
        follow_redirects=True,
        headers={"User-Agent": "TALAA-iCal/1.0"},
    ) as client:
        resp = await client.get(url)
    resp.raise_for_status()
    return resp.text


async def _sync_import(
    db: AsyncSession, imp: CalendarImport,
) -> SyncResult:
    """Pull ``imp.url``, parse, upsert blocks, prune stale ones."""
    try:
        text = await _fetch_ical(imp.url)
        events = ical_service.parse_feed(text)
    except Exception as exc:  # pragma: no cover – network issues
        imp.last_error = str(exc)[:500]
        imp.last_synced_at = datetime.now(tz=timezone.utc)
        await db.flush()
        return SyncResult(
            imported=0, removed=0,
            last_error=imp.last_error,
            last_synced_at=imp.last_synced_at,
        )

    # Existing blocks keyed by external_uid for diffing.
    existing = {
        b.external_uid: b for b in (
            await db.execute(
                select(CalendarBlock)
                .where(CalendarBlock.import_id == imp.id)
            )
        ).scalars().all()
    }

    seen: set[str] = set()
    imported = 0
    for ev in events:
        if ev.end <= ev.start:
            continue
        uid = ev.uid or f"{ev.start.isoformat()}_{ev.end.isoformat()}"
        seen.add(uid)
        if uid in existing:
            blk = existing[uid]
            blk.start_date = ev.start
            blk.end_date = ev.end
            blk.summary = ev.summary
        else:
            db.add(CalendarBlock(
                property_id=imp.property_id,
                import_id=imp.id,
                start_date=ev.start,
                end_date=ev.end,
                source=BlockSource.imported,
                summary=ev.summary,
                external_uid=uid,
            ))
            imported += 1

    # Prune blocks no longer in the feed.
    stale = [b.id for uid, b in existing.items() if uid not in seen]
    if stale:
        await db.execute(
            delete(CalendarBlock).where(CalendarBlock.id.in_(stale))
        )

    imp.last_error = None
    imp.last_synced_at = datetime.now(tz=timezone.utc)
    imp.last_event_count = len(seen)
    await db.flush()

    return SyncResult(
        imported=imported,
        removed=len(stale),
        last_error=None,
        last_synced_at=imp.last_synced_at,
    )


@router.post(
    "/imports/{import_id}/sync",
    response_model=SyncResult,
)
async def sync_import_endpoint(
    import_id: int,
    user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db),
):
    imp = await db.get(CalendarImport, import_id)
    if imp is None:
        raise HTTPException(status_code=404, detail="Import not found")
    await _load_property_or_403(db, imp.property_id, user)
    if not imp.is_active:
        raise HTTPException(status_code=400, detail="Import is disabled")
    return await _sync_import(db, imp)
