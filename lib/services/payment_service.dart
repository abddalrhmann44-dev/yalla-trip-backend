// ═══════════════════════════════════════════════════════════════
//  TALAA — Payment Service
//  Wraps the /payments/* REST endpoints.
// ═══════════════════════════════════════════════════════════════

import '../models/payment_model.dart';
import '../utils/api_client.dart';

class PaymentService {
  static final _api = ApiClient();

  /// Starts a payment for [bookingId] using [provider] + [method].
  /// Returns the initiate response with a possible ``checkoutUrl``.
  static Future<PaymentInitiateResult> initiate({
    required int bookingId,
    required PayProvider provider,
    required PayMethod method,
  }) async {
    final data = await _api.post('/payments/initiate', {
      'booking_id': bookingId,
      'provider': providerWire(provider),
      'method': methodWire(method),
    });
    return PaymentInitiateResult.fromJson(data as Map<String, dynamic>);
  }

  /// List my payments (descending by created_at).
  static Future<List<PaymentStatus>> myPayments() async {
    final data = await _api.get('/payments/my');
    return (data as List)
        .map((e) => PaymentStatus.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Fetch the live status of a single payment – used for polling
  /// after the user returns from the gateway web view.
  static Future<PaymentStatus> getPayment(int paymentId) async {
    final data = await _api.get('/payments/$paymentId');
    return PaymentStatus.fromJson(data as Map<String, dynamic>);
  }
}
