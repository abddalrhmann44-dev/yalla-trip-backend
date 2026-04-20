"""Cancellation-policy refund calculator.

Pure-function module – no DB or HTTP side-effects – so the logic is
trivially unit-testable.
"""

from __future__ import annotations

from dataclasses import dataclass
from datetime import date, datetime, timezone

from app.models.property import CancellationPolicy


@dataclass(frozen=True)
class RefundQuote:
    """Result of a cancellation preview.

    Attributes
    ----------
    refundable_percent : int
        0, 50 or 100 – percentage of the customer's total that will
        come back.
    refund_amount : float
        The actual currency amount.
    platform_fee_refunded : bool
        Whether Talaa's commission is also refunded (only for 100 %
        refunds by default).
    reason_en : str
    reason_ar : str
        Human-readable explanation, used in UI confirmation.
    """

    refundable_percent: int
    refund_amount: float
    platform_fee_refunded: bool
    reason_en: str
    reason_ar: str


def _hours_until(target: date, now: datetime) -> float:
    """Return hours between ``now`` (tz-aware) and the start of
    ``target`` day (treated as UTC midnight)."""
    target_dt = datetime.combine(
        target, datetime.min.time(), tzinfo=timezone.utc
    )
    return (target_dt - now).total_seconds() / 3600.0


def quote_refund(
    *,
    policy: CancellationPolicy,
    check_in: date,
    total_price: float,
    now: datetime | None = None,
) -> RefundQuote:
    """Calculate how much the guest gets back when they cancel now.

    The three policies are the standard Airbnb-style tiers:

    * **flexible** – full refund if the guest cancels more than
      24 hours before check-in.
    * **moderate** – full refund if > 5 days; 50 % within 5 days.
    * **strict**   – full refund if > 7 days; 50 % between 7 days and
      24 hours; 0 % within 24 hours.

    After check-in (``hours ≤ 0``) nothing is refunded regardless of
    policy.
    """
    now = now or datetime.now(timezone.utc)
    hours = _hours_until(check_in, now)

    if hours <= 0:
        return RefundQuote(
            refundable_percent=0,
            refund_amount=0.0,
            platform_fee_refunded=False,
            reason_en="Check-in date has passed; no refund is available.",
            reason_ar="موعد الوصول مر بالفعل، لا يوجد استرداد.",
        )

    if policy == CancellationPolicy.flexible:
        percent = 100 if hours >= 24 else 0
        if percent:
            return _full(total_price, reason="≥ 24h before check-in (flexible)")
        return _none(reason_ar="أقل من 24 ساعة على الوصول (سياسة مرنة)")

    if policy == CancellationPolicy.moderate:
        if hours >= 24 * 5:
            return _full(total_price, reason="≥ 5 days before check-in (moderate)")
        if hours >= 24:
            return _half(total_price, reason="< 5 days before check-in (moderate)")
        return _none(reason_ar="أقل من 24 ساعة على الوصول (سياسة متوسطة)")

    # strict
    if hours >= 24 * 7:
        return _full(total_price, reason="≥ 7 days before check-in (strict)")
    if hours >= 24:
        return _half(total_price, reason="1–7 days before check-in (strict)")
    return _none(reason_ar="أقل من 24 ساعة على الوصول (سياسة صارمة)")


def _full(total: float, *, reason: str) -> RefundQuote:
    return RefundQuote(
        refundable_percent=100,
        refund_amount=round(total, 2),
        platform_fee_refunded=True,
        reason_en=f"100% refund – {reason}.",
        reason_ar="استرداد كامل (100%) حسب سياسة الإلغاء.",
    )


def _half(total: float, *, reason: str) -> RefundQuote:
    return RefundQuote(
        refundable_percent=50,
        refund_amount=round(total * 0.5, 2),
        platform_fee_refunded=False,
        reason_en=f"50% refund – {reason}.",
        reason_ar="استرداد جزئي (50%) حسب سياسة الإلغاء.",
    )


def _none(*, reason_ar: str) -> RefundQuote:
    return RefundQuote(
        refundable_percent=0,
        refund_amount=0.0,
        platform_fee_refunded=False,
        reason_en="No refund – cancellation window has closed.",
        reason_ar=f"لا يوجد استرداد — {reason_ar}.",
    )
