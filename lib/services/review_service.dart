// ═══════════════════════════════════════════════════════════════
//  TALAA — Review Service
//  Wraps the /reviews/* REST endpoints.
// ═══════════════════════════════════════════════════════════════

import '../models/review_model.dart';
import '../utils/api_client.dart';

class ReviewService {
  static final _api = ApiClient();

  /// Submit a new review for a completed booking.
  static Future<ReviewModel> create({
    required int bookingId,
    required double rating,
    String? comment,
  }) async {
    final data = await _api.post('/reviews', {
      'booking_id': bookingId,
      'rating': rating,
      if (comment != null && comment.trim().isNotEmpty) 'comment': comment,
    });
    return ReviewModel.fromJson(data as Map<String, dynamic>);
  }

  /// Completed bookings the user hasn't reviewed yet.
  static Future<List<PendingReview>> myPending() async {
    final data = await _api.get('/reviews/my/pending');
    return (data as List)
        .map((e) => PendingReview.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  /// Number of reviews the current user has authored – used for the
  /// profile badge.
  static Future<int> myCount() async {
    final data = await _api.get('/reviews/my/count');
    return ((data as Map)['count'] ?? 0) as int;
  }

  /// Paginated list of reviews for a property.  Hidden/moderated
  /// rows are filtered out server-side.
  static Future<List<ReviewModel>> forProperty(
    int propertyId, {
    int page = 1,
    int limit = 20,
  }) async {
    final data =
        await _api.get('/reviews/property/$propertyId?page=$page&limit=$limit');
    final items = (data as Map)['items'] as List? ?? const [];
    return items
        .map((e) => ReviewModel.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  /// Owner-side endpoint – post a public reply to a review on your
  /// own property.
  static Future<ReviewModel> respond({
    required int reviewId,
    required String response,
  }) async {
    final data = await _api.post('/reviews/$reviewId/respond', {
      'response': response,
    });
    return ReviewModel.fromJson(data as Map<String, dynamic>);
  }

  /// Flag a review for moderation.
  static Future<void> report(int reviewId) async {
    await _api.post('/reviews/$reviewId/report', {});
  }
}
