// ═══════════════════════════════════════════════════════════════
//  YALLA TRIP — Payment Service
//  Mock implementation — replace with real payment gateway
// ═══════════════════════════════════════════════════════════════

import 'dart:math';

enum PaymentMethod { visa, meeza, fawry, vodafoneCash, etisalatCash }

class PaymentResult {
  final bool success;
  final String transactionId;
  final String? errorMessage;

  const PaymentResult({
    required this.success,
    this.transactionId = '',
    this.errorMessage,
  });
}

class PaymentService {
  // ── Handle payment (mock) ─────────────────────────────────
  /// Simulates payment processing. Replace with real gateway.
  Future<PaymentResult> handlePayment({
    required PaymentMethod method,
    required double amount,
    required String userId,
    Map<String, String>? cardDetails,
  }) async {
    // Simulate network delay
    await Future.delayed(const Duration(seconds: 2));

    // Mock: 95% success rate
    final success = Random().nextDouble() < 0.95;

    if (success) {
      final txId = 'TXN_${DateTime.now().millisecondsSinceEpoch}';
      return PaymentResult(success: true, transactionId: txId);
    } else {
      return const PaymentResult(
        success: false,
        errorMessage: 'فشل في الدفع، حاول مرة أخرى',
      );
    }
  }

  // ── Method labels ─────────────────────────────────────────
  static String methodLabel(PaymentMethod method, {bool arabic = true}) {
    switch (method) {
      case PaymentMethod.visa:
        return arabic ? 'فيزا / ماستركارد' : 'Visa / Mastercard';
      case PaymentMethod.meeza:
        return arabic ? 'ميزة' : 'Meeza';
      case PaymentMethod.fawry:
        return arabic ? 'فوري' : 'Fawry';
      case PaymentMethod.vodafoneCash:
        return arabic ? 'فودافون كاش' : 'Vodafone Cash';
      case PaymentMethod.etisalatCash:
        return arabic ? 'اتصالات كاش' : 'Etisalat Cash';
    }
  }

  static String methodIcon(PaymentMethod method) {
    switch (method) {
      case PaymentMethod.visa:
        return '💳';
      case PaymentMethod.meeza:
        return '🏦';
      case PaymentMethod.fawry:
        return '🏪';
      case PaymentMethod.vodafoneCash:
        return '📱';
      case PaymentMethod.etisalatCash:
        return '📲';
    }
  }
}
