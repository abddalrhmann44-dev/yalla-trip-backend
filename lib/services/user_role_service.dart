// ═══════════════════════════════════════════════════════════════
//  YALLA TRIP — User Role Service
//  Single source of truth للـ role في الـ app
// ═══════════════════════════════════════════════════════════════

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole { guest, owner }

class UserRoleService {
  UserRoleService._();
  static final UserRoleService instance = UserRoleService._();

  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  // ── Cache بعد أول load ──────────────────────────────────────
  UserRole? _cached;

  // ── احفظ الـ role في Firestore عند التسجيل ─────────────────
  Future<void> saveRole(UserRole role) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    await _db.collection('users').doc(uid).set({
      'role': role.name, // 'owner' أو 'guest'
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    _cached = role;
  }

  // ── اجيب الـ role من Firestore ──────────────────────────────
  Future<UserRole> getRole() async {
    if (_cached != null) return _cached!;
    final uid = _auth.currentUser?.uid;
    if (uid == null) return UserRole.guest;
    try {
      final doc = await _db.collection('users').doc(uid).get();
      final r = doc.data()?['role'] as String?;
      _cached = r == 'owner' ? UserRole.owner : UserRole.guest;
      return _cached!;
    } catch (_) {
      return UserRole.guest;
    }
  }

  // ── هل ده مالك؟ ─────────────────────────────────────────────
  Future<bool> get isOwner async => (await getRole()) == UserRole.owner;

  // ── Reset عند logout ─────────────────────────────────────────
  void clearCache() => _cached = null;
}
