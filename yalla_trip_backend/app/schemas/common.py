"""Shared schema helpers: pagination, API envelope, messages."""

from __future__ import annotations

from typing import Any, Generic, List, TypeVar

from pydantic import BaseModel, Field

T = TypeVar("T")


class PaginationParams(BaseModel):
    page: int = Field(1, ge=1, description="Page number")
    limit: int = Field(20, ge=1, le=100, description="Items per page")


class PaginatedResponse(BaseModel, Generic[T]):
    items: List[T]
    total: int
    page: int
    limit: int
    pages: int


class MessageResponse(BaseModel):
    message: str
    message_ar: str


class ErrorResponse(BaseModel):
    detail: str
    detail_ar: str
    code: str | None = None
