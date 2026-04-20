// ═══════════════════════════════════════════════════════════════
//  TALAA — Refund Quote Model
//  Mirrors backend RefundQuoteOut (cancel preview response).
// ═══════════════════════════════════════════════════════════════

enum CancellationPolicyTier { flexible, moderate, strict }

CancellationPolicyTier _parsePolicy(String s) {
  switch (s) {
    case 'flexible':
      return CancellationPolicyTier.flexible;
    case 'strict':
      return CancellationPolicyTier.strict;
    case 'moderate':
    default:
      return CancellationPolicyTier.moderate;
  }
}

String policyLabelAr(CancellationPolicyTier p) {
  switch (p) {
    case CancellationPolicyTier.flexible:
      return 'مرنة';
    case CancellationPolicyTier.moderate:
      return 'متوسطة';
    case CancellationPolicyTier.strict:
      return 'صارمة';
  }
}

class RefundQuote {
  final int refundablePercent;
  final double refundAmount;
  final bool platformFeeRefunded;
  final String reasonEn;
  final String reasonAr;
  final CancellationPolicyTier policy;

  const RefundQuote({
    required this.refundablePercent,
    required this.refundAmount,
    required this.platformFeeRefunded,
    required this.reasonEn,
    required this.reasonAr,
    required this.policy,
  });

  factory RefundQuote.fromJson(Map<String, dynamic> j) => RefundQuote(
        refundablePercent: j['refundable_percent'] ?? 0,
        refundAmount: (j['refund_amount'] ?? 0).toDouble(),
        platformFeeRefunded: j['platform_fee_refunded'] == true,
        reasonEn: (j['reason_en'] ?? '').toString(),
        reasonAr: (j['reason_ar'] ?? '').toString(),
        policy: _parsePolicy(
          (j['cancellation_policy'] ?? 'moderate').toString(),
        ),
      );

  bool get isFullRefund => refundablePercent >= 100;
  bool get isPartial =>
      refundablePercent > 0 && refundablePercent < 100;
  bool get noRefund => refundablePercent == 0;
}
