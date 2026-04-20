"""Promo-code validation + atomic redemption.

We split responsibilities from the router:
  * :func:`validate_code` – stateless check, used by both the
    ``/promo-codes/validate`` preview endpoint and the booking flow.
  * :func:`redeem_for_booking` – runs inside the booking's DB
    transaction, increments ``uses_count`` with an *atomic* compare
    (``uses_count < max_uses``) so two concurrent bookings can't both
    consume the very last slot.
"""

from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timezone

import structlog
from sqlalchemy import and_, func, or_, select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.promo_code import PromoCode, PromoRedemption, PromoType

logger = structlog.get_logger(__name__)


@dataclass
class ValidationResult:
    valid: bool
    code: str
    discount_amount: float
    final_amount: float
    reason: str | None = None
    reason_ar: str | None = None
    promo: PromoCode | None = None


def _compute_discount(promo: PromoCode, amount: float) -> float:
    if promo.type == PromoType.percent:
        raw = amount * (promo.value / 100.0)
        if promo.max_discount is not None:
            raw = min(raw, promo.max_discount)
    else:
        raw = promo.value
    # Never discount more than the booking itself.
    return round(min(raw, amount), 2)


async def _count_redemptions_for_user(
    db: AsyncSession, promo_id: int, user_id: int
) -> int:
    result = await db.execute(
        select(func.count(PromoRedemption.id)).where(
            PromoRedemption.promo_id == promo_id,
            PromoRedemption.user_id == user_id,
        )
    )
    return int(result.scalar() or 0)


async def validate_code(
    db: AsyncSession,
    code: str,
    booking_amount: float,
    user_id: int | None,
) -> ValidationResult:
    """Stateless validation – does **not** increment ``uses_count``.

    Used both by the preview endpoint and as the first check inside
    :func:`redeem_for_booking`.  ``user_id=None`` skips the per-user
    cap check (useful for pre-login previews in a web flow).
    """
    code_norm = code.strip().upper()
    row = await db.execute(select(PromoCode).where(PromoCode.code == code_norm))
    promo = row.scalar_one_or_none()

    if promo is None:
        return ValidationResult(
            valid=False, code=code_norm,
            discount_amount=0.0, final_amount=booking_amount,
            reason="Invalid promo code",
            reason_ar="كود غير صحيح",
        )

    if not promo.is_active:
        return ValidationResult(
            valid=False, code=code_norm,
            discount_amount=0.0, final_amount=booking_amount,
            reason="Promo code is disabled",
            reason_ar="الكود غير مفعل",
            promo=promo,
        )

    now = datetime.now(timezone.utc)
    if promo.valid_from and now < promo.valid_from:
        return ValidationResult(
            valid=False, code=code_norm,
            discount_amount=0.0, final_amount=booking_amount,
            reason="Promo code is not active yet",
            reason_ar="الكود لم يبدأ بعد",
            promo=promo,
        )
    if promo.valid_until and now > promo.valid_until:
        return ValidationResult(
            valid=False, code=code_norm,
            discount_amount=0.0, final_amount=booking_amount,
            reason="Promo code has expired",
            reason_ar="الكود منتهي الصلاحية",
            promo=promo,
        )

    if (
        promo.min_booking_amount is not None
        and booking_amount < promo.min_booking_amount
    ):
        return ValidationResult(
            valid=False, code=code_norm,
            discount_amount=0.0, final_amount=booking_amount,
            reason=(
                f"Minimum booking amount is {promo.min_booking_amount:.0f} EGP"
            ),
            reason_ar=(
                f"الحد الأدنى للحجز {promo.min_booking_amount:.0f} جنيه"
            ),
            promo=promo,
        )

    if promo.max_uses is not None and promo.uses_count >= promo.max_uses:
        return ValidationResult(
            valid=False, code=code_norm,
            discount_amount=0.0, final_amount=booking_amount,
            reason="Promo code usage limit reached",
            reason_ar="الكود استُخدم بالكامل",
            promo=promo,
        )

    if user_id is not None and promo.max_uses_per_user is not None:
        used = await _count_redemptions_for_user(db, promo.id, user_id)
        if used >= promo.max_uses_per_user:
            return ValidationResult(
                valid=False, code=code_norm,
                discount_amount=0.0, final_amount=booking_amount,
                reason="You have already used this code the maximum times",
                reason_ar="لقد استخدمت هذا الكود بالفعل العدد الأقصى",
                promo=promo,
            )

    discount = _compute_discount(promo, booking_amount)
    return ValidationResult(
        valid=True, code=code_norm,
        discount_amount=discount,
        final_amount=round(booking_amount - discount, 2),
        promo=promo,
    )


async def redeem_for_booking(
    db: AsyncSession,
    *,
    code: str,
    booking_id: int,
    user_id: int,
    booking_amount: float,
) -> ValidationResult:
    """Atomically redeem a code against a booking.

    Raises ``ValueError`` with a user-visible reason when the code is
    unusable – the caller should surface the message to the client
    and NOT create the booking row.

    Invariants:
      * Exactly one ``PromoRedemption`` row is inserted.
      * ``PromoCode.uses_count`` is incremented by exactly one, using
        a conditional UPDATE that fails if the limit was reached by
        another concurrent booking between our check and our write.
    """
    res = await validate_code(db, code, booking_amount, user_id)
    if not res.valid:
        raise ValueError(res.reason_ar or res.reason or "Invalid promo code")

    promo = res.promo
    assert promo is not None  # validate_code guarantees this on valid==True

    # Atomic increment – the WHERE clause rejects the update if the
    # code hit its cap after we did the initial check.
    if promo.max_uses is not None:
        stmt = (
            update(PromoCode)
            .where(
                and_(
                    PromoCode.id == promo.id,
                    or_(
                        PromoCode.max_uses.is_(None),
                        PromoCode.uses_count < PromoCode.max_uses,
                    ),
                )
            )
            .values(uses_count=PromoCode.uses_count + 1)
        )
    else:
        stmt = (
            update(PromoCode)
            .where(PromoCode.id == promo.id)
            .values(uses_count=PromoCode.uses_count + 1)
        )

    result = await db.execute(stmt)
    if result.rowcount == 0:
        raise ValueError("الكود استُخدم بالكامل")

    db.add(PromoRedemption(
        promo_id=promo.id,
        user_id=user_id,
        booking_id=booking_id,
        discount_amount=res.discount_amount,
        original_amount=booking_amount,
    ))

    logger.info(
        "promo_redeemed",
        code=promo.code, user_id=user_id, booking_id=booking_id,
        discount=res.discount_amount,
    )
    return res
