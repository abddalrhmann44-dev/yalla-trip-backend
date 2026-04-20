// ═══════════════════════════════════════════════════════════════
//  TALAA — Admin Service
//  Admin-only REST calls: users, properties, bookings, reviews, stats.
//  All endpoints require the caller to have UserRole.admin.
// ═══════════════════════════════════════════════════════════════

import '../models/booking_model.dart';
import '../models/property_model_api.dart';
import '../models/user_model_api.dart';
import '../utils/api_client.dart';

class AdminService {
  static final _api = ApiClient();

  // ══════════════════════════════════════════════════════════
  //  USERS
  // ══════════════════════════════════════════════════════════
  static Future<List<UserApi>> getUsers({
    String? search,
    String? role,
    int page = 1,
    int limit = 50,
  }) async {
    String query = '?page=$page&limit=$limit';
    if (search != null && search.isNotEmpty) {
      query += '&search=${Uri.encodeComponent(search)}';
    }
    if (role != null && role.isNotEmpty) {
      query += '&role=${Uri.encodeComponent(role)}';
    }
    final data = await _api.get('/admin/users$query');
    return (data['items'] as List)
        .map((e) => UserApi.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Soft-delete / deactivate a user account.
  static Future<void> deactivateUser(int userId) async {
    await _api.delete('/admin/users/$userId');
  }

  /// Re-enable a previously deactivated account.
  static Future<UserApi> activateUser(int userId) async {
    final data = await _api.patch('/admin/users/$userId/activate', {});
    return UserApi.fromJson(data as Map<String, dynamic>);
  }

  /// Promote / demote a user (guest ↔ owner ↔ admin).
  static Future<UserApi> changeUserRole(int userId, String role) async {
    final data = await _api.patch('/admin/users/$userId/role', {'role': role});
    return UserApi.fromJson(data as Map<String, dynamic>);
  }

  /// Toggle the KYC-verified flag on a user.
  static Future<UserApi> setUserVerified(int userId, bool verified) async {
    final data = await _api.patch(
      '/admin/users/$userId/verify',
      {'is_verified': verified},
    );
    return UserApi.fromJson(data as Map<String, dynamic>);
  }

  // ══════════════════════════════════════════════════════════
  //  PROPERTIES
  // ══════════════════════════════════════════════════════════
  static Future<List<PropertyApi>> getProperties({
    String? search,
    int page = 1,
    int limit = 50,
  }) async {
    String query = '?page=$page&limit=$limit';
    if (search != null && search.isNotEmpty) {
      query += '&search=${Uri.encodeComponent(search)}';
    }
    final data = await _api.get('/admin/properties$query');
    return (data['items'] as List)
        .map((e) => PropertyApi.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<PropertyApi> approveProperty(int id) async {
    final data = await _api.put('/admin/properties/$id/approve', {});
    return PropertyApi.fromJson(data as Map<String, dynamic>);
  }

  static Future<PropertyApi> rejectProperty(int id, {String? note}) async {
    final body = <String, dynamic>{};
    if (note != null) body['note'] = note;
    final data = await _api.put('/admin/properties/$id/reject', body);
    return PropertyApi.fromJson(data as Map<String, dynamic>);
  }

  static Future<PropertyApi> needsEditProperty(int id, {String? note}) async {
    final body = <String, dynamic>{};
    if (note != null) body['note'] = note;
    final data = await _api.put('/admin/properties/$id/needs-edit', body);
    return PropertyApi.fromJson(data as Map<String, dynamic>);
  }

  /// Permanently remove a property (cascades to its bookings & reviews).
  static Future<void> deleteProperty(int id) async {
    await _api.delete('/admin/properties/$id');
  }

  // ══════════════════════════════════════════════════════════
  //  BOOKINGS
  // ══════════════════════════════════════════════════════════
  static Future<List<BookingModel>> getAllBookings({
    String? status,
    String? paymentStatus,
    int page = 1,
    int limit = 50,
  }) async {
    String query = '?page=$page&limit=$limit';
    if (status != null && status.isNotEmpty) {
      query += '&status=${Uri.encodeComponent(status)}';
    }
    if (paymentStatus != null && paymentStatus.isNotEmpty) {
      query += '&payment_status=${Uri.encodeComponent(paymentStatus)}';
    }
    final data = await _api.get('/admin/bookings$query');
    return (data['items'] as List)
        .map((e) => BookingModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<BookingModel> confirmBooking(int id) async {
    final data = await _api.put('/bookings/$id/confirm', {});
    return BookingModel.fromJson(data as Map<String, dynamic>);
  }

  static Future<BookingModel> cancelBooking(int id) async {
    final data = await _api.put('/bookings/$id/cancel', {});
    return BookingModel.fromJson(data as Map<String, dynamic>);
  }

  static Future<BookingModel> completeBooking(int id) async {
    final data = await _api.put('/bookings/$id/complete', {});
    return BookingModel.fromJson(data as Map<String, dynamic>);
  }

  // ══════════════════════════════════════════════════════════
  //  REVIEWS
  // ══════════════════════════════════════════════════════════
  static Future<void> deleteReview(int reviewId) async {
    await _api.delete('/admin/reviews/$reviewId');
  }

  // ══════════════════════════════════════════════════════════
  //  STATS
  // ══════════════════════════════════════════════════════════
  static Future<Map<String, dynamic>> getStats() async {
    final data = await _api.get('/admin/stats');
    return data as Map<String, dynamic>;
  }
}
