// ═══════════════════════════════════════════════════════════════
//  TALAA — Promo Code Service
//  User: validate a code before checkout.
//  Admin: full CRUD + usage stats.
// ═══════════════════════════════════════════════════════════════

import '../utils/api_client.dart';

enum PromoType { percent, fixed }

extension PromoTypeCode on PromoType {
  String get code => name;
  String get labelAr => this == PromoType.percent ? 'نسبة %' : 'مبلغ ثابت';
}

class PromoValidation {
  final bool valid;
  final String code;
  final double discountAmount;
  final double finalAmount;
  final String? reason;
  final String? reasonAr;

  PromoValidation({
    required this.valid,
    required this.code,
    required this.discountAmount,
    required this.finalAmount,
    this.reason,
    this.reasonAr,
  });

  factory PromoValidation.fromJson(Map<String, dynamic> j) => PromoValidation(
        valid: j['valid'] as bool,
        code: j['code'] as String,
        discountAmount: (j['discount_amount'] as num).toDouble(),
        finalAmount: (j['final_amount'] as num).toDouble(),
        reason: j['reason'] as String?,
        reasonAr: j['reason_ar'] as String?,
      );
}

class PromoCodeModel {
  final int id;
  final String code;
  final String? description;
  final PromoType type;
  final double value;
  final double? maxDiscount;
  final double? minBookingAmount;
  final int? maxUses;
  final int? maxUsesPerUser;
  final int usesCount;
  final DateTime? validFrom;
  final DateTime? validUntil;
  final bool isActive;
  final DateTime createdAt;

  PromoCodeModel({
    required this.id,
    required this.code,
    required this.description,
    required this.type,
    required this.value,
    required this.maxDiscount,
    required this.minBookingAmount,
    required this.maxUses,
    required this.maxUsesPerUser,
    required this.usesCount,
    required this.validFrom,
    required this.validUntil,
    required this.isActive,
    required this.createdAt,
  });

  factory PromoCodeModel.fromJson(Map<String, dynamic> j) => PromoCodeModel(
        id: j['id'] as int,
        code: j['code'] as String,
        description: j['description'] as String?,
        type: PromoType.values.firstWhere((t) => t.name == j['type']),
        value: (j['value'] as num).toDouble(),
        maxDiscount: (j['max_discount'] as num?)?.toDouble(),
        minBookingAmount: (j['min_booking_amount'] as num?)?.toDouble(),
        maxUses: j['max_uses'] as int?,
        maxUsesPerUser: j['max_uses_per_user'] as int?,
        usesCount: j['uses_count'] as int,
        validFrom: j['valid_from'] != null
            ? DateTime.parse(j['valid_from'] as String)
            : null,
        validUntil: j['valid_until'] != null
            ? DateTime.parse(j['valid_until'] as String)
            : null,
        isActive: j['is_active'] as bool,
        createdAt: DateTime.parse(j['created_at'] as String),
      );

  /// Human-readable discount preview, e.g. "10%" or "50 جنيه".
  String get displayValue {
    if (type == PromoType.percent) {
      return '${value.toStringAsFixed(value.truncateToDouble() == value ? 0 : 1)}%';
    }
    return '${value.toStringAsFixed(0)} جنيه';
  }

  bool get isExhausted => maxUses != null && usesCount >= maxUses!;
}

class PromoCodeService {
  static final _api = ApiClient();

  /// Validate a user-entered code against a booking amount (preview).
  /// Returns the server's decision including discount + final amount.
  static Future<PromoValidation> validate({
    required String code,
    required double bookingAmount,
  }) async {
    final res = await _api.post('/promo-codes/validate', {
      'code': code.trim(),
      'booking_amount': bookingAmount,
    });
    return PromoValidation.fromJson(res as Map<String, dynamic>);
  }

  // ── Admin endpoints ──────────────────────────────────────
  static Future<List<PromoCodeModel>> adminList({
    bool? isActive,
    String? search,
    int limit = 50,
    int offset = 0,
  }) async {
    final qp = <String, String>{
      'limit': '$limit',
      'offset': '$offset',
      if (isActive != null) 'is_active': '$isActive',
      if (search != null && search.isNotEmpty) 'search': search,
    };
    final query = qp.entries.map((e) => '${e.key}=${e.value}').join('&');
    final res = await _api.get('/promo-codes/admin?$query');
    return (res as List)
        .map((e) => PromoCodeModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<PromoCodeModel> adminCreate({
    required String code,
    required PromoType type,
    required double value,
    String? description,
    double? maxDiscount,
    double? minBookingAmount,
    int? maxUses,
    int? maxUsesPerUser,
    DateTime? validFrom,
    DateTime? validUntil,
    bool isActive = true,
  }) async {
    final body = <String, dynamic>{
      'code': code.trim().toUpperCase(),
      'type': type.code,
      'value': value,
      'is_active': isActive,
      if (description != null) 'description': description,
      if (maxDiscount != null) 'max_discount': maxDiscount,
      if (minBookingAmount != null) 'min_booking_amount': minBookingAmount,
      if (maxUses != null) 'max_uses': maxUses,
      if (maxUsesPerUser != null) 'max_uses_per_user': maxUsesPerUser,
      if (validFrom != null) 'valid_from': validFrom.toUtc().toIso8601String(),
      if (validUntil != null) 'valid_until': validUntil.toUtc().toIso8601String(),
    };
    final res = await _api.post('/promo-codes/admin', body);
    return PromoCodeModel.fromJson(res as Map<String, dynamic>);
  }

  static Future<PromoCodeModel> adminUpdate(
    int id, {
    bool? isActive,
    double? value,
    int? maxUses,
    DateTime? validUntil,
  }) async {
    final body = <String, dynamic>{
      if (isActive != null) 'is_active': isActive,
      if (value != null) 'value': value,
      if (maxUses != null) 'max_uses': maxUses,
      if (validUntil != null)
        'valid_until': validUntil.toUtc().toIso8601String(),
    };
    final res = await _api.patch('/promo-codes/admin/$id', body);
    return PromoCodeModel.fromJson(res as Map<String, dynamic>);
  }

  /// Hard-delete a code (cascades to its redemption rows).
  static Future<void> adminDelete(int id) async {
    await _api.delete('/promo-codes/admin/$id');
  }

  static Future<Map<String, dynamic>> adminStatsOverview() async {
    final res = await _api.get('/promo-codes/admin/stats/overview');
    return res as Map<String, dynamic>;
  }
}
