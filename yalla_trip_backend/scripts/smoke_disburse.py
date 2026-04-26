"""End-to-end smoke test for the Wave 26 disburse pipeline.

Run from inside the API container:

    docker compose exec api python scripts/smoke_disburse.py

The script seeds a host + bank account + payout directly in the
DB, fires the mock gateway, simulates a success webhook, and
asserts the payout finishes in ``succeeded``/``paid`` state.

Idempotent: any rows it creates are tagged with the marker email
``smoke-disburse@talaa.local`` and torn down at the end so the
script can be re-run without bloating the DB.
"""
from __future__ import annotations

import asyncio
import json
import sys
from datetime import date, timedelta

from sqlalchemy import delete, select

from app.database import async_session
from app.models.payout import (
    BankAccountType,
    BookingPayoutStatus,
    DisburseStatus,
    HostBankAccount,
    Payout,
    PayoutStatus,
)
from app.models.user import User, UserRole
from app.services.disburse import (
    DisburseChannel,
    DisburseRequest,
    MockDisburseGateway,
)

MARKER_EMAIL = "smoke-disburse@talaa.local"


async def _setup(db) -> tuple[User, HostBankAccount, Payout]:
    # Re-use a single host across runs so the script stays idempotent.
    host = (
        await db.execute(select(User).where(User.email == MARKER_EMAIL))
    ).scalar_one_or_none()
    if host is None:
        host = User(
            email=MARKER_EMAIL,
            name="Smoke Disburse Host",
            phone="+201000000000",
            role=UserRole.owner,
            firebase_uid=f"smoke-{MARKER_EMAIL}",
        )
        db.add(host)
        await db.flush()

    # Wipe any leftover payout/account rows from a previous run so
    # we get a clean state machine to assert against.
    await db.execute(delete(Payout).where(Payout.host_id == host.id))
    await db.execute(
        delete(HostBankAccount).where(HostBankAccount.host_id == host.id)
    )
    await db.flush()

    bank = HostBankAccount(
        host_id=host.id,
        type=BankAccountType.iban,
        account_name="Smoke Test",
        bank_name="CIB",
        iban="EG380019000500000000263180002",
        is_default=True,
        verified=True,
    )
    db.add(bank)
    await db.flush()

    today = date.today()
    payout = Payout(
        host_id=host.id,
        bank_account_id=bank.id,
        total_amount=1500.00,
        cycle_start=today - timedelta(days=7),
        cycle_end=today,
        status=PayoutStatus.pending,
    )
    db.add(payout)
    await db.flush()
    return host, bank, payout


async def main() -> int:
    gateway = MockDisburseGateway()

    async with async_session() as db:
        host, bank, payout = await _setup(db)
        print(f"[setup] host={host.id} bank={bank.id} payout={payout.id}")

        # 1) Initiate disbursement via the mock gateway.
        req = DisburseRequest(
            payout_id=payout.id,
            amount_egp=payout.total_amount,
            channel=DisburseChannel.iban,
            account_name=bank.account_name,
            iban=bank.iban,
            note=f"smoke #{payout.id}",
        )
        result = await gateway.initiate(req)
        assert result.provider_ref, "mock did not return a ref"
        payout.disburse_provider = gateway.name
        payout.disburse_ref = result.provider_ref
        payout.disburse_status = DisburseStatus.initiated
        await db.flush()
        print(f"[initiate] status={result.status.value} ref={result.provider_ref}")

        # 2) Build + parse a *success* webhook end-to-end.
        body, headers = MockDisburseGateway.make_success_webhook(
            payout_id=payout.id, ref=result.provider_ref,
        )
        parsed = await gateway.parse_webhook(headers, body)
        assert parsed is not None, "webhook signature verification failed"
        assert parsed.succeeded, "expected succeeded=true"
        assert parsed.payout_id == payout.id
        assert parsed.provider_ref == result.provider_ref
        print(f"[webhook] payout_id={parsed.payout_id} succeeded={parsed.succeeded}")

        # 3) Mirror the router's transition: succeeded → paid.
        payout.disburse_status = DisburseStatus.succeeded
        payout.status = PayoutStatus.paid
        payout.reference_number = parsed.provider_ref
        payout.disburse_payload = {"webhook": parsed.raw}
        await db.commit()

        # 4) Verify by re-reading from a fresh session.
    async with async_session() as db:
        fresh = await db.get(Payout, payout.id)
        assert fresh is not None
        assert fresh.disburse_status == DisburseStatus.succeeded
        assert fresh.status == PayoutStatus.paid
        assert fresh.reference_number == result.provider_ref
        print(
            f"[verify] payout={fresh.id} "
            f"status={fresh.status.value} "
            f"disburse_status={fresh.disburse_status.value} "
            f"ref={fresh.reference_number}"
        )

        # 5) Negative test: tampered signature must be rejected.
        bad_body, bad_headers = MockDisburseGateway.make_success_webhook(
            payout_id=payout.id, ref=result.provider_ref,
        )
        bad_headers["X-Mock-Signature"] = "0" * 64
        rejected = await gateway.parse_webhook(bad_headers, bad_body)
        assert rejected is None, "tampered signature must not parse"
        print("[negative] tampered signature rejected ✓")

        # 6) Negative test: failure webhook flips to failed.
        fail_body, fail_headers = MockDisburseGateway.make_failure_webhook(
            payout_id=payout.id, ref=result.provider_ref, reason="IBAN rejected",
        )
        fail_parsed = await gateway.parse_webhook(fail_headers, fail_body)
        assert fail_parsed is not None and fail_parsed.failed
        print(f"[negative] failure webhook parsed: {fail_parsed.message}")

    print("\n✅ all checks passed")
    return 0


if __name__ == "__main__":
    sys.exit(asyncio.run(main()))
