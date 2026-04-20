// ═══════════════════════════════════════════════════════════════
//  TALAA — Review Models
//  Mirrors backend ReviewOut / PendingReviewItem schemas.
// ═══════════════════════════════════════════════════════════════

class ReviewUserBrief {
  final int id;
  final String name;
  final String? avatarUrl;

  const ReviewUserBrief({
    required this.id,
    required this.name,
    this.avatarUrl,
  });

  factory ReviewUserBrief.fromJson(Map<String, dynamic> j) =>
      ReviewUserBrief(
        id: j['id'] ?? 0,
        name: (j['name'] ?? '').toString(),
        avatarUrl: j['avatar_url'] as String?,
      );
}

class ReviewModel {
  final int id;
  final int bookingId;
  final int propertyId;
  final int reviewerId;
  final ReviewUserBrief? reviewer;
  final double rating;
  final String? comment;
  final String? ownerResponse;
  final DateTime? ownerResponseAt;
  final bool isHidden;
  final DateTime createdAt;

  const ReviewModel({
    required this.id,
    required this.bookingId,
    required this.propertyId,
    required this.reviewerId,
    this.reviewer,
    required this.rating,
    this.comment,
    this.ownerResponse,
    this.ownerResponseAt,
    this.isHidden = false,
    required this.createdAt,
  });

  factory ReviewModel.fromJson(Map<String, dynamic> j) {
    DateTime? parseDt(dynamic v) =>
        v == null ? null : DateTime.tryParse(v.toString());

    return ReviewModel(
      id: j['id'] ?? 0,
      bookingId: j['booking_id'] ?? 0,
      propertyId: j['property_id'] ?? 0,
      reviewerId: j['reviewer_id'] ?? 0,
      reviewer: j['reviewer'] != null
          ? ReviewUserBrief.fromJson(
              (j['reviewer'] as Map).cast<String, dynamic>())
          : null,
      rating: (j['rating'] ?? 0).toDouble(),
      comment: j['comment'] as String?,
      ownerResponse: j['owner_response'] as String?,
      ownerResponseAt: parseDt(j['owner_response_at']),
      isHidden: j['is_hidden'] == true,
      createdAt: parseDt(j['created_at']) ?? DateTime.now(),
    );
  }

  bool get hasOwnerResponse =>
      ownerResponse != null && ownerResponse!.trim().isNotEmpty;
}

/// Summary of a completed booking that the user hasn't reviewed yet.
/// Returned by ``GET /reviews/my/pending``.
class PendingReview {
  final int bookingId;
  final String bookingCode;
  final int propertyId;
  final String propertyName;
  final String? propertyImage;
  final DateTime checkIn;
  final DateTime checkOut;
  final DateTime completedAt;

  const PendingReview({
    required this.bookingId,
    required this.bookingCode,
    required this.propertyId,
    required this.propertyName,
    this.propertyImage,
    required this.checkIn,
    required this.checkOut,
    required this.completedAt,
  });

  factory PendingReview.fromJson(Map<String, dynamic> j) {
    return PendingReview(
      bookingId: j['booking_id'] ?? 0,
      bookingCode: (j['booking_code'] ?? '').toString(),
      propertyId: j['property_id'] ?? 0,
      propertyName: (j['property_name'] ?? '').toString(),
      propertyImage: j['property_image'] as String?,
      checkIn: DateTime.tryParse(j['check_in'] ?? '') ?? DateTime.now(),
      checkOut: DateTime.tryParse(j['check_out'] ?? '') ?? DateTime.now(),
      completedAt:
          DateTime.tryParse(j['completed_at'] ?? '') ?? DateTime.now(),
    );
  }

  int get nights => checkOut.difference(checkIn).inDays;
}
