"""Audit-log Pydantic schemas."""

from __future__ import annotations

from datetime import datetime

from pydantic import BaseModel


class AuditLogOut(BaseModel):
    id: int
    actor_id: int | None
    actor_email: str | None
    actor_role: str | None
    action: str
    target_type: str | None
    target_id: int | None
    before: dict | None
    after: dict | None
    ip_address: str | None
    user_agent: str | None
    request_id: str | None
    created_at: datetime

    class Config:
        from_attributes = True
