// ═══════════════════════════════════════════════════════════════
//  YALLA TRIP — Admin Configuration Service
//  Manage app fee, promo codes, check admin status
// ═══════════════════════════════════════════════════════════════

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/app_config_model.dart';
import '../models/promo_code_model.dart';

class AdminConfigurationService {
  final FirebaseFirestore _db;
  AdminConfigurationService({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  // ── App Fee ───────────────────────────────────────────────

  /// Fetch current app fee percent (cached-aware)
  Future<double> getAppFeePercent() async {
    final doc = await _db.collection('appSettings').doc('config').get();
    if (!doc.exists) return 10.0; // default 10%
    return AppConfigModel.fromFirestore(doc.data()!).appFeePercent;
  }

  /// Stream for real-time fee updates
  Stream<double> appFeeStream() {
    return _db
        .collection('appSettings')
        .doc('config')
        .snapshots()
        .map((snap) {
      if (!snap.exists) return 10.0;
      return AppConfigModel.fromFirestore(snap.data()!).appFeePercent;
    });
  }

  /// Update the app fee percentage
  Future<void> updateAppFee(double percent) async {
    await _db.collection('appSettings').doc('config').set(
      {'appFeePercent': percent},
      SetOptions(merge: true),
    );
  }

  // ── Admin Check ───────────────────────────────────────────

  /// Check if given email belongs to an admin
  Future<bool> isAdmin(String email) async {
    if (email.isEmpty) return false;
    final doc =
        await _db.collection('admins').doc(email.toLowerCase()).get();
    return doc.exists;
  }

  // ── Promo Code Management ─────────────────────────────────

  Future<void> createPromoCode(PromoCodeModel promo) async {
    await _db.collection('promoCodes').add(promo.toFirestore());
  }

  Future<void> updatePromoCode(String promoId, Map<String, dynamic> data) async {
    await _db.collection('promoCodes').doc(promoId).update(data);
  }

  Future<void> deletePromoCode(String promoId) async {
    await _db.collection('promoCodes').doc(promoId).delete();
  }

  Future<void> togglePromoActive(String promoId, bool isActive) async {
    await _db
        .collection('promoCodes')
        .doc(promoId)
        .update({'isActive': isActive});
  }
}
