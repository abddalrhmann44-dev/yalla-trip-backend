"""Guest / user identity verification (KYC).

Users (mostly guests) upload an ID card image and a selfie; admins
review.  Approving flips :attr:`User.is_verified` so hosts can choose
to only accept verified guests.
"""

from __future__ import annotations

import enum
from datetime import datetime

from sqlalchemy import (
    DateTime,
    Enum,
    ForeignKey,
    String,
    Text,
    func,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


class UserVerificationStatus(str, enum.Enum):
    pending = "pending"
    approved = "approved"
    rejected = "rejected"
    needs_edit = "needs_edit"


class UserIdDocType(str, enum.Enum):
    national_id = "national_id"
    passport = "passport"
    driver_license = "driver_license"


class UserVerification(Base):
    """KYC submission for one user (one row per submission)."""
    __tablename__ = "user_verifications"

    id: Mapped[int] = mapped_column(primary_key=True, index=True)

    user_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False, index=True,
    )
    reviewed_by: Mapped[int | None] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL"),
        nullable=True, index=True,
    )

    status: Mapped[UserVerificationStatus] = mapped_column(
        Enum(UserVerificationStatus),
        default=UserVerificationStatus.pending,
        server_default="pending",
        nullable=False,
        index=True,
    )

    id_doc_type: Mapped[UserIdDocType] = mapped_column(
        Enum(UserIdDocType),
        default=UserIdDocType.national_id,
        server_default="national_id",
        nullable=False,
    )
    id_front_url: Mapped[str] = mapped_column(String(512), nullable=False)
    id_back_url: Mapped[str | None] = mapped_column(String(512), nullable=True)
    selfie_url: Mapped[str] = mapped_column(String(512), nullable=False)

    admin_note: Mapped[str | None] = mapped_column(Text, nullable=True)

    submitted_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(),
    )
    reviewed_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True,
    )

    # Relationships
    user = relationship(
        "User", foreign_keys=[user_id], lazy="selectin",
    )
    reviewer = relationship(
        "User", foreign_keys=[reviewed_by], lazy="selectin",
    )

    def __repr__(self) -> str:
        return (
            f"<UserVerification id={self.id} user={self.user_id} "
            f"status={self.status.value}>"
        )
