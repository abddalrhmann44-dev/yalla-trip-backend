// ═══════════════════════════════════════════════════════════════
//  TALAA — Payout Service
//  Host: bank accounts + history + summary
//  Admin: batch creation + mark-paid/failed + CSV export
// ═══════════════════════════════════════════════════════════════

import '../utils/api_client.dart';

enum BankAccountType { iban, wallet, instapay }

extension BankAccountTypeX on BankAccountType {
  String get code => name;
  String get labelAr {
    switch (this) {
      case BankAccountType.iban:
        return 'حساب بنكي (IBAN)';
      case BankAccountType.wallet:
        return 'محفظة إلكترونية';
      case BankAccountType.instapay:
        return 'إنستا باي';
    }
  }
}

enum PayoutStatus { pending, processing, paid, failed }

extension PayoutStatusX on PayoutStatus {
  String get labelAr {
    switch (this) {
      case PayoutStatus.pending:
        return 'قيد الانتظار';
      case PayoutStatus.processing:
        return 'قيد المعالجة';
      case PayoutStatus.paid:
        return 'تم الدفع';
      case PayoutStatus.failed:
        return 'فشل';
    }
  }
}

/// Wave 26 — automated disbursement (Kashier / mock) state machine.
/// Mirrors `app.models.payout.DisburseStatus` on the backend.
///
/// Names are intentionally `snake_case` so `enum.name` matches the
/// wire format coming from the FastAPI server without a mapping
/// table — keeping JSON deserialisation a one-liner.
// ignore: constant_identifier_names
enum DisburseStatus { not_started, initiated, processing, succeeded, failed }

extension DisburseStatusX on DisburseStatus {
  String get labelAr {
    switch (this) {
      case DisburseStatus.not_started:
        return 'لم يبدأ';
      case DisburseStatus.initiated:
        return 'تم إرسال الطلب';
      case DisburseStatus.processing:
        return 'قيد التحويل';
      case DisburseStatus.succeeded:
        return 'تم التحويل ✅';
      case DisburseStatus.failed:
        return 'فشل التحويل';
    }
  }

  /// Whether the row should display the "received" affirmation in the
  /// host wallet — used for the green checkmark + reference card.
  bool get isTerminalSuccess => this == DisburseStatus.succeeded;
}

// ── Models ────────────────────────────────────────────────
class BankAccount {
  final int id;
  final int hostId;
  final BankAccountType type;
  final String accountName;
  final String? bankName;
  final String? ibanMasked;
  final String? walletPhone;
  final String? instapayAddress;
  final bool isDefault;
  final bool verified;
  final DateTime createdAt;

  BankAccount({
    required this.id,
    required this.hostId,
    required this.type,
    required this.accountName,
    required this.bankName,
    required this.ibanMasked,
    required this.walletPhone,
    required this.instapayAddress,
    required this.isDefault,
    required this.verified,
    required this.createdAt,
  });

  factory BankAccount.fromJson(Map<String, dynamic> j) => BankAccount(
        id: j['id'] as int,
        hostId: j['host_id'] as int,
        type: BankAccountType.values.firstWhere((t) => t.name == j['type']),
        accountName: j['account_name'] as String,
        bankName: j['bank_name'] as String?,
        ibanMasked: j['iban_masked'] as String?,
        walletPhone: j['wallet_phone'] as String?,
        instapayAddress: j['instapay_address'] as String?,
        isDefault: j['is_default'] as bool? ?? false,
        verified: j['verified'] as bool? ?? false,
        createdAt: DateTime.parse(j['created_at'] as String),
      );

  /// Short display line under the account name.
  String get displayDetail {
    switch (type) {
      case BankAccountType.iban:
        return '${bankName ?? ''} · ${ibanMasked ?? ''}';
      case BankAccountType.wallet:
        return '${bankName ?? 'محفظة'} · ${walletPhone ?? ''}';
      case BankAccountType.instapay:
        return instapayAddress ?? '';
    }
  }
}

class PayoutItem {
  final int id;
  final int bookingId;
  final double amount;
  final String? bookingCode;
  PayoutItem({
    required this.id,
    required this.bookingId,
    required this.amount,
    required this.bookingCode,
  });
  factory PayoutItem.fromJson(Map<String, dynamic> j) => PayoutItem(
        id: j['id'] as int,
        bookingId: j['booking_id'] as int,
        amount: (j['amount'] as num).toDouble(),
        bookingCode: j['booking_code'] as String?,
      );
}

class PayoutModel {
  final int id;
  final int hostId;
  final int? bankAccountId;
  final double totalAmount;
  final DateTime cycleStart;
  final DateTime cycleEnd;
  final PayoutStatus status;
  final String? referenceNumber;
  final String? adminNotes;
  final DateTime? processedAt;
  final DateTime createdAt;
  final List<PayoutItem> items;

  // ── Wave 26 — automated disbursement ───────────────────
  /// Gateway slug (`kashier`, `mock`, …) — null for legacy manual rows.
  final String? disburseProvider;
  /// Gateway-side transaction id; the host can quote this to support
  /// or to their bank to chase a missing deposit.
  final String? disburseRef;
  final DisburseStatus disburseStatus;
  final DateTime? disbursedAt;
  /// Optional S3 URL for a PDF / image receipt the host can download
  /// straight from the app — strongest possible proof of payment.
  final String? disburseReceiptUrl;

  PayoutModel({
    required this.id,
    required this.hostId,
    required this.bankAccountId,
    required this.totalAmount,
    required this.cycleStart,
    required this.cycleEnd,
    required this.status,
    required this.referenceNumber,
    required this.adminNotes,
    required this.processedAt,
    required this.createdAt,
    required this.items,
    required this.disburseProvider,
    required this.disburseRef,
    required this.disburseStatus,
    required this.disbursedAt,
    required this.disburseReceiptUrl,
  });

  factory PayoutModel.fromJson(Map<String, dynamic> j) => PayoutModel(
        id: j['id'] as int,
        hostId: j['host_id'] as int,
        bankAccountId: j['bank_account_id'] as int?,
        totalAmount: (j['total_amount'] as num).toDouble(),
        cycleStart: DateTime.parse(j['cycle_start'] as String),
        cycleEnd: DateTime.parse(j['cycle_end'] as String),
        status:
            PayoutStatus.values.firstWhere((t) => t.name == j['status']),
        referenceNumber: j['reference_number'] as String?,
        adminNotes: j['admin_notes'] as String?,
        processedAt: j['processed_at'] != null
            ? DateTime.parse(j['processed_at'] as String)
            : null,
        createdAt: DateTime.parse(j['created_at'] as String),
        items: (j['items'] as List? ?? [])
            .map((e) => PayoutItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        disburseProvider: j['disburse_provider'] as String?,
        disburseRef: j['disburse_ref'] as String?,
        // Default to ``not_started`` for legacy rows where the column
        // is missing or null in the response.
        disburseStatus: DisburseStatus.values.firstWhere(
          (s) => s.name == (j['disburse_status'] ?? 'not_started'),
          orElse: () => DisburseStatus.not_started,
        ),
        disbursedAt: j['disbursed_at'] != null
            ? DateTime.parse(j['disbursed_at'] as String)
            : null,
        disburseReceiptUrl: j['disburse_receipt_url'] as String?,
      );
}

class HostPayoutSummary {
  final double pendingBalance;
  final double queuedBalance;
  final double paidTotal;
  final DateTime? lastPaidAt;
  final int eligibleBookingCount;

  HostPayoutSummary({
    required this.pendingBalance,
    required this.queuedBalance,
    required this.paidTotal,
    required this.lastPaidAt,
    required this.eligibleBookingCount,
  });

  factory HostPayoutSummary.fromJson(Map<String, dynamic> j) =>
      HostPayoutSummary(
        pendingBalance: (j['pending_balance'] as num).toDouble(),
        queuedBalance: (j['queued_balance'] as num).toDouble(),
        paidTotal: (j['paid_total'] as num).toDouble(),
        lastPaidAt: j['last_paid_at'] != null
            ? DateTime.parse(j['last_paid_at'] as String)
            : null,
        eligibleBookingCount: j['eligible_booking_count'] as int,
      );
}

class PayoutService {
  static final _api = ApiClient();

  // ── Bank accounts ────────────────────────────────────────
  static Future<List<BankAccount>> listBankAccounts() async {
    final res = await _api.get('/payouts/bank-accounts');
    return (res as List)
        .map((e) => BankAccount.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<BankAccount> addBankAccount({
    required BankAccountType type,
    required String accountName,
    String? bankName,
    String? iban,
    String? walletPhone,
    String? instapayAddress,
    bool isDefault = false,
  }) async {
    final res = await _api.post('/payouts/bank-accounts', {
      'type': type.code,
      'account_name': accountName,
      'is_default': isDefault,
      if (bankName != null) 'bank_name': bankName,
      if (iban != null) 'iban': iban,
      if (walletPhone != null) 'wallet_phone': walletPhone,
      if (instapayAddress != null) 'instapay_address': instapayAddress,
    });
    return BankAccount.fromJson(res as Map<String, dynamic>);
  }

  static Future<BankAccount> updateBankAccount(
    int id, {
    String? accountName,
    String? bankName,
    bool? isDefault,
  }) async {
    final body = <String, dynamic>{
      if (accountName != null) 'account_name': accountName,
      if (bankName != null) 'bank_name': bankName,
      if (isDefault != null) 'is_default': isDefault,
    };
    final res = await _api.patch('/payouts/bank-accounts/$id', body);
    return BankAccount.fromJson(res as Map<String, dynamic>);
  }

  static Future<void> deleteBankAccount(int id) async {
    await _api.delete('/payouts/bank-accounts/$id');
  }

  // ── Host history ─────────────────────────────────────────
  static Future<HostPayoutSummary> mySummary() async {
    final res = await _api.get('/payouts/me/summary');
    return HostPayoutSummary.fromJson(res as Map<String, dynamic>);
  }

  static Future<List<PayoutModel>> myPayouts({int limit = 50}) async {
    final res = await _api.get('/payouts/me?limit=$limit');
    return (res as List)
        .map((e) => PayoutModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── Admin ────────────────────────────────────────────────
  static Future<List<PayoutModel>> adminList({
    PayoutStatus? status,
    int? hostId,
    int limit = 100,
  }) async {
    final qp = <String, String>{'limit': '$limit'};
    if (status != null) qp['status'] = status.name;
    if (hostId != null) qp['host_id'] = '$hostId';
    final q = qp.entries.map((e) => '${e.key}=${e.value}').join('&');
    final res = await _api.get('/payouts/admin?$q');
    return (res as List)
        .map((e) => PayoutModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<Map<String, dynamic>> adminEligiblePreview({
    required DateTime cycleStart,
    required DateTime cycleEnd,
    int? hostId,
  }) async {
    final qp = <String, String>{
      'cycle_start': cycleStart.toIso8601String().split('T').first,
      'cycle_end': cycleEnd.toIso8601String().split('T').first,
    };
    if (hostId != null) qp['host_id'] = '$hostId';
    final q = qp.entries.map((e) => '${e.key}=${e.value}').join('&');
    final res = await _api.get('/payouts/admin/eligible/preview?$q');
    return res as Map<String, dynamic>;
  }

  static Future<List<PayoutModel>> adminCreateBatch({
    required DateTime cycleStart,
    required DateTime cycleEnd,
    int? hostId,
  }) async {
    final res = await _api.post('/payouts/admin/batch', {
      'cycle_start': cycleStart.toIso8601String().split('T').first,
      'cycle_end': cycleEnd.toIso8601String().split('T').first,
      if (hostId != null) 'host_id': hostId,
    });
    return (res as List)
        .map((e) => PayoutModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<PayoutModel> adminMarkPaid(
    int payoutId, {
    required String referenceNumber,
    String? notes,
  }) async {
    final res = await _api.post('/payouts/admin/$payoutId/mark-paid', {
      'reference_number': referenceNumber,
      if (notes != null && notes.isNotEmpty) 'admin_notes': notes,
    });
    return PayoutModel.fromJson(res as Map<String, dynamic>);
  }

  static Future<PayoutModel> adminMarkFailed(
    int payoutId, {
    required String notes,
  }) async {
    final res = await _api.post('/payouts/admin/$payoutId/mark-failed', {
      'admin_notes': notes,
    });
    return PayoutModel.fromJson(res as Map<String, dynamic>);
  }

  /// Wave 26 — fire the configured disbursement gateway (Kashier in
  /// prod, mock in dev) for a single payout.  Returns the updated row
  /// with `disburseStatus = initiated`; the success state arrives
  /// later via webhook.  Throws on gateway-rejection (HTTP 502) so
  /// the admin can fall back to manual.
  static Future<PayoutModel> adminDisburse(int payoutId) async {
    final res = await _api.post('/payouts/admin/$payoutId/disburse', {});
    return PayoutModel.fromJson(res as Map<String, dynamic>);
  }

  /// Returns the URL the client can open in the browser to download
  /// the CSV — the current [ApiClient] only speaks JSON.
  static String adminCsvUrl(int payoutId) =>
      '${ApiClient.baseUrl}/payouts/admin/$payoutId/csv';
}
