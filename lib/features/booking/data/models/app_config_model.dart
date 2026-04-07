// ═══════════════════════════════════════════════════════════════
//  YALLA TRIP — App Configuration Model
//  Holds admin-configurable app settings (fee %, etc.)
// ═══════════════════════════════════════════════════════════════

class AppConfigModel {
  final double appFeePercent;

  const AppConfigModel({this.appFeePercent = 10.0});

  factory AppConfigModel.fromFirestore(Map<String, dynamic> d) {
    return AppConfigModel(
      appFeePercent: (d['appFeePercent'] ?? 10.0).toDouble(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'appFeePercent': appFeePercent,
      };
}

/// Result of the pricing calculation — immutable snapshot
class PricingResult {
  final double basePrice;
  final double discount;
  final double subtotal;
  final double appFee;
  final double ownerEarnings;
  final double appFeePercent;
  final double promoPercent;

  const PricingResult({
    required this.basePrice,
    required this.discount,
    required this.subtotal,
    required this.appFee,
    required this.ownerEarnings,
    required this.appFeePercent,
    required this.promoPercent,
  });
}
