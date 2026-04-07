// ═══════════════════════════════════════════════════════════════
//  YALLA TRIP — Promo Code Model
// ═══════════════════════════════════════════════════════════════

import 'package:cloud_firestore/cloud_firestore.dart';

class PromoCodeModel {
  final String id;
  final String code;
  final double discountPercent;
  final bool isActive;
  final DateTime expiryDate;
  final DateTime createdAt;
  final int usageCount;
  final int? maxUsage; // null = unlimited

  const PromoCodeModel({
    required this.id,
    required this.code,
    required this.discountPercent,
    required this.isActive,
    required this.expiryDate,
    required this.createdAt,
    this.usageCount = 0,
    this.maxUsage,
  });

  bool get isExpired => DateTime.now().isAfter(expiryDate);
  bool get isValid => isActive && !isExpired && (maxUsage == null || usageCount < maxUsage!);

  factory PromoCodeModel.fromFirestore(String docId, Map<String, dynamic> d) {
    return PromoCodeModel(
      id: docId,
      code: (d['code'] ?? '').toString().toUpperCase(),
      discountPercent: (d['discountPercent'] ?? 0).toDouble(),
      isActive: d['isActive'] ?? false,
      expiryDate: (d['expiryDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      usageCount: (d['usageCount'] ?? 0).toInt(),
      maxUsage: d['maxUsage']?.toInt(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'code': code.toUpperCase(),
        'discountPercent': discountPercent,
        'isActive': isActive,
        'expiryDate': Timestamp.fromDate(expiryDate),
        'createdAt': FieldValue.serverTimestamp(),
        'usageCount': usageCount,
        'maxUsage': maxUsage,
      };
}
