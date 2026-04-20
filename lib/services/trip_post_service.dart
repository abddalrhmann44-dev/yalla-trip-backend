// ═══════════════════════════════════════════════════════════════
//  TALAA — TripPost (Best-Trip feed) Service
//  Thin wrapper over the /trip-posts/* REST endpoints.
// ═══════════════════════════════════════════════════════════════

import '../utils/api_client.dart';

enum TripVerdict { loved, disliked }

String tripVerdictCode(TripVerdict v) =>
    v == TripVerdict.loved ? 'loved' : 'disliked';

TripVerdict _verdictFromCode(String s) =>
    s == 'loved' ? TripVerdict.loved : TripVerdict.disliked;

class TripAuthor {
  final int id;
  final String name;
  final String? avatarUrl;
  final bool isVerified;
  TripAuthor({
    required this.id,
    required this.name,
    this.avatarUrl,
    required this.isVerified,
  });
  factory TripAuthor.fromJson(Map<String, dynamic> j) => TripAuthor(
        id: j['id'] as int,
        name: j['name'] as String? ?? '',
        avatarUrl: j['avatar_url'] as String?,
        isVerified: (j['is_verified'] as bool?) ?? false,
      );
}

class TripPropertyBrief {
  final int id;
  final String name;
  final String area;
  final bool isVerified;
  TripPropertyBrief({
    required this.id,
    required this.name,
    required this.area,
    required this.isVerified,
  });
  factory TripPropertyBrief.fromJson(Map<String, dynamic> j) =>
      TripPropertyBrief(
        id: j['id'] as int,
        name: j['name'] as String? ?? '',
        area: j['area'] as String? ?? '',
        isVerified: (j['is_verified'] as bool?) ?? false,
      );
}

class TripPost {
  final int id;
  final TripVerdict verdict;
  final String? caption;
  final List<String> imageUrls;
  final DateTime createdAt;
  final int propertyId;
  final int bookingId;
  final TripAuthor author;
  final TripPropertyBrief property;

  TripPost({
    required this.id,
    required this.verdict,
    required this.caption,
    required this.imageUrls,
    required this.createdAt,
    required this.propertyId,
    required this.bookingId,
    required this.author,
    required this.property,
  });

  factory TripPost.fromJson(Map<String, dynamic> j) => TripPost(
        id: j['id'] as int,
        verdict: _verdictFromCode(j['verdict'] as String? ?? 'loved'),
        caption: j['caption'] as String?,
        imageUrls: ((j['image_urls'] as List?) ?? const [])
            .whereType<String>()
            .toList(),
        createdAt: DateTime.parse(j['created_at'] as String),
        propertyId: j['property_id'] as int,
        bookingId: j['booking_id'] as int,
        author: TripAuthor.fromJson(j['author'] as Map<String, dynamic>),
        property:
            TripPropertyBrief.fromJson(j['property'] as Map<String, dynamic>),
      );
}

class EligibleBooking {
  final int bookingId;
  final int propertyId;
  final String propertyName;
  final DateTime checkOut;
  EligibleBooking({
    required this.bookingId,
    required this.propertyId,
    required this.propertyName,
    required this.checkOut,
  });
  factory EligibleBooking.fromJson(Map<String, dynamic> j) => EligibleBooking(
        bookingId: j['booking_id'] as int,
        propertyId: j['property_id'] as int,
        propertyName: j['property_name'] as String? ?? '',
        checkOut: DateTime.parse(j['check_out'] as String),
      );
}

class TripPostService {
  static final _api = ApiClient();

  /// Public global feed. Returns (items, hasMore).
  static Future<List<TripPost>> feed({
    int page = 1,
    int limit = 20,
    TripVerdict? verdict,
    int? propertyId,
  }) async {
    final params = <String, String>{'page': '$page', 'limit': '$limit'};
    if (verdict != null) params['verdict'] = tripVerdictCode(verdict);
    if (propertyId != null) params['property_id'] = '$propertyId';
    final qs = params.entries.map((e) => '${e.key}=${e.value}').join('&');
    final res = await _api.get('/trip-posts?$qs');
    final map = res as Map<String, dynamic>;
    final items = (map['items'] as List)
        .map((e) => TripPost.fromJson(e as Map<String, dynamic>))
        .toList();
    return items;
  }

  static Future<List<TripPost>> mine() async {
    final res = await _api.get('/trip-posts/mine');
    return (res as List)
        .map((e) => TripPost.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<List<EligibleBooking>> eligibleBookings() async {
    final res = await _api.get('/trip-posts/eligible-bookings');
    return (res as List)
        .map((e) => EligibleBooking.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<TripPost> create({
    required int bookingId,
    required TripVerdict verdict,
    String? caption,
    List<String> imageUrls = const [],
  }) async {
    final res = await _api.post('/trip-posts', {
      'booking_id': bookingId,
      'verdict': tripVerdictCode(verdict),
      if (caption != null) 'caption': caption,
      'image_urls': imageUrls,
    });
    return TripPost.fromJson(res as Map<String, dynamic>);
  }

  static Future<void> delete(int postId) async {
    await _api.delete('/trip-posts/$postId');
  }
}
