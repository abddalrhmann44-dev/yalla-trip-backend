"""Wave 25 — deposit & cash-on-arrival calculations.

The hybrid pricing flow (rolled out in Wave 25) lets hosts opt in to
collecting an *online deposit* from the guest and the *remainder in
cash* on arrival.  Centralising the math here keeps the booking
router slim and gives us one obvious place to test edge cases.

Design notes
------------
* The deposit must always cover **at least one nightly rate** so the
  guest has skin in the game and the host receives something tangible
  online — even if the platform commission is tiny.
* The deposit must also cover the **full platform commission** so we
  never need to chase the host for our cut.  For long stays where 10 %
  of the total exceeds one nightly rate, the deposit grows in whole
  nights (1 night → 2 nights → 3 nights, …).
* The deposit is capped at the booking total: a 1-night booking
  shouldn't ask the guest to pre-pay more than the entire stay.
* No-shows let the host keep the deposit minus a single night's
  commission — the platform doesn't double-dip on a stay that never
  happened.
"""

from __future__ import annotations

import math
from dataclasses import dataclass


@dataclass(frozen=True)
class DepositBreakdown:
    """Pricing split for a hybrid deposit + cash-on-arrival booking.

    All amounts are EGP and rounded to two decimals.  The invariant
    ``deposit_amount + remaining_cash_amount == total_price`` always
    holds (within a 1-piastre rounding tolerance).
    """

    # What the guest pays online up-front.
    deposit_amount: float
    # What the guest pays the host in cash on arrival.
    remaining_cash_amount: float
    # Number of nights the deposit covers (= deposit / price_per_night,
    # capped at total nights).  Useful for the receipt UI: "العربون =
    # سعر ليلة واحدة" / "سعر ليلتين".
    deposit_nights: int
    # Platform commission already baked into the deposit.
    platform_fee: float
    # What we wire to the host's wallet once the cash collection is
    # confirmed by both sides (= deposit_amount - platform_fee).
    owner_online_payout: float
    # No-show payout — single-night commission deducted from the
    # deposit if the guest never shows up.
    no_show_owner_payout: float
    no_show_platform_fee: float


def _round(value: float) -> float:
    """Currency-friendly rounding that avoids float drift in receipts."""

    return round(value, 2)


def compute_deposit_breakdown(
    *,
    total_price: float,
    price_per_night: float,
    commission_rate: float,
    cash_on_arrival_enabled: bool,
) -> DepositBreakdown:
    """Compute the deposit / cash split for a single booking.

    Parameters
    ----------
    total_price:
        Full amount the guest owes for the stay *after* promo codes
        and wallet credits have been applied.  This already includes
        nightly rates + cleaning + utilities + refundable deposit.
    price_per_night:
        The property's nightly rate — used as the indivisible unit
        for sizing the deposit so the guest sees "ليلة" / "ليلتين"
        in their receipt rather than an awkward fraction.
    commission_rate:
        Platform fee as a fraction (e.g. ``0.10`` for 10 %).
    cash_on_arrival_enabled:
        When ``False`` the function returns the legacy 100 %-online
        breakdown (deposit = total, remaining = 0).  We still expose
        the same shape so callers don't need to branch.
    """

    if total_price <= 0:
        raise ValueError("total_price must be positive")
    if price_per_night <= 0:
        raise ValueError("price_per_night must be positive")
    if not 0 <= commission_rate < 1:
        raise ValueError("commission_rate must be in [0, 1)")

    total_commission = _round(total_price * commission_rate)
    one_night_commission = _round(price_per_night * commission_rate)

    if not cash_on_arrival_enabled:
        # Legacy flow — guest pre-pays everything online, host
        # receives ``total - commission`` once the holdback window
        # elapses.  We still populate the deposit fields so downstream
        # code (receipts, payouts) doesn't need to special-case this.
        return DepositBreakdown(
            deposit_amount=_round(total_price),
            remaining_cash_amount=0.0,
            deposit_nights=0,  # not meaningful for online-only
            platform_fee=total_commission,
            owner_online_payout=_round(total_price - total_commission),
            no_show_owner_payout=_round(total_price - one_night_commission),
            no_show_platform_fee=one_night_commission,
        )

    # ── Hybrid flow ──────────────────────────────────────────
    # Number of whole nights the deposit must span to cover the
    # commission.  ``ceil`` ensures we never under-collect; ``max(1,
    # …)`` keeps the floor at a single night for short stays where
    # the commission is naturally smaller than one night.
    if price_per_night > 0:
        nights_for_commission = math.ceil(total_commission / price_per_night)
    else:  # defensive — caller already guards this
        nights_for_commission = 1
    deposit_nights = max(1, nights_for_commission)

    deposit_raw = price_per_night * deposit_nights
    # Never ask the guest to pre-pay more than the full stay.  This
    # also collapses 1-night bookings cleanly back to "100 % online".
    deposit_amount = _round(min(deposit_raw, total_price))
    remaining_cash_amount = _round(max(0.0, total_price - deposit_amount))

    # Recompute the deposit_nights value if the cap kicked in so the
    # receipt UI still tells the truth.
    if deposit_amount < deposit_raw:
        deposit_nights = max(1, int(round(deposit_amount / price_per_night)))

    return DepositBreakdown(
        deposit_amount=deposit_amount,
        remaining_cash_amount=remaining_cash_amount,
        deposit_nights=deposit_nights,
        platform_fee=total_commission,
        owner_online_payout=_round(deposit_amount - total_commission),
        no_show_owner_payout=_round(deposit_amount - one_night_commission),
        no_show_platform_fee=one_night_commission,
    )
