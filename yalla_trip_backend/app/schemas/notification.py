"""Notification Pydantic schemas."""

from __future__ import annotations

from datetime import datetime
from typing import Optional

from pydantic import BaseModel

from app.models.notification import NotificationType


class NotificationOut(BaseModel):
    id: int
    title: str
    body: str
    type: NotificationType
    is_read: bool
    created_at: datetime

    model_config = {"from_attributes": True}


class NotificationCreate(BaseModel):
    """Admin / system creates a notification for a user."""
    user_id: int
    title: str
    body: str
    type: NotificationType = NotificationType.system
