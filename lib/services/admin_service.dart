// ═══════════════════════════════════════════════════════════════
//  TALAA — Admin Service
//  Admin-only REST calls: users, properties, bookings, reviews, stats.
//  All endpoints require the caller to have UserRole.admin.
// ═══════════════════════════════════════════════════════════════

import '../models/admin_refund_row.dart';
import '../models/admin_review_item.dart';
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

  static Future<List<PropertyApi>> getPendingProperties({
    int page = 1,
    int limit = 100,
  }) async {
    final data = await _api.get(
      '/admin/properties/pending?page=$page&limit=$limit',
    );
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

  /// Toggle the ``is_featured`` flag on a property.  Featured rows
  /// bubble up on the home page's curated rail.
  static Future<PropertyApi> setPropertyFeatured(
      int id, bool featured) async {
    final data = await _api.patch(
      '/admin/properties/$id/featured',
      {'is_featured': featured},
    );
    return PropertyApi.fromJson(data as Map<String, dynamic>);
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
  //  REVIEWS  (moderation)
  // ══════════════════════════════════════════════════════════

  /// Paginated review list for the admin moderation panel.
  ///
  /// Filters mirror the backend ``GET /admin/reviews`` query params:
  /// - [hidden] — null = both, true = hidden only, false = visible only
  /// - [flaggedOnly] — only reviews where ``report_count > 0``
  /// - [minRating] / [maxRating] — rating window (1-5)
  /// - [propertyId] — restrict to one property
  /// - [search] — case-insensitive substring match against the comment
  static Future<({List<AdminReviewItem> items, int total, int pages})>
      getReviewsForModeration({
    bool? hidden,
    bool flaggedOnly = false,
    double? minRating,
    double? maxRating,
    int? propertyId,
    String? search,
    int page = 1,
    int limit = 30,
  }) async {
    final params = <String, String>{
      'page': '$page',
      'limit': '$limit',
      if (hidden != null) 'hidden': '$hidden',
      if (flaggedOnly) 'flagged_only': 'true',
      if (minRating != null) 'min_rating': '$minRating',
      if (maxRating != null) 'max_rating': '$maxRating',
      if (propertyId != null) 'property_id': '$propertyId',
      if (search != null && search.isNotEmpty) 'search': search,
    };
    final qs = params.entries
        .map((e) =>
            '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}')
        .join('&');
    final data = await _api.get('/admin/reviews?$qs');
    final items = (data['items'] as List)
        .map((e) => AdminReviewItem.fromJson(e as Map<String, dynamic>))
        .toList();
    return (
      items: items,
      total: (data['total'] as num?)?.toInt() ?? items.length,
      pages: (data['pages'] as num?)?.toInt() ?? 1,
    );
  }

  /// Toggle the soft-hide flag on a review.  When [hidden] is true
  /// the review disappears from public listings but stays linked to
  /// its booking; when false it becomes visible again immediately.
  static Future<AdminReviewItem> setReviewHidden(
      int reviewId, bool hidden) async {
    final data = await _api.patch(
      '/admin/reviews/$reviewId/hide',
      {'is_hidden': hidden},
    );
    return AdminReviewItem.fromJson(data as Map<String, dynamic>);
  }

  /// Permanently delete a review and recompute the property's average
  /// rating.  Use sparingly — the soft-hide above is preferred for
  /// borderline content because it preserves the booking ↔ review
  /// link.
  static Future<void> deleteReview(int reviewId) async {
    await _api.delete('/admin/reviews/$reviewId');
  }

  // ══════════════════════════════════════════════════════════
  //  REFUNDS  (finance queue)
  // ══════════════════════════════════════════════════════════

  /// Paginated refund queue.
  ///
  /// [state] may be:
  /// - ``'pending'``   — paid + cancelled bookings whose refund hasn't
  ///                     been marked refunded yet (default).
  /// - ``'processed'`` — already refunded / partially refunded.
  /// - ``'all'``       — both buckets in one list.
  static Future<({List<AdminRefundRow> items, int total, int pages})>
      getRefunds({
    String state = 'pending',
    int page = 1,
    int limit = 30,
  }) async {
    final qs = 'page=$page&limit=$limit&state=$state';
    final data = await _api.get('/admin/refunds?$qs');
    final items = (data['items'] as List)
        .map((e) => AdminRefundRow.fromJson(e as Map<String, dynamic>))
        .toList();
    return (
      items: items,
      total: (data['total'] as num?)?.toInt() ?? items.length,
      pages: (data['pages'] as num?)?.toInt() ?? 1,
    );
  }

  /// Mark a booking as ``refunded`` (or ``partially_refunded``) after
  /// the gateway refund was processed out-of-band.  Audit-logged on
  /// the backend.
  static Future<AdminRefundRow> markRefundProcessed(
    int bookingId, {
    bool partial = false,
    String? note,
  }) async {
    final data = await _api.post(
      '/admin/refunds/$bookingId/mark-processed',
      {
        'partial': partial,
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      },
    );
    return AdminRefundRow.fromJson(data as Map<String, dynamic>);
  }

  // ══════════════════════════════════════════════════════════
  //  FRAUD DETECTION (suspicious accounts)
  // ══════════════════════════════════════════════════════════
  static Future<List<Map<String, dynamic>>> getFraudFlags({
    int threshold = 30,
    int limit = 50,
  }) async {
    final data = await _api.get(
      '/admin/fraud-detection?threshold=$threshold&limit=$limit',
    );
    return (data as List).cast<Map<String, dynamic>>();
  }

  // ══════════════════════════════════════════════════════════
  //  ADVANCED ANALYTICS  (admin dashboard page)
  // ══════════════════════════════════════════════════════════
  static Future<Map<String, dynamic>> getAdvancedAnalytics(
      {int months = 6}) async {
    final data = await _api.get('/admin/analytics/advanced?months=$months');
    return data as Map<String, dynamic>;
  }

  // ══════════════════════════════════════════════════════════
  //  PLATFORM SETTINGS  (pricing rules page)
  // ══════════════════════════════════════════════════════════
  static Future<Map<String, dynamic>> getPlatformSettings() async {
    final data = await _api.get('/admin/settings');
    return data as Map<String, dynamic>;
  }

  /// Patch any subset of the platform settings.  Pass only the keys
  /// the admin actually changed to keep the PATCH minimal.
  static Future<Map<String, dynamic>> updatePlatformSettings(
    Map<String, dynamic> changes, {
    String? note,
  }) async {
    final body = {
      ...changes,
      if (note != null && note.isNotEmpty) 'note': note,
    };
    final data = await _api.patch('/admin/settings', body);
    return data as Map<String, dynamic>;
  }

  // ══════════════════════════════════════════════════════════
  //  STATS
  // ══════════════════════════════════════════════════════════
  static Future<Map<String, dynamic>> getStats() async {
    final data = await _api.get('/admin/stats');
    return data as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> getFinancialReport({int months = 12}) async {
    final data = await _api.get('/admin/financial-report?months=$months');
    return data as Map<String, dynamic>;
  }

  // ── Code lookups ───────────────────────────────────────────
  static Future<Map<String, dynamic>> lookupPropertyCode(String code) async {
    final data = await _api.get('/admin/lookup/property/${Uri.encodeComponent(code)}');
    return data as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> lookupBookingCode(String code) async {
    final data = await _api.get('/admin/lookup/booking/${Uri.encodeComponent(code)}');
    return data as Map<String, dynamic>;
  }

  // ── Trip Posts moderation ──────────────────────────────────
  static Future<List<Map<String, dynamic>>> adminListTripPosts({
    bool hiddenOnly = false,
    String? verdict,
    String? search,
    int limit = 50,
    int offset = 0,
  }) async {
    var q = '/trip-posts/admin/list?limit=$limit&offset=$offset&hidden_only=$hiddenOnly';
    if (verdict != null) q += '&verdict=${Uri.encodeComponent(verdict)}';
    if (search != null && search.isNotEmpty) {
      q += '&search=${Uri.encodeComponent(search)}';
    }
    final data = await _api.get(q);
    return (data as List).cast<Map<String, dynamic>>();
  }

  static Future<void> adminHideTripPost(int postId) async {
    await _api.post('/trip-posts/admin/$postId/hide', {});
  }

  static Future<void> adminUnhideTripPost(int postId) async {
    await _api.post('/trip-posts/admin/$postId/unhide', {});
  }

  static Future<void> adminDeleteTripPost(int postId) async {
    await _api.delete('/trip-posts/$postId');
  }
}
