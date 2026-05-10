"""Platform-wide configuration overrides.

Stores admin-tunable knobs that override the static defaults in
``app/config.py``.  We use a singleton row pattern (one row, id=1)
because all settings are global; per-tenant settings would warrant a
separate ``user_settings`` model.

Settings flow:
- ``app/config.py`` keeps the *default* values (e.g.
  ``PLATFORM_FEE_PERCENT = 10.0``).  These are baked into the build.
- ``platform_settings`` row 1 stores any *override*.  Whenever a code
  path needs a setting, it should call
  :func:`app.services.platform_settings_service.get_settings` which
  merges the override with the defaults — so deleting a column never
  breaks the system.
"""

from __future__ import annotations

from datetime import datetime

from sqlalchemy import DateTime, Float, Integer, String, Text, func
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base


class PlatformSetting(Base):
    """Singleton row (id=1) holding admin-tunable platform knobs."""
    __tablename__ = "platform_settings"

    id: Mapped[int] = mapped_column(primary_key=True)

    # Commission charged on every paid booking (percent, 0-100).
    platform_fee_percent: Mapped[float] = mapped_column(
        Float, nullable=False, default=10.0, server_default="10.0",
    )
    # Default deposit percentage when an owner does not override it.
    deposit_percent_default: Mapped[float] = mapped_column(
        Float, nullable=False, default=20.0, server_default="20.0",
    )
    # Number of days after check-out before the host's money is
    # released to their payout balance.
    payout_hold_days: Mapped[int] = mapped_column(
        Integer, nullable=False, default=1, server_default="1",
    )
    # Wallet redemption guard — minimum subtotal (EGP) at which the
    # guest is allowed to spend wallet credit on a booking.
    wallet_min_redeem_subtotal: Mapped[float] = mapped_column(
        Float, nullable=False, default=3000.0, server_default="3000.0",
    )
    # Reward (EGP) credited to the *referrer* when an invitee completes
    # signup via the referral code.
    referral_reward_egp: Mapped[float] = mapped_column(
        Float, nullable=False, default=100.0, server_default="100.0",
    )
    # Cap on rewarded referrals per user — prevents abuse loops.
    referral_reward_cap: Mapped[int] = mapped_column(
        Integer, nullable=False, default=3, server_default="3",
    )
    # Optional human-readable note explaining the most recent change
    # (surfaced in the admin audit log).
    last_change_note: Mapped[str | None] = mapped_column(Text, nullable=True)

    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
        nullable=False,
    )
    updated_by_name: Mapped[str | None] = mapped_column(
        String(120), nullable=True,
    )

    def __repr__(self) -> str:
        return (
            f"<PlatformSetting fee={self.platform_fee_percent} "
            f"deposit={self.deposit_percent_default}>"
        )
