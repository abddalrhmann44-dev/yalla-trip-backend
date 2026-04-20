"""Chat router – price-negotiation conversations (Wave 23).

Endpoints
---------
GET    /chats                        → list my conversations
POST   /chats                        → start (or get) a negotiation about a property
GET    /chats/{cid}                  → single conversation meta
GET    /chats/{cid}/messages         → paginated history (oldest→newest)
POST   /chats/{cid}/messages         → send a (sanitised) text clarification
POST   /chats/{cid}/offer            → propose / counter a price
POST   /chats/{cid}/accept           → accept the latest offer → auto-booking
POST   /chats/{cid}/decline          → decline (thread stays open)
PATCH  /chats/{cid}/read             → mark incoming messages as read
"""

from __future__ import annotations

from datetime import datetime, timezone
from typing import Optional

import structlog
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import and_, func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.middleware.auth_middleware import get_current_active_user
from app.models.chat import (
    Conversation,
    ConversationStatus,
    Message,
    MessageKind,
)
from app.models.property import Category, Property
from app.models.user import User
from app.schemas.chat import (
    ConversationAccepted,
    ConversationCreate,
    ConversationOut,
    MessageCreate,
    MessageOut,
    OfferBody,
    PaginatedMessages,
    PropertyBrief,
)
from app.schemas.user import UserBrief
from app.services.chat_sanitizer import sanitize_chat_text
from app.services.push_service import push_to_user

#: Only these property categories expose the "fissal" negotiation chat.
_CHAT_ELIGIBLE_CATEGORIES = {Category.chalet, Category.boat}

logger = structlog.get_logger(__name__)
router = APIRouter(prefix="/chats", tags=["Chat"])


# ── helpers ──────────────────────────────────────────────
def _is_participant(conv: Conversation, user: User) -> bool:
    return user.id in (conv.guest_id, conv.owner_id)


def _first_image(prop: Optional[Property]) -> Optional[str]:
    if prop and prop.images:
        return prop.images[0]
    return None


def _serialize(conv: Conversation, viewer: User) -> ConversationOut:
    unread = (
        conv.guest_unread_count if viewer.id == conv.guest_id
        else conv.owner_unread_count
    )
    return ConversationOut(
        id=conv.id,
        guest=UserBrief.model_validate(conv.guest),
        owner=UserBrief.model_validate(conv.owner),
        property=(
            PropertyBrief(
                id=conv.property.id,
                name=conv.property.name,
                first_image=_first_image(conv.property),
            )
            if conv.property
            else None
        ),
        check_in=conv.check_in,
        check_out=conv.check_out,
        guests=conv.guests,
        status=conv.status,
        latest_offer_amount=conv.latest_offer_amount,
        latest_offer_by=conv.latest_offer_by,  # type: ignore[arg-type]
        booking_id=conv.booking_id,
        last_message_at=conv.last_message_at,
        last_message_preview=conv.last_message_preview,
        unread_count=unread,
        created_at=conv.created_at,
        updated_at=conv.updated_at,
    )


async def _get_conv_or_404(cid: int, user: User, db: AsyncSession) -> Conversation:
    conv = await db.get(Conversation, cid)
    if conv is None:
        raise HTTPException(status_code=404, detail="Conversation not found")
    if not _is_participant(conv, user):
        raise HTTPException(status_code=403, detail="Not a participant")
    return conv


# ── list conversations ───────────────────────────────────
@router.get("", response_model=list[ConversationOut])
async def list_conversations(
    user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db),
):
    stmt = (
        select(Conversation)
        .where(or_(Conversation.guest_id == user.id, Conversation.owner_id == user.id))
        .order_by(Conversation.last_message_at.desc().nullslast(), Conversation.updated_at.desc())
    )
    rows = (await db.execute(stmt)).scalars().all()
    return [_serialize(c, user) for c in rows]


# ── start / get conversation ─────────────────────────────
@router.post(
    "", response_model=ConversationOut, status_code=status.HTTP_201_CREATED,
)
async def create_conversation(
    body: ConversationCreate,
    user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db),
):
    prop = await db.get(Property, body.property_id)
    if prop is None:
        raise HTTPException(status_code=404, detail="Property not found")
    if prop.owner_id == user.id:
        raise HTTPException(
            status_code=400,
            detail="Cannot start a chat with yourself about your own property",
        )
    # ── Category gate: chat is only for chalets + boats (Wave 23) ──
    if prop.category not in _CHAT_ELIGIBLE_CATEGORIES:
        raise HTTPException(
            status_code=409,
            detail=(
                "التفاوض على السعر متاح فقط للشاليهات والمراكب / "
                "Chat-based pricing is only available for chalets and boats"
            ),
        )
    # ── Owner must have confirmed their phone so the guest can ──
    # ── reach them once the booking is confirmed. ──────────────
    if not prop.owner.phone_verified:
        raise HTTPException(
            status_code=409,
            detail=(
                "يجب على المالك توثيق رقم الموبايل قبل استقبال رسائل / "
                "Owner phone not verified yet"
            ),
        )

    # ── look up existing conversation for the same trip window ──
    existing = (
        await db.execute(
            select(Conversation).where(
                Conversation.guest_id == user.id,
                Conversation.owner_id == prop.owner_id,
                Conversation.property_id == prop.id,
            )
        )
    ).scalar_one_or_none()
    if existing is not None:
        # Refresh the trip intent so the inbox header always shows the
        # window the guest cares about right now.  If an older thread
        # was previously ``accepted``/``declined``, we keep it as-is —
        # the guest must contact support rather than silently reuse a
        # finalised negotiation.
        if existing.status == ConversationStatus.open:
            existing.check_in = body.check_in
            existing.check_out = body.check_out
            existing.guests = body.guests
            await db.flush()
            await db.refresh(existing)
        return _serialize(existing, user)

    conv = Conversation(
        guest_id=user.id,
        owner_id=prop.owner_id,
        property_id=prop.id,
        check_in=body.check_in,
        check_out=body.check_out,
        guests=body.guests,
        status=ConversationStatus.open,
    )
    db.add(conv)
    await db.flush()
    await db.refresh(conv)
    logger.info(
        "chat_conversation_created",
        conv_id=conv.id, guest=user.id, owner=prop.owner_id,
        check_in=str(body.check_in), check_out=str(body.check_out),
        guests=body.guests,
    )
    return _serialize(conv, user)


# ── single conversation ──────────────────────────────────
@router.get("/{cid}", response_model=ConversationOut)
async def get_conversation(
    cid: int,
    user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db),
):
    conv = await _get_conv_or_404(cid, user, db)
    return _serialize(conv, user)


# ── paginated message history ────────────────────────────
@router.get("/{cid}/messages", response_model=PaginatedMessages)
async def list_messages(
    cid: int,
    before: Optional[datetime] = Query(None, description="Return messages strictly older than this timestamp"),
    limit: int = Query(50, ge=1, le=100),
    user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db),
):
    conv = await _get_conv_or_404(cid, user, db)
    stmt = (
        select(Message)
        .where(Message.conversation_id == conv.id)
        .order_by(Message.created_at.desc())
        .limit(limit + 1)
    )
    if before:
        stmt = stmt.where(Message.created_at < before)

    rows = (await db.execute(stmt)).scalars().all()
    has_more = len(rows) > limit
    rows = rows[:limit]
    # reverse so the client gets oldest→newest in chronological order
    rows = list(reversed(rows))
    return PaginatedMessages(
        items=[MessageOut.model_validate(m) for m in rows],
        has_more=has_more,
    )


# ── send a message (text clarification — auto-sanitised) ────────
@router.post(
    "/{cid}/messages",
    response_model=MessageOut,
    status_code=status.HTTP_201_CREATED,
)
async def send_message(
    cid: int,
    body: MessageCreate,
    user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db),
):
    conv = await _get_conv_or_404(cid, user, db)
    if conv.status != ConversationStatus.open:
        raise HTTPException(
            status_code=409,
            detail="تم إغلاق المحادثة / Conversation is closed",
        )

    # Redact phone numbers / emails before persisting so raw contact
    # info never reaches the other side before a confirmed booking.
    clean_body = sanitize_chat_text(body.body.strip())
    msg = Message(
        conversation_id=conv.id,
        sender_id=user.id,
        kind=MessageKind.text,
        body=clean_body,
    )
    db.add(msg)

    now = datetime.now(timezone.utc)
    conv.last_message_at = now
    conv.last_message_preview = clean_body[:200]

    # Bump the *other* participant's unread counter.
    if user.id == conv.guest_id:
        conv.owner_unread_count = (conv.owner_unread_count or 0) + 1
    else:
        conv.guest_unread_count = (conv.guest_unread_count or 0) + 1

    await db.flush()
    await db.refresh(msg)

    # Push-notify the recipient so they see the message even when the
    # app is backgrounded.  In-app inbox entries aren't needed for
    # chat messages – the conversations list already shows them.
    recipient_id = conv.owner_id if user.id == conv.guest_id else conv.guest_id
    snippet = msg.body[:120]
    try:
        await push_to_user(
            db, recipient_id,
            title=user.name or "رسالة جديدة",
            body=snippet,
            data={
                "type": "chat_message",
                "conversation_id": conv.id,
                "message_id": msg.id,
            },
        )
    except Exception as exc:
        logger.warning("chat_push_error", error=str(exc))

    logger.info("chat_message_sent", conv_id=conv.id, sender=user.id, len=len(msg.body))
    return MessageOut.model_validate(msg)


# ── mark as read ─────────────────────────────────────────
@router.patch("/{cid}/read", response_model=ConversationOut)
async def mark_read(
    cid: int,
    user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db),
):
    conv = await _get_conv_or_404(cid, user, db)

    # Mark the *other* participant's messages as read by stamping read_at.
    await db.execute(
        Message.__table__.update()
        .where(
            and_(
                Message.conversation_id == conv.id,
                Message.sender_id != user.id,
                Message.read_at.is_(None),
            )
        )
        .values(read_at=func.now())
    )

    if user.id == conv.guest_id:
        conv.guest_unread_count = 0
    else:
        conv.owner_unread_count = 0
    await db.flush()
    await db.refresh(conv)
    return _serialize(conv, user)


# ══════════════════════════════════════════════════════════════
#  Price negotiation (Wave 23)
# ══════════════════════════════════════════════════════════════

def _role_of(conv: Conversation, user: User) -> str:
    return "guest" if user.id == conv.guest_id else "owner"


def _require_open(conv: Conversation) -> None:
    if conv.status != ConversationStatus.open:
        raise HTTPException(
            status_code=409,
            detail="تم إغلاق المحادثة / Conversation is closed",
        )


async def _bump_unread(conv: Conversation, sender_id: int) -> None:
    if sender_id == conv.guest_id:
        conv.owner_unread_count = (conv.owner_unread_count or 0) + 1
    else:
        conv.guest_unread_count = (conv.guest_unread_count or 0) + 1


async def _notify_counterpart(
    db: AsyncSession,
    conv: Conversation, sender: User,
    title: str, body: str, data: dict,
) -> None:
    recipient_id = (
        conv.owner_id if sender.id == conv.guest_id else conv.guest_id
    )
    try:
        await push_to_user(db, recipient_id, title=title, body=body, data=data)
    except Exception as exc:  # pragma: no cover - best-effort
        logger.warning("chat_push_error", error=str(exc))


# ── propose / counter a price ────────────────────────────
@router.post(
    "/{cid}/offer",
    response_model=MessageOut,
    status_code=status.HTTP_201_CREATED,
)
async def post_offer(
    cid: int,
    body: OfferBody,
    user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db),
):
    conv = await _get_conv_or_404(cid, user, db)
    _require_open(conv)

    role = _role_of(conv, user)
    amount = round(body.amount, 2)

    preview = (
        f"عرض {role_label_ar(role)}: {int(amount)} ج.م"
        if amount.is_integer() else
        f"عرض {role_label_ar(role)}: {amount:.2f} ج.م"
    )

    msg = Message(
        conversation_id=conv.id,
        sender_id=user.id,
        kind=MessageKind.offer,
        body=preview,
        offer_amount=amount,
    )
    db.add(msg)

    now = datetime.now(timezone.utc)
    conv.last_message_at = now
    conv.last_message_preview = preview[:200]
    conv.latest_offer_amount = amount
    conv.latest_offer_by = role
    await _bump_unread(conv, user.id)

    await db.flush()
    await db.refresh(msg)

    await _notify_counterpart(
        db, conv, user,
        title="عرض سعر جديد",
        body=preview,
        data={
            "type": "chat_offer",
            "conversation_id": conv.id,
            "message_id": msg.id,
            "amount": amount,
        },
    )
    logger.info(
        "chat_offer_posted",
        conv_id=conv.id, sender=user.id, role=role, amount=amount,
    )
    return MessageOut.model_validate(msg)


def role_label_ar(role: str) -> str:
    return "المالك" if role == "owner" else "الضيف"


# ── decline the latest offer (thread stays open) ──────────
@router.post(
    "/{cid}/decline",
    response_model=MessageOut,
    status_code=status.HTTP_201_CREATED,
)
async def post_decline(
    cid: int,
    user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db),
):
    conv = await _get_conv_or_404(cid, user, db)
    _require_open(conv)
    if conv.latest_offer_amount is None:
        raise HTTPException(
            status_code=400,
            detail="لا يوجد عرض لرفضه / No offer to decline",
        )
    # You can't decline your own offer.
    if conv.latest_offer_by == _role_of(conv, user):
        raise HTTPException(
            status_code=400,
            detail="لا يمكن رفض عرضك / You cannot decline your own offer",
        )

    msg = Message(
        conversation_id=conv.id,
        sender_id=user.id,
        kind=MessageKind.decline,
        body="تم رفض العرض — في انتظار عرض جديد",
    )
    db.add(msg)
    conv.last_message_at = datetime.now(timezone.utc)
    conv.last_message_preview = msg.body
    # Clear the latest offer so neither side can accept it.
    conv.latest_offer_amount = None
    conv.latest_offer_by = None
    await _bump_unread(conv, user.id)
    await db.flush()
    await db.refresh(msg)
    return MessageOut.model_validate(msg)


# ── accept the counter-party's latest offer → auto-booking ──
@router.post(
    "/{cid}/accept",
    response_model=ConversationAccepted,
    status_code=status.HTTP_201_CREATED,
)
async def post_accept(
    cid: int,
    user: User = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db),
):
    # Imported here to avoid a circular import on startup.
    from app.routers.bookings import _calc_price, _generate_code
    from app.models.booking import Booking, BookingStatus, DepositStatus

    conv = await _get_conv_or_404(cid, user, db)
    _require_open(conv)

    if conv.latest_offer_amount is None:
        raise HTTPException(
            status_code=400,
            detail="لا يوجد عرض للقبول / No offer to accept",
        )
    my_role = _role_of(conv, user)
    if conv.latest_offer_by == my_role:
        raise HTTPException(
            status_code=400,
            detail="لا يمكن قبول عرضك / You cannot accept your own offer",
        )
    if conv.check_in is None or conv.check_out is None or conv.guests is None:
        raise HTTPException(
            status_code=400,
            detail="المحادثة تفتقر لتفاصيل الحجز / Conversation missing trip info",
        )

    prop = await db.get(Property, conv.property_id)
    if prop is None or not prop.is_available:
        raise HTTPException(
            status_code=400,
            detail="العقار غير متاح / Property not available",
        )

    # Compute price using the agreed amount as the per-night rate,
    # while preserving all of the property's fee rules (cleaning
    # fee / utility fees for chalets, etc.).  This mutates the
    # Property instance in memory but we never flush it back.
    original_rate = prop.price_per_night
    original_weekend = prop.weekend_price
    prop.price_per_night = float(conv.latest_offer_amount)
    prop.weekend_price = None  # same agreed rate applies to weekends
    try:
        price = _calc_price(prop, conv.check_in, conv.check_out)
    finally:
        prop.price_per_night = original_rate
        prop.weekend_price = original_weekend

    code = await _generate_code(db)
    booking = Booking(
        booking_code=code,
        property_id=prop.id,
        guest_id=conv.guest_id,
        owner_id=conv.owner_id,
        check_in=conv.check_in,
        check_out=conv.check_out,
        guests_count=conv.guests,
        electricity_fee=price.electricity_fee,
        water_fee=price.water_fee,
        security_deposit=price.security_deposit,
        deposit_status=(
            DepositStatus.held if price.security_deposit > 0
            else DepositStatus.refunded
        ),
        total_price=price.total_price,
        platform_fee=price.platform_fee,
        owner_payout=price.owner_payout,
        status=BookingStatus.pending,
    )
    db.add(booking)
    await db.flush()
    await db.refresh(booking)

    # Seal the conversation.
    conv.status = ConversationStatus.accepted
    conv.booking_id = booking.id
    now = datetime.now(timezone.utc)
    conv.last_message_at = now
    conv.last_message_preview = (
        f"تم الاتفاق — حجز {booking.booking_code}"
    )

    accept_msg = Message(
        conversation_id=conv.id,
        sender_id=user.id,
        kind=MessageKind.accept,
        body=(
            f"تم قبول العرض {int(conv.latest_offer_amount or 0)} ج.م — "
            f"حجز {booking.booking_code}"
        ),
        offer_amount=conv.latest_offer_amount,
        booking_id=booking.id,
    )
    db.add(accept_msg)
    await _bump_unread(conv, user.id)
    await db.flush()

    await _notify_counterpart(
        db, conv, user,
        title="تم قبول العرض",
        body=f"تم إنشاء حجز {booking.booking_code}",
        data={
            "type": "chat_accept",
            "conversation_id": conv.id,
            "booking_id": booking.id,
        },
    )

    logger.info(
        "chat_offer_accepted",
        conv_id=conv.id,
        booking_id=booking.id,
        acceptor=user.id,
        amount=float(conv.latest_offer_amount or 0),
        total=price.total_price,
    )
    await db.refresh(conv)
    return ConversationAccepted(
        conversation=_serialize(conv, user),
        booking_id=booking.id,
        booking_code=booking.booking_code,
        total_price=price.total_price,
    )
