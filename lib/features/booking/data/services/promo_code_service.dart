// ═══════════════════════════════════════════════════════════════
//  YALLA TRIP — Promo Code Service
//  Validate and fetch promo codes from Firestore
// ═══════════════════════════════════════════════════════════════

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/promo_code_model.dart';

class PromoCodeService {
  final FirebaseFirestore _db;
  PromoCodeService({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  // ── Validate a promo code ─────────────────────────────────
  /// Returns the PromoCodeModel if valid, throws on error.
  Future<PromoCodeModel> validatePromo(String code) async {
    if (code.trim().isEmpty) {
      throw PromoException('الكود فارغ');
    }

    final snap = await _db
        .collection('promoCodes')
        .where('code', isEqualTo: code.trim().toUpperCase())
        .limit(1)
        .get();

    if (snap.docs.isEmpty) {
      throw PromoException('الكود غير موجود');
    }

    final promo = PromoCodeModel.fromFirestore(
        snap.docs.first.id, snap.docs.first.data());

    if (!promo.isActive) {
      throw PromoException('الكود غير نشط');
    }

    if (promo.isExpired) {
      throw PromoException('الكود منتهي الصلاحية');
    }

    if (promo.maxUsage != null && promo.usageCount >= promo.maxUsage!) {
      throw PromoException('الكود تم استخدامه بالكامل');
    }

    return promo;
  }

  // ── Get a single promo by ID ──────────────────────────────
  Future<PromoCodeModel?> getPromo(String promoId) async {
    final doc = await _db.collection('promoCodes').doc(promoId).get();
    if (!doc.exists) return null;
    return PromoCodeModel.fromFirestore(doc.id, doc.data()!);
  }

  // ── Stream all promos (admin) ─────────────────────────────
  Stream<List<PromoCodeModel>> allPromosStream() {
    return _db
        .collection('promoCodes')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => PromoCodeModel.fromFirestore(d.id, d.data()))
            .toList());
  }
}

/// Custom exception for promo validation errors
class PromoException implements Exception {
  final String message;
  const PromoException(this.message);
  @override
  String toString() => message;
}
