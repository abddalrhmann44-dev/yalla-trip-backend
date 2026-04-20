"""Phone-number OTP challenge (Wave 23).

An owner (or any user) proves ownership of a phone number by
verifying a 6-digit code sent via SMS.  A row is created per
``(user_id, phone)`` challenge; we store the *hash* of the code plus
an expiry and an attempts counter to protect against brute force.

Design notes
-------------
- Codes expire after 10 minutes (``OTP_TTL_SECONDS``).
- After 5 failed ``verify`` attempts the row is marked exhausted and
  the user must request a fresh code.
- The raw code is never stored — only its SHA-256 hash in
  ``code_hash`` (``app.services.phone_otp_service`` handles hashing).
- A user may keep at most one *active* row per phone: starting a new
  challenge for the same phone invalidates any previous pending row
  (done in the service layer).
"""

from __future__ import annotations

from datetime import datetime

from sqlalchemy import (
    Boolean,
    DateTime,
    ForeignKey,
    Integer,
    String,
    func,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base

#: Minutes a generated OTP remains valid.
OTP_TTL_SECONDS: int = 10 * 60
#: How many wrong code entries before the row is marked exhausted.
MAX_VERIFY_ATTEMPTS: int = 5


class PhoneOtp(Base):
    __tablename__ = "phone_otps"

    id: Mapped[int] = mapped_column(primary_key=True, index=True)

    user_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    phone: Mapped[str] = mapped_column(String(20), nullable=False, index=True)

    # SHA-256 hex digest of the 6-digit code.  Compared against
    # ``sha256(input).hexdigest()`` during verification.
    code_hash: Mapped[str] = mapped_column(String(64), nullable=False)

    attempts: Mapped[int] = mapped_column(
        Integer, default=0, server_default="0", nullable=False,
    )
    expires_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, index=True,
    )
    used: Mapped[bool] = mapped_column(
        Boolean, default=False, server_default="false", nullable=False,
    )

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False,
    )

    user = relationship("User", lazy="selectin")

    def __repr__(self) -> str:  # pragma: no cover
        return (
            f"<PhoneOtp id={self.id} user={self.user_id} phone={self.phone}"
            f" used={self.used} attempts={self.attempts}>"
        )
