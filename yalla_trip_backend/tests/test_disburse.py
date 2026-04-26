"""Wave 26 — disbursement gateway, webhook, admin endpoint and
reconciliation scheduler tests.

The mock gateway is the system under test: every code path the
production Kashier integration will hit is exercised here, with
the network swap-out being the only delta in prod.
"""

from __future__ import annotations

from datetime import date, datetime, timedelta, timezone

import pytest
from httpx import AsyncClient

from app.models.payout import (
    BankAccountType,
    DisburseStatus,
    HostBankAccount,
    Payout,
    PayoutStatus,
)
from app.services.disburse import MockDisburseGateway
from tests.conftest import TestSession


# ══════════════════════════════════════════════════════════════
#  Helpers
# ══════════════════════════════════════════════════════════════
async def _seed_payout(
    *,
    owner_id: int = 2,
    bank: bool = True,
    amount: float = 1000.0,
) -> int:
    """Insert a host bank account + a pending Payout directly.

    Skips the regular booking → batch flow because we're testing
    the disburse leg in isolation; that flow has its own coverage
    in :pyfile:`test_payouts.py`.
    """
    async with TestSession() as s:
        bank_id: int | None = None
        if bank:
            account = HostBankAccount(
                host_id=owner_id,
                type=BankAccountType.iban,
                account_name="Test Owner",
                bank_name="CIB",
                iban="EG380019000500000000263180123",
                is_default=True,
                verified=True,
            )
            s.add(account)
            await s.flush()
            bank_id = account.id

        today = date.today()
        payout = Payout(
            host_id=owner_id,
            bank_account_id=bank_id,
            total_amount=amount,
            cycle_start=today - timedelta(days=7),
            cycle_end=today,
            status=PayoutStatus.pending,
        )
        s.add(payout)
        await s.commit()
        return payout.id


async def _refresh_payout(payout_id: int) -> Payout:
    async with TestSession() as s:
        row = await s.get(Payout, payout_id)
        assert row is not None
        # Detach so callers can safely access attributes after the
        # session closes — we never re-write through this handle.
        s.expunge(row)
        return row


# ══════════════════════════════════════════════════════════════
#  Admin → POST /payouts/admin/{id}/disburse
# ══════════════════════════════════════════════════════════════
@pytest.mark.asyncio
async def test_admin_disburse_initiates_and_persists_ref(
    admin_client: AsyncClient,
):
    pid = await _seed_payout()
    resp = await admin_client.post(f"/payouts/admin/{pid}/disburse")
    assert resp.status_code == 200, resp.text

    body = resp.json()
    assert body["disburse_status"] == "initiated"
    assert body["disburse_provider"] == "mock"
    assert body["disburse_ref"], "expected a non-empty provider ref"

    # DB row mirrors the response — guards against a router that
    # returns a synthetic value without committing.
    row = await _refresh_payout(pid)
    assert row.disburse_status == DisburseStatus.initiated
    assert row.disburse_ref == body["disburse_ref"]
    assert row.disburse_provider == "mock"
    # Payload snapshot captures both the request and response so
    # ops can replay a missing webhook.
    assert "request" in (row.disburse_payload or {})
    assert "response" in (row.disburse_payload or {})


@pytest.mark.asyncio
async def test_disburse_rejects_already_initiated(admin_client: AsyncClient):
    """Double-firing the gateway would burn money — must be 400."""
    pid = await _seed_payout()
    first = await admin_client.post(f"/payouts/admin/{pid}/disburse")
    assert first.status_code == 200

    second = await admin_client.post(f"/payouts/admin/{pid}/disburse")
    assert second.status_code == 400
    assert "initiated" in second.json()["detail"].lower()


@pytest.mark.asyncio
async def test_disburse_rejects_payout_without_bank_account(
    admin_client: AsyncClient,
):
    pid = await _seed_payout(bank=False)
    resp = await admin_client.post(f"/payouts/admin/{pid}/disburse")
    assert resp.status_code == 400
    assert "bank" in resp.json()["detail"].lower()


@pytest.mark.asyncio
async def test_disburse_404_for_missing_payout(admin_client: AsyncClient):
    resp = await admin_client.post("/payouts/admin/99999/disburse")
    assert resp.status_code == 404


@pytest.mark.asyncio
async def test_non_admin_cannot_disburse(guest_client: AsyncClient):
    pid = await _seed_payout()
    resp = await guest_client.post(f"/payouts/admin/{pid}/disburse")
    assert resp.status_code == 403


# ══════════════════════════════════════════════════════════════
#  Webhook → POST /payouts/disburse/webhook
# ══════════════════════════════════════════════════════════════
@pytest.mark.asyncio
async def test_webhook_success_promotes_payout_to_paid(
    admin_client: AsyncClient, guest_client: AsyncClient,
):
    pid = await _seed_payout()
    init = (await admin_client.post(f"/payouts/admin/{pid}/disburse")).json()
    ref = init["disburse_ref"]

    body, headers = MockDisburseGateway.make_success_webhook(
        payout_id=pid, ref=ref,
    )
    # Webhook is unauthenticated; use any client that can reach the
    # ASGI transport — the guest client is fine.
    resp = await guest_client.post(
        "/payouts/disburse/webhook",
        content=body,
        headers={**headers, "Content-Type": "application/json"},
    )
    assert resp.status_code == 200, resp.text
    assert resp.json() == {"ok": True}

    row = await _refresh_payout(pid)
    assert row.disburse_status == DisburseStatus.succeeded
    assert row.disbursed_at is not None
    # Bookkeeping side auto-advanced — host doesn't have to wait
    # for a separate manual click.
    assert row.status == PayoutStatus.paid
    assert row.reference_number == ref


@pytest.mark.asyncio
async def test_webhook_rejects_tampered_signature(
    admin_client: AsyncClient, guest_client: AsyncClient,
):
    pid = await _seed_payout()
    init = (await admin_client.post(f"/payouts/admin/{pid}/disburse")).json()
    ref = init["disburse_ref"]

    body, headers = MockDisburseGateway.make_success_webhook(
        payout_id=pid, ref=ref,
    )
    headers["X-Mock-Signature"] = "0" * 64  # garbage

    resp = await guest_client.post(
        "/payouts/disburse/webhook",
        content=body,
        headers={**headers, "Content-Type": "application/json"},
    )
    assert resp.status_code == 401

    # State must be untouched — a tampered webhook should never
    # advance the payout.
    row = await _refresh_payout(pid)
    assert row.disburse_status == DisburseStatus.initiated
    assert row.status == PayoutStatus.pending


@pytest.mark.asyncio
async def test_webhook_idempotent_after_terminal_state(
    admin_client: AsyncClient, guest_client: AsyncClient,
):
    """Replaying a success webhook must not double-credit the host."""
    pid = await _seed_payout()
    init = (await admin_client.post(f"/payouts/admin/{pid}/disburse")).json()
    ref = init["disburse_ref"]
    body, headers = MockDisburseGateway.make_success_webhook(
        payout_id=pid, ref=ref,
    )
    h = {**headers, "Content-Type": "application/json"}

    first = await guest_client.post(
        "/payouts/disburse/webhook", content=body, headers=h,
    )
    assert first.status_code == 200
    first_row = await _refresh_payout(pid)
    first_disbursed_at = first_row.disbursed_at

    # Replay — same body, same signature.  Router must short-circuit.
    second = await guest_client.post(
        "/payouts/disburse/webhook", content=body, headers=h,
    )
    assert second.status_code == 200
    assert second.json().get("ignored") == "already_terminal"

    second_row = await _refresh_payout(pid)
    assert second_row.disbursed_at == first_disbursed_at


@pytest.mark.asyncio
async def test_webhook_failure_marks_disburse_failed_but_keeps_payout_pending(
    admin_client: AsyncClient, guest_client: AsyncClient,
):
    pid = await _seed_payout()
    init = (await admin_client.post(f"/payouts/admin/{pid}/disburse")).json()
    ref = init["disburse_ref"]

    body, headers = MockDisburseGateway.make_failure_webhook(
        payout_id=pid, ref=ref, reason="IBAN rejected",
    )
    resp = await guest_client.post(
        "/payouts/disburse/webhook",
        content=body,
        headers={**headers, "Content-Type": "application/json"},
    )
    assert resp.status_code == 200

    row = await _refresh_payout(pid)
    assert row.disburse_status == DisburseStatus.failed
    # The bookkeeping side stays ``pending`` so the admin can either
    # retry (after fixing the IBAN) or manually mark-failed.
    assert row.status == PayoutStatus.pending
    assert row.disbursed_at is None


@pytest.mark.asyncio
async def test_webhook_for_unknown_payout_returns_200_ignored(
    guest_client: AsyncClient,
):
    """Unknown payout ⇒ 200 + ignored so the gateway stops retrying."""
    body, headers = MockDisburseGateway.make_success_webhook(
        payout_id=99999, ref="MOCK-DSB-99999-DEADBEEF",
    )
    resp = await guest_client.post(
        "/payouts/disburse/webhook",
        content=body,
        headers={**headers, "Content-Type": "application/json"},
    )
    assert resp.status_code == 200
    assert resp.json().get("ignored") == "unknown_payout"


@pytest.mark.asyncio
async def test_webhook_rejects_ref_mismatch(
    admin_client: AsyncClient, guest_client: AsyncClient,
):
    """A webhook whose provider_ref doesn't match the stored one is
    almost certainly a replay from a different payout — refuse 400."""
    pid = await _seed_payout()
    await admin_client.post(f"/payouts/admin/{pid}/disburse")

    body, headers = MockDisburseGateway.make_success_webhook(
        payout_id=pid, ref="MOCK-DSB-OTHER-PAYOUT-XX",
    )
    resp = await guest_client.post(
        "/payouts/disburse/webhook",
        content=body,
        headers={**headers, "Content-Type": "application/json"},
    )
    assert resp.status_code == 400
    assert "mismatch" in resp.json()["detail"].lower()


# ══════════════════════════════════════════════════════════════
#  Reconciliation scheduler
# ══════════════════════════════════════════════════════════════
@pytest.mark.asyncio
async def test_reconciler_skips_payouts_inside_sla():
    """A freshly-initiated payout must NOT be polled — the gateway is
    still inside its own retry window."""
    from app.services import disburse_reconciler

    pid = await _seed_payout()
    async with TestSession() as s:
        row = await s.get(Payout, pid)
        assert row is not None
        row.disburse_status = DisburseStatus.initiated
        row.disburse_ref = "MOCK-DSB-1-FRESH"
        # ``created_at`` is auto-set by the model; we leave it alone
        # so the row falls *inside* the SLA window.
        await s.commit()

    async with TestSession() as s:
        counters = await disburse_reconciler.sweep_once(s)
    assert counters["checked"] == 0


@pytest.mark.asyncio
async def test_reconciler_polls_stuck_payouts():
    """A payout past the SLA must be checked; the mock gateway returns
    ``processing`` so the row stays unchanged but ``checked`` ticks."""
    from app.services import disburse_reconciler

    pid = await _seed_payout()
    async with TestSession() as s:
        row = await s.get(Payout, pid)
        assert row is not None
        row.disburse_status = DisburseStatus.initiated
        row.disburse_ref = f"MOCK-DSB-{pid}-AGED"
        # Force the row outside the SLA window so the sweeper picks
        # it up.  We can't use SLA - 1 because ``created_at`` is
        # server-default; overwrite it explicitly.
        row.created_at = datetime.now(timezone.utc) - timedelta(days=3)
        await s.commit()

    async with TestSession() as s:
        counters = await disburse_reconciler.sweep_once(s)
    assert counters["checked"] == 1
    # Mock's ``fetch_status`` returns succeeded=False, failed=False
    # (it has no out-of-band store), which the reconciler counts as
    # ``still_processing``.  Terminal counters must stay zero so the
    # sweeper never invents a state the gateway didn't confirm.
    assert counters["succeeded"] == 0
    assert counters["failed"] == 0
    assert counters["still_processing"] == 1

    row = await _refresh_payout(pid)
    # Status untouched — sweeper must never invent terminal state.
    assert row.disburse_status == DisburseStatus.initiated


# ══════════════════════════════════════════════════════════════
#  Amount cross-check (Wave 26.1 hardening)
# ══════════════════════════════════════════════════════════════
@pytest.mark.asyncio
async def test_webhook_rejects_amount_mismatch(
    admin_client: AsyncClient, guest_client: AsyncClient,
):
    """A webhook claiming a different amount than our records must
    NOT mark the payout paid.  Regression test for the missing
    cross-check that would have let a buggy or forged webhook
    silently flip ``disburse_status = succeeded`` while the host
    received a different sum."""
    pid = await _seed_payout(amount=1000.0)
    init = (await admin_client.post(f"/payouts/admin/{pid}/disburse")).json()
    ref = init["disburse_ref"]

    # Webhook claims only 1 EGP arrived even though our record says 1000.
    body, headers = MockDisburseGateway.make_success_webhook(
        payout_id=pid, ref=ref, amount=1.0,
    )
    resp = await guest_client.post(
        "/payouts/disburse/webhook",
        content=body,
        headers={**headers, "Content-Type": "application/json"},
    )
    assert resp.status_code == 200
    assert resp.json().get("ignored") == "amount_mismatch"

    row = await _refresh_payout(pid)
    # The payout must be flipped to *failed*, never succeeded —
    # silently accepting the smaller amount would mean a host gets
    # paid 1 EGP but our DB records the full 1000 as delivered.
    assert row.disburse_status == DisburseStatus.failed
    assert row.status != PayoutStatus.paid
    assert "mismatch" in (row.admin_notes or "").lower()


@pytest.mark.asyncio
async def test_webhook_accepts_matching_amount(
    admin_client: AsyncClient, guest_client: AsyncClient,
):
    """The flip side of the mismatch test — when amounts agree, the
    payout still flows through to ``paid`` as before."""
    pid = await _seed_payout(amount=1000.0)
    init = (await admin_client.post(f"/payouts/admin/{pid}/disburse")).json()
    ref = init["disburse_ref"]

    body, headers = MockDisburseGateway.make_success_webhook(
        payout_id=pid, ref=ref, amount=1000.0,
    )
    resp = await guest_client.post(
        "/payouts/disburse/webhook",
        content=body,
        headers={**headers, "Content-Type": "application/json"},
    )
    assert resp.status_code == 200

    row = await _refresh_payout(pid)
    assert row.disburse_status == DisburseStatus.succeeded
    assert row.status == PayoutStatus.paid
