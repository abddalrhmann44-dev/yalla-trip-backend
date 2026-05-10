// ═══════════════════════════════════════════════════════════════
//  TALAA — AdminReviewItem
//  DTO for the admin review-moderation page.  Mirrors the backend's
//  ``_AdminReviewOut`` schema in ``app/routers/admin.py`` and
//  surfaces every field the moderator needs in a single row:
//   - the review (rating, comment, host reply, created_at)
//   - the property (name + cover image, so the moderator does not
//     have to drill into the property page)
//   - the reviewer (name + avatar — to spot serial offenders)
//   - the moderation flags (is_hidden, report_count)
// ═══════════════════════════════════════════════════════════════

class AdminReviewItem {
  final int id;
  final int bookingId;
  final int propertyId;
  final String? propertyName;
  final String? propertyImage;
  final int reviewerId;
  final String? reviewerName;
  final String? reviewerAvatar;
  final double rating;
  final String? comment;
  final String? ownerResponse;
  final DateTime? ownerResponseAt;
  final bool isHidden;
  final int reportCount;
  final DateTime createdAt;

  const AdminReviewItem({
    required this.id,
    required this.bookingId,
    required this.propertyId,
    required this.reviewerId,
    required this.rating,
    required this.isHidden,
    required this.reportCount,
    required this.createdAt,
    this.propertyName,
    this.propertyImage,
    this.reviewerName,
    this.reviewerAvatar,
    this.comment,
    this.ownerResponse,
    this.ownerResponseAt,
  });

  factory AdminReviewItem.fromJson(Map<String, dynamic> j) {
    DateTime? parseDate(Object? v) {
      if (v == null) return null;
      return DateTime.tryParse(v as String);
    }

    return AdminReviewItem(
      id: (j['id'] as num).toInt(),
      bookingId: (j['booking_id'] as num).toInt(),
      propertyId: (j['property_id'] as num).toInt(),
      propertyName: j['property_name'] as String?,
      propertyImage: j['property_image'] as String?,
      reviewerId: (j['reviewer_id'] as num).toInt(),
      reviewerName: j['reviewer_name'] as String?,
      reviewerAvatar: j['reviewer_avatar'] as String?,
      rating: (j['rating'] as num).toDouble(),
      comment: j['comment'] as String?,
      ownerResponse: j['owner_response'] as String?,
      ownerResponseAt: parseDate(j['owner_response_at']),
      isHidden: j['is_hidden'] as bool? ?? false,
      reportCount: (j['report_count'] as num?)?.toInt() ?? 0,
      createdAt: parseDate(j['created_at']) ?? DateTime.now(),
    );
  }

  /// Convenience copyWith used after a hide/unhide call so the list
  /// can be patched in-place without a full reload.
  AdminReviewItem copyWith({bool? isHidden}) => AdminReviewItem(
        id: id,
        bookingId: bookingId,
        propertyId: propertyId,
        propertyName: propertyName,
        propertyImage: propertyImage,
        reviewerId: reviewerId,
        reviewerName: reviewerName,
        reviewerAvatar: reviewerAvatar,
        rating: rating,
        comment: comment,
        ownerResponse: ownerResponse,
        ownerResponseAt: ownerResponseAt,
        isHidden: isHidden ?? this.isHidden,
        reportCount: reportCount,
        createdAt: createdAt,
      );
}
