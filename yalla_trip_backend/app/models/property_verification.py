"""Property ownership / KYC verification.

Hosts upload proof-of-ownership documents (contract, electricity bill,
ID matching the property address, …).  Admins review and either
approve, reject, or request edits.

Approved verifications set :attr:`Property.is_verified` (added as a
derived column via the same migration) so the Flutter client can show
a "verified host" badge.
"""

from __future__ import annotations

import enum
from datetime import datetime

from sqlalchemy import (
    DateTime,
    Enum,
    ForeignKey,
    Integer,
    String,
    Text,
    func,
)
from sqlalchemy.dialects.postgresql import ARRAY
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


class VerificationStatus(str, enum.Enum):
    pending = "pending"       # submitted, awaiting admin review
    approved = "approved"     # admin accepted
    rejected = "rejected"     # admin rejected (host may re-submit)
    needs_edit = "needs_edit" # admin asked for more docs / fixes


class DocumentType(str, enum.Enum):
    ownership_contract = "ownership_contract"
    utility_bill = "utility_bill"
    id_card = "id_card"
    commercial_register = "commercial_register"
    other = "other"


class PropertyVerification(Base):
    """Ownership/KYC submission for one property (one row per submission)."""
    __tablename__ = "property_verifications"

    id: Mapped[int] = mapped_column(primary_key=True, index=True)

    property_id: Mapped[int] = mapped_column(
        ForeignKey("properties.id", ondelete="CASCADE"),
        nullable=False, index=True,
    )
    submitted_by: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL"),
        nullable=True, index=True,
    )
    reviewed_by: Mapped[int | None] = mapped_column(
        ForeignKey("users.id", ondelete="SET NULL"),
        nullable=True, index=True,
    )

    status: Mapped[VerificationStatus] = mapped_column(
        Enum(VerificationStatus),
        default=VerificationStatus.pending,
        server_default="pending",
        nullable=False,
        index=True,
    )

    # Array of S3 URLs, one per uploaded document
    document_urls: Mapped[list[str]] = mapped_column(
        ARRAY(String), nullable=False, server_default="{}",
    )
    primary_document_type: Mapped[DocumentType] = mapped_column(
        Enum(DocumentType), default=DocumentType.ownership_contract,
        nullable=False,
    )

    host_note: Mapped[str | None] = mapped_column(Text, nullable=True)
    admin_note: Mapped[str | None] = mapped_column(Text, nullable=True)

    submitted_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(),
    )
    reviewed_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True,
    )

    # Relationships
    property = relationship("Property", lazy="selectin")
    submitter = relationship(
        "User", foreign_keys=[submitted_by], lazy="selectin",
    )
    reviewer = relationship(
        "User", foreign_keys=[reviewed_by], lazy="selectin",
    )

    def __repr__(self) -> str:
        return (
            f"<PropertyVerification id={self.id} prop={self.property_id} "
            f"status={self.status.value}>"
        )
