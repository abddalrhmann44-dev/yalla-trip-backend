"""Admin audit log.

Every mutating action performed by a staff account (admin / moderator)
gets one row here so we can answer "who did what, when, and from
where" for security and legal compliance.

Design choices:

* ``actor_id`` is nullable – if the admin account is later deleted we
  still want to preserve the log; ``ON DELETE SET NULL`` enforces it.
* ``target_type`` + ``target_id`` are a polymorphic pointer rather
  than dedicated FKs – the set of target kinds grows over time and a
  real FK would need a schema change each time.
* ``before`` / ``after`` are JSONB dicts holding whatever fields the
  action changed.  Never log secrets (tokens, passwords) – the
  helper in :mod:`app.services.audit_service` strips them.
* The table is insert-only and indexed on ``(created_at)`` and
  ``(actor_id, created_at)`` to keep admin dashboards fast.
"""

from __future__ import annotations

from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, Index, Integer, String, func
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


class AuditLogEntry(Base):
    __tablename__ = "audit_log"
    __table_args__ = (
        Index("ix_audit_log_actor_created", "actor_id", "created_at"),
    )

    id: Mapped[int] = mapped_column(primary_key=True, index=True)

    actor_id: Mapped[int | None] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL"),
        nullable=True, index=True,
    )
    # Snapshots of the actor – keep them around even if the user row
    # is later wiped (legal requirement in some jurisdictions).
    actor_email: Mapped[str | None] = mapped_column(String(200), nullable=True)
    actor_role: Mapped[str | None] = mapped_column(String(32), nullable=True)

    # Free-form dotted action key: ``user.suspend``, ``property.delete``,
    # ``payout.mark_paid``, ``promo.create`` …
    action: Mapped[str] = mapped_column(String(64), nullable=False, index=True)

    # Polymorphic pointer.  ``target_id`` may be null for system-wide
    # actions (e.g. a batch payout run covering many rows).
    target_type: Mapped[str | None] = mapped_column(String(32), nullable=True)
    target_id: Mapped[int | None] = mapped_column(Integer, nullable=True)

    # Optional diff payload.  ``{"before": {...}, "after": {...}}`` is
    # the canonical shape, but small actions may use just ``after``.
    before: Mapped[dict | None] = mapped_column(JSONB, nullable=True)
    after: Mapped[dict | None] = mapped_column(JSONB, nullable=True)

    # Request provenance for forensic review.
    ip_address: Mapped[str | None] = mapped_column(String(64), nullable=True)
    user_agent: Mapped[str | None] = mapped_column(String(500), nullable=True)
    request_id: Mapped[str | None] = mapped_column(String(64), nullable=True)

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(),
        nullable=False, index=True,
    )

    actor = relationship("User", lazy="selectin")

    def __repr__(self) -> str:  # pragma: no cover
        return (
            f"<AuditLogEntry {self.action} "
            f"actor={self.actor_id} target={self.target_type}:{self.target_id}>"
        )
