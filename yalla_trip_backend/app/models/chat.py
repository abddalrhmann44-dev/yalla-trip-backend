"""Chat models – conversations between a guest and a property owner.

Wave-23 re-scope: conversations are no longer generic text threads.  A
conversation is a *price-negotiation* channel scoped to a property *and*
a prospective booking window (check-in / check-out / guests).  Parties
exchange structured offers until one accepts, at which point the
platform auto-creates a booking (see ``app.routers.chat`` for the
orchestration logic).

Text messages are still allowed for short clarifications but are
sanitised server-side to strip phone numbers — full contact details are
only revealed to both parties once the booking is *confirmed*.
"""

from __future__ import annotations

import enum
from datetime import date, datetime

from sqlalchemy import (
    Date,
    DateTime,
    Enum as SAEnum,
    Float,
    ForeignKey,
    Integer,
    String,
    Text,
    UniqueConstraint,
    func,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


class ConversationStatus(str, enum.Enum):
    """Lifecycle of a negotiation thread."""

    open = "open"           # still negotiating
    accepted = "accepted"   # offer accepted → booking created
    declined = "declined"   # one side closed the conversation
    expired = "expired"     # no activity within TTL (reserved)


class MessageKind(str, enum.Enum):
    """Semantic role of a chat message."""

    text = "text"           # plain (sanitised) chat
    offer = "offer"         # price proposal from either side
    accept = "accept"       # accepts the counter-party's latest offer
    decline = "decline"     # declines the latest offer (thread stays open)
    system = "system"       # platform-generated (booking-created, etc.)


class Conversation(Base):
    """A 1-on-1 thread between a guest and an owner about a property."""

    __tablename__ = "conversations"
    __table_args__ = (
        UniqueConstraint(
            "guest_id", "owner_id", "property_id",
            name="uq_conversation_participants",
        ),
    )

    id: Mapped[int] = mapped_column(primary_key=True, index=True)

    guest_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    owner_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    property_id: Mapped[int] = mapped_column(
        ForeignKey("properties.id", ondelete="SET NULL"), nullable=True, index=True
    )

    last_message_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True, index=True
    )
    last_message_preview: Mapped[str | None] = mapped_column(
        String(200), nullable=True
    )

    guest_unread_count: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    owner_unread_count: Mapped[int] = mapped_column(Integer, default=0, nullable=False)

    # ── Booking intent (Wave 23) ─────────────────────────────
    # Nullable for back-compat with legacy open threads, but every new
    # conversation must carry these so both parties are negotiating over
    # the *same* trip context.
    check_in: Mapped[date | None] = mapped_column(Date, nullable=True)
    check_out: Mapped[date | None] = mapped_column(Date, nullable=True)
    guests: Mapped[int | None] = mapped_column(Integer, nullable=True)

    # Negotiation state
    status: Mapped[ConversationStatus] = mapped_column(
        SAEnum(
            ConversationStatus,
            name="conversationstatus",
            values_callable=lambda e: [m.value for m in e],
        ),
        default=ConversationStatus.open,
        server_default=ConversationStatus.open.value,
        nullable=False,
        index=True,
    )
    # Amount (EGP, per-night for chalets / per-hour for boats) of the
    # most recent offer in the thread — fast access for the inbox list.
    latest_offer_amount: Mapped[float | None] = mapped_column(
        Float, nullable=True
    )
    # Role of the user who posted the latest offer: "guest" | "owner"
    # | NULL (no offer yet).
    latest_offer_by: Mapped[str | None] = mapped_column(
        String(8), nullable=True
    )
    # Booking auto-created when both parties accepted an offer (Wave 23).
    booking_id: Mapped[int | None] = mapped_column(
        ForeignKey("bookings.id", ondelete="SET NULL"),
        nullable=True, index=True,
    )

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
        nullable=False,
    )

    guest = relationship("User", foreign_keys=[guest_id], lazy="selectin")
    owner = relationship("User", foreign_keys=[owner_id], lazy="selectin")
    property = relationship("Property", lazy="selectin")

    messages = relationship(
        "Message",
        back_populates="conversation",
        cascade="all, delete-orphan",
        order_by="Message.created_at",
    )

    def __repr__(self) -> str:
        return f"<Conversation id={self.id} guest={self.guest_id} owner={self.owner_id}>"


class Message(Base):
    __tablename__ = "messages"

    id: Mapped[int] = mapped_column(primary_key=True, index=True)

    conversation_id: Mapped[int] = mapped_column(
        ForeignKey("conversations.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    sender_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )

    # ── Kind of message (Wave 23) ────────────────────────────
    kind: Mapped[MessageKind] = mapped_column(
        SAEnum(
            MessageKind,
            name="messagekind",
            values_callable=lambda e: [m.value for m in e],
        ),
        default=MessageKind.text,
        server_default=MessageKind.text.value,
        nullable=False,
        index=True,
    )
    body: Mapped[str] = mapped_column(Text, nullable=False)

    # Offer amount (EGP per night / per hour).  Populated for kind =
    # ``offer`` and mirrored into the parent conversation's
    # ``latest_offer_amount`` for fast inbox rendering.
    offer_amount: Mapped[float | None] = mapped_column(Float, nullable=True)

    # Booking auto-created when this message is an ``accept`` that
    # seals an offer.  NULL otherwise.
    booking_id: Mapped[int | None] = mapped_column(
        ForeignKey("bookings.id", ondelete="SET NULL"),
        nullable=True, index=True,
    )

    # Read timestamp for the *other* participant.  NULL = unread.
    read_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
        index=True,
    )

    conversation = relationship("Conversation", back_populates="messages")
    sender = relationship("User", lazy="selectin")

    def __repr__(self) -> str:
        return f"<Message id={self.id} conv={self.conversation_id} from={self.sender_id}>"
