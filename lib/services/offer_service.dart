// ═══════════════════════════════════════════════════════════════
//  TALAA — Offer Service
//  CRUD for time-limited promotional offers via REST API
// ═══════════════════════════════════════════════════════════════

import '../utils/api_client.dart';

class OfferItem {
  final int propertyId;
  final String propertyName;
  final double offerPrice;
  final DateTime offerStart;
  final DateTime offerEnd;
  final double originalPrice;
  final int discountPercent;
  final bool isActive;

  OfferItem({
    required this.propertyId,
    required this.propertyName,
    required this.offerPrice,
    required this.offerStart,
    required this.offerEnd,
    required this.originalPrice,
    required this.discountPercent,
    required this.isActive,
  });

  factory OfferItem.fromJson(Map<String, dynamic> json) {
    return OfferItem(
      propertyId: json['property_id'] as int,
      propertyName: json['property_name'] as String,
      offerPrice: (json['offer_price'] as num).toDouble(),
      offerStart: DateTime.parse(json['offer_start'] as String),
      offerEnd: DateTime.parse(json['offer_end'] as String),
      originalPrice: (json['original_price'] as num).toDouble(),
      discountPercent: json['discount_percent'] as int? ?? 0,
      isActive: json['is_active'] as bool? ?? false,
    );
  }
}

class OfferService {
  static final _api = ApiClient();

  static Future<List<OfferItem>> getMyOffers() async {
    final data = await _api.get('/offers/my');
    return (data as List).map((e) => OfferItem.fromJson(e)).toList();
  }

  static Future<OfferItem> createOffer({
    required int propertyId,
    required double offerPrice,
    required DateTime offerStart,
    required DateTime offerEnd,
  }) async {
    final data = await _api.post('/offers/$propertyId', {
      'offer_price': offerPrice,
      'offer_start': offerStart.toUtc().toIso8601String(),
      'offer_end': offerEnd.toUtc().toIso8601String(),
    });
    return OfferItem.fromJson(data as Map<String, dynamic>);
  }

  static Future<void> cancelOffer(int propertyId) async {
    await _api.delete('/offers/$propertyId');
  }
}
