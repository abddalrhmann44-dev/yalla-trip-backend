"""Calendar sync DTOs (Wave 13)."""

from __future__ import annotations

from datetime import date, datetime
from typing import Optional

from pydantic import BaseModel, ConfigDict, Field, HttpUrl


class CalendarImportCreate(BaseModel):
    property_id: int
    name: str = Field(..., min_length=1, max_length=100)
    url: HttpUrl


class CalendarImportUpdate(BaseModel):
    name: Optional[str] = Field(None, min_length=1, max_length=100)
    url: Optional[HttpUrl] = None
    is_active: Optional[bool] = None


class CalendarImportOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    property_id: int
    name: str
    url: str
    is_active: bool
    last_synced_at: Optional[datetime] = None
    last_error: Optional[str] = None
    last_event_count: int
    created_at: datetime


class CalendarBlockCreate(BaseModel):
    property_id: int
    start_date: date
    end_date: date
    summary: Optional[str] = Field(None, max_length=500)


class CalendarBlockOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    property_id: int
    import_id: Optional[int] = None
    start_date: date
    end_date: date
    source: str
    summary: Optional[str] = None
    external_uid: Optional[str] = None
    created_at: datetime


class SyncResult(BaseModel):
    imported: int
    removed: int
    last_error: Optional[str] = None
    last_synced_at: datetime


class FeedTokenOut(BaseModel):
    """Response shape for ``POST /calendar/{prop_id}/token``."""
    property_id: int
    token: str
    feed_url: str
