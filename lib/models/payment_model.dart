// ═══════════════════════════════════════════════════════════════
//  TALAA — Payment Model
//  Mirrors backend PaymentOut / PaymentInitiateResponse schemas.
// ═══════════════════════════════════════════════════════════════

enum PayProvider { fawry, paymob, cod }

enum PayMethod { card, wallet, fawryVoucher, instapay, cod }

enum PayState {
  pending,
  processing,
  paid,
  failed,
  refunded,
  expired,
  cancelled,
}

// ── small helpers (free functions – no need for extensions) ─────
PayProvider _parseProvider(String s) {
  switch (s) {
    case 'fawry':
      return PayProvider.fawry;
    case 'paymob':
      return PayProvider.paymob;
    case 'cod':
      return PayProvider.cod;
  }
  return PayProvider.paymob;
}

PayMethod _parseMethod(String s) {
  switch (s) {
    case 'card':
      return PayMethod.card;
    case 'wallet':
      return PayMethod.wallet;
    case 'fawry_voucher':
      return PayMethod.fawryVoucher;
    case 'instapay':
      return PayMethod.instapay;
    case 'cod':
      return PayMethod.cod;
  }
  return PayMethod.card;
}

PayState _parseState(String s) {
  switch (s) {
    case 'pending':
      return PayState.pending;
    case 'processing':
      return PayState.processing;
    case 'paid':
      return PayState.paid;
    case 'failed':
      return PayState.failed;
    case 'refunded':
      return PayState.refunded;
    case 'expired':
      return PayState.expired;
    case 'cancelled':
      return PayState.cancelled;
  }
  return PayState.pending;
}

String providerWire(PayProvider p) => p.name; // enum name matches backend

String methodWire(PayMethod m) {
  switch (m) {
    case PayMethod.card:
      return 'card';
    case PayMethod.wallet:
      return 'wallet';
    case PayMethod.fawryVoucher:
      return 'fawry_voucher';
    case PayMethod.instapay:
      return 'instapay';
    case PayMethod.cod:
      return 'cod';
  }
}

// ── InitiateResponse ───────────────────────────────────────────
class PaymentInitiateResult {
  final int paymentId;
  final PayProvider provider;
  final PayMethod method;
  final PayState state;
  final double amount;
  final String currency;
  final String merchantRef;
  final String? providerRef;
  final String? checkoutUrl;
  final Map<String, dynamic> extra;

  const PaymentInitiateResult({
    required this.paymentId,
    required this.provider,
    required this.method,
    required this.state,
    required this.amount,
    required this.currency,
    required this.merchantRef,
    this.providerRef,
    this.checkoutUrl,
    this.extra = const {},
  });

  factory PaymentInitiateResult.fromJson(Map<String, dynamic> j) {
    return PaymentInitiateResult(
      paymentId: j['payment_id'] ?? 0,
      provider: _parseProvider((j['provider'] ?? 'paymob').toString()),
      method: _parseMethod((j['method'] ?? 'card').toString()),
      state: _parseState((j['state'] ?? 'pending').toString()),
      amount: (j['amount'] ?? 0).toDouble(),
      currency: (j['currency'] ?? 'EGP').toString(),
      merchantRef: (j['merchant_ref'] ?? '').toString(),
      providerRef: j['provider_ref'] as String?,
      checkoutUrl: j['checkout_url'] as String?,
      extra: (j['extra'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
  }
}

// ── PaymentOut (status polling) ────────────────────────────────
class PaymentStatus {
  final int id;
  final int bookingId;
  final PayProvider provider;
  final PayMethod method;
  final PayState state;
  final double amount;
  final String currency;
  final String merchantRef;
  final String? providerRef;
  final String? checkoutUrl;
  final String? errorMessage;
  final DateTime? paidAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const PaymentStatus({
    required this.id,
    required this.bookingId,
    required this.provider,
    required this.method,
    required this.state,
    required this.amount,
    required this.currency,
    required this.merchantRef,
    this.providerRef,
    this.checkoutUrl,
    this.errorMessage,
    this.paidAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PaymentStatus.fromJson(Map<String, dynamic> j) {
    DateTime? parseDt(dynamic v) =>
        v == null ? null : DateTime.tryParse(v.toString());

    return PaymentStatus(
      id: j['id'] ?? 0,
      bookingId: j['booking_id'] ?? 0,
      provider: _parseProvider((j['provider'] ?? 'paymob').toString()),
      method: _parseMethod((j['method'] ?? 'card').toString()),
      state: _parseState((j['state'] ?? 'pending').toString()),
      amount: (j['amount'] ?? 0).toDouble(),
      currency: (j['currency'] ?? 'EGP').toString(),
      merchantRef: (j['merchant_ref'] ?? '').toString(),
      providerRef: j['provider_ref'] as String?,
      checkoutUrl: j['checkout_url'] as String?,
      errorMessage: j['error_message'] as String?,
      paidAt: parseDt(j['paid_at']),
      createdAt: parseDt(j['created_at']) ?? DateTime.now(),
      updatedAt: parseDt(j['updated_at']) ?? DateTime.now(),
    );
  }

  bool get isTerminal =>
      state == PayState.paid ||
      state == PayState.failed ||
      state == PayState.refunded ||
      state == PayState.expired ||
      state == PayState.cancelled;
}
