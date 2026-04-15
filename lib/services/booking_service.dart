// ═══════════════════════════════════════════════════════════════
//  TALAA — Booking Service
//  All booking-related API calls
// ═══════════════════════════════════════════════════════════════

import '../models/booking_model.dart';
import '../utils/api_client.dart';

class BookingService {
  static final _api = ApiClient();

  // ── Create a new booking ──────────────────────────────────
  static Future<BookingModel> createBooking({
    required int propertyId,
    required DateTime checkIn,
    required DateTime checkOut,
    required int guestsCount,
  }) async {
    final data = await _api.post('/bookings', {
      'property_id': propertyId,
      'check_in': checkIn.toIso8601String().split('T')[0],
      'check_out': checkOut.toIso8601String().split('T')[0],
      'guests_count': guestsCount,
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

  // ── Cancel booking ────────────────────────────────────────
  static Future<BookingModel> cancelBooking(int id) async {
    final data = await _api.put('/bookings/$id/cancel', {});
    return BookingModel.fromJson(data as Map<String, dynamic>);
  }

  // ── Complete booking (owner action) ───────────────────────
  static Future<BookingModel> completeBooking(int id) async {
    final data = await _api.put('/bookings/$id/complete', {});
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
