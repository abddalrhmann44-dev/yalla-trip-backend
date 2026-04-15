// ═══════════════════════════════════════════════════════════════
//  TALAA — Admin Service
//  Admin-specific API calls (properties, users, stats)
// ═══════════════════════════════════════════════════════════════

import '../models/property_model_api.dart';
import '../models/booking_model.dart';
import '../utils/api_client.dart';

class AdminService {
  static final _api = ApiClient();

  // ── List all properties (admin) ─────────────────────────────
  static Future<List<PropertyApi>> getProperties({
    String? search,
    int page = 1,
    int limit = 50,
  }) async {
    String query = '?page=$page&limit=$limit';
    if (search != null) query += '&search=${Uri.encodeComponent(search)}';
    final data = await _api.get('/admin/properties$query');
    return (data['items'] as List)
        .map((e) => PropertyApi.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── Approve property ────────────────────────────────────────
  static Future<PropertyApi> approveProperty(int id) async {
    final data = await _api.put('/admin/properties/$id/approve', {});
    return PropertyApi.fromJson(data as Map<String, dynamic>);
  }

  // ── Reject property ────────────────────────────────────────
  static Future<PropertyApi> rejectProperty(int id, {String? note}) async {
    final body = <String, dynamic>{};
    if (note != null) body['note'] = note;
    final data = await _api.put('/admin/properties/$id/reject', body);
    return PropertyApi.fromJson(data as Map<String, dynamic>);
  }

  // ── Needs edit ────────────────────────────────────────────
  static Future<PropertyApi> needsEditProperty(int id, {String? note}) async {
    final body = <String, dynamic>{};
    if (note != null) body['note'] = note;
    final data = await _api.put('/admin/properties/$id/needs-edit', body);
    return PropertyApi.fromJson(data as Map<String, dynamic>);
  }

  // ── Delete property (admin) ─────────────────────────────────
  static Future<void> deleteProperty(int id) async {
    await _api.delete('/properties/$id');
  }

  // ── Get dashboard stats ─────────────────────────────────────
  static Future<Map<String, dynamic>> getStats() async {
    final data = await _api.get('/admin/stats');
    return data as Map<String, dynamic>;
  }

  // ── List all bookings (admin) ───────────────────────────────
  static Future<List<BookingModel>> getAllBookings({
    String? status,
    int page = 1,
    int limit = 50,
  }) async {
    String query = '?page=$page&limit=$limit';
    if (status != null) query += '&status=${Uri.encodeComponent(status)}';
    final data = await _api.get('/bookings/all$query');
    return (data['items'] as List)
        .map((e) => BookingModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── Confirm booking (admin) ─────────────────────────────────
  static Future<BookingModel> confirmBooking(int id) async {
    final data = await _api.put('/bookings/$id/confirm', {});
    return BookingModel.fromJson(data as Map<String, dynamic>);
  }

  // ── Cancel booking (admin) ──────────────────────────────────
  static Future<BookingModel> cancelBooking(int id) async {
    final data = await _api.put('/bookings/$id/cancel', {});
    return BookingModel.fromJson(data as Map<String, dynamic>);
  }
}
