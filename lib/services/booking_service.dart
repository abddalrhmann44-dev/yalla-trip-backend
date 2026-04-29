// ═══════════════════════════════════════════════════════════════
//  TALAA — Booking Service
//  All booking-related API calls
// ═══════════════════════════════════════════════════════════════

import '../models/booking_model.dart';
import '../models/refund_quote.dart';
import '../utils/api_client.dart';

class BookingService {
  static final _api = ApiClient();

  // ── Create a new booking ──────────────────────────────────
  /// [promoCode] is optional; when provided the backend validates it
  /// and either returns the discounted booking or rejects it with 400.
  static Future<BookingModel> createBooking({
    required int propertyId,
    required DateTime checkIn,
    required DateTime checkOut,
    required int guestsCount,
    String? promoCode,
    double walletAmount = 0,
  }) async {
    final data = await _api.post('/bookings', {
      'property_id': propertyId,
      'check_in': checkIn.toIso8601String().split('T')[0],
      'check_out': checkOut.toIso8601String().split('T')[0],
      'guests_count': guestsCount,
      if (promoCode != null && promoCode.trim().isNotEmpty)
        'promo_code': promoCode.trim(),
      if (walletAmount > 0) 'wallet_amount': walletAmount,
    });
    return BookingModel.fromJson(data as Map<String, dynamic>);
  }

  // ── My bookings (as guest) ────────────────────────────────
  static Future<List<BookingModel>> getMyBookings({
    String? status,
    int page = 1,
    int limit = 20,
  }) async {
    String query = '?page=$page&limit=$limit';
    if (status != null) query += '&status=${Uri.encodeComponent(status)}';

    final data = await _api.get('/bookings/my$query');
    return (data['items'] as List)
        .map((e) => BookingModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── Owner bookings ────────────────────────────────────────
  static Future<List<BookingModel>> getOwnerBookings({
    String? status,
    int page = 1,
    int limit = 20,
  }) async {
    String query = '?page=$page&limit=$limit';
    if (status != null) query += '&status=${Uri.encodeComponent(status)}';

    final data = await _api.get('/bookings/owner$query');
    return (data['items'] as List)
        .map((e) => BookingModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── Confirm booking (owner action) ────────────────────────
  static Future<BookingModel> confirmBooking(int id) async {
    final data = await _api.put('/bookings/$id/confirm', {});
    return BookingModel.fromJson(data as Map<String, dynamic>);
  }

  // ── Cancel-preview: how much will the guest get back? ─────
  static Future<RefundQuote> cancelPreview(int id) async {
    final data = await _api.get('/bookings/$id/cancel/preview');
    return RefundQuote.fromJson(data as Map<String, dynamic>);
  }

  // ── Cancel booking ────────────────────────────────────────
  static Future<BookingModel> cancelBooking(int id, {String? reason}) async {
    final data = await _api.put('/bookings/$id/cancel', {
      if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
    });
    return BookingModel.fromJson(data as Map<String, dynamic>);
  }

  // ── Complete booking (owner action) ───────────────────────
  static Future<BookingModel> completeBooking(int id) async {
    final data = await _api.put('/bookings/$id/complete', {});
    return BookingModel.fromJson(data as Map<String, dynamic>);
  }

  // ── Cash-on-arrival workflow (Wave 25) ────────────────────
  // Three mirror endpoints that drive the deposit + cash settlement
  // handshake.  All three return the updated ``BookingModel`` so
  // the caller can rebuild the UI without a second fetch.

  /// Host confirms they received the cash leg from the guest.
  /// Pairs with [confirmArrival]; both must fire before the
  /// platform releases the host's online payout.
  static Future<BookingModel> confirmCashReceived(int id) async {
    final data = await _api.post(
      '/bookings/$id/confirm-cash-received',
      {},
    );
    return BookingModel.fromJson(data as Map<String, dynamic>);
  }

  /// Guest confirms they arrived and handed over the cash leg.
  static Future<BookingModel> confirmArrival(int id) async {
    final data = await _api.post('/bookings/$id/confirm-arrival', {});
    return BookingModel.fromJson(data as Map<String, dynamic>);
  }

  /// Host reports the guest as a no-show.  Backend forfeits the
  /// deposit minus a single night's commission.
  static Future<BookingModel> reportNoShow(int id) async {
    final data = await _api.post('/bookings/$id/report-no-show', {});
    return BookingModel.fromJson(data as Map<String, dynamic>);
  }

  // ── Refund security deposit (owner action) ────────────────
  static Future<BookingModel> refundDeposit(int id) async {
    final data = await _api.post('/bookings/$id/deposit/refund', {});
    return BookingModel.fromJson(data as Map<String, dynamic>);
  }

  // ── Deduct security deposit (owner action) ────────────────
  static Future<BookingModel> deductDeposit(int id) async {
    final data = await _api.post('/bookings/$id/deposit/deduct', {});
    return BookingModel.fromJson(data as Map<String, dynamic>);
  }
}
