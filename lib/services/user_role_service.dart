// ═══════════════════════════════════════════════════════════════
//  TALAA — User Role Service  (REST API)
//  Single source of truth للـ role في الـ app
// ═══════════════════════════════════════════════════════════════

import '../utils/api_client.dart';
import 'user_service.dart';

enum UserRole { guest, owner }

class UserRoleService {
  UserRoleService._();
  static final UserRoleService instance = UserRoleService._();

  static final _api = ApiClient();

  // ── Cache بعد أول load ──────────────────────────────────────
  UserRole? _cached;

  // ── احفظ الـ role عبر API ─────────────────────────────────────
  Future<void> saveRole(UserRole role) async {
    await _api.put('/users/me/role', {'role': role.name});
    _cached = role;
  }

  // ── اجيب الـ role من API ──────────────────────────────────────
  Future<UserRole> getRole() async {
    if (_cached != null) return _cached!;
    try {
      final profile = await UserService.getProfile();
      _cached = profile.isOwner ? UserRole.owner : UserRole.guest;
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
