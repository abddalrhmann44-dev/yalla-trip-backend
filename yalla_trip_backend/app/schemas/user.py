"""User Pydantic schemas for request / response validation."""

from __future__ import annotations

from datetime import datetime
from typing import Optional

from pydantic import BaseModel, EmailStr, Field

from app.models.user import UserRole


# ── Request schemas ───────────────────────────────────────
class UserCreate(BaseModel):
    firebase_uid: str
    name: str = Field(..., min_length=2, max_length=120)
    email: Optional[EmailStr] = None
    phone: Optional[str] = Field(None, pattern=r"^\+?[0-9]{10,15}$")
    role: UserRole = UserRole.guest


class UserUpdate(BaseModel):
    name: Optional[str] = Field(None, min_length=2, max_length=120)
    email: Optional[EmailStr] = None
    phone: Optional[str] = Field(None, pattern=r"^\+?[0-9]{10,15}$")
    avatar_url: Optional[str] = None


# ── Response schemas ──────────────────────────────────────
class UserOut(BaseModel):
    id: int
    firebase_uid: str
    name: str
    email: Optional[str] = None
    phone: Optional[str] = None
    role: UserRole
    avatar_url: Optional[str] = None
    is_verified: bool
    is_active: bool
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}


class UserBrief(BaseModel):
    """Minimal user info embedded in other responses."""
    id: int
    name: str
    avatar_url: Optional[str] = None

    model_config = {"from_attributes": True}


# ── Auth schemas ──────────────────────────────────────────
class TokenPayload(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    user: UserOut


class FirebaseTokenRequest(BaseModel):
    firebase_token: str


class RefreshTokenRequest(BaseModel):
    refresh_token: str


class RoleChangeRequest(BaseModel):
    role: UserRole


class FcmTokenRequest(BaseModel):
    fcm_token: str
