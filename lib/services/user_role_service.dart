// ═══════════════════════════════════════════════════════════════
//  TALAA — User Role Service  (REST API)
//  Single source of truth للـ role في الـ app
//
//  Now a ``ChangeNotifier`` — widgets (e.g. ``HomePage``) can listen
//  for guest⇄owner flips and swap their bottom-nav / IndexedStack
//  in place instead of pushing a separate ``HostShellPage`` route.
//  The cached role is the only mutable field; every write through
//  ``saveRole`` / ``clearCache`` calls ``notifyListeners`` so all
//  subscribers stay in sync.
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/foundation.dart';

import '../utils/api_client.dart';
import 'user_service.dart';

enum UserRole { guest, owner }

class UserRoleService extends ChangeNotifier {
  UserRoleService._();
  static final UserRoleService instance = UserRoleService._();

  static final _api = ApiClient();

  // ── Cache بعد أول load ──────────────────────────────────────
  UserRole? _cached;

  // ── Admin "shadow" guest mode ───────────────────────────────
  // Admins implicitly have owner privileges (``isOwner`` returns
  // true when the backend role is ``admin``).  When an admin taps
  // "Guest Mode" on their profile we don't want to PUT
  // ``/users/me/role`` with ``guest`` — that would silently demote
  // them and strip their admin powers on the server.  Instead we
  // flip this local flag: the UI treats them as a guest for the
  // duration of the session, but the backend role stays ``admin``.
  bool _localGuestOverride = false;

  bool get localGuestOverride => _localGuestOverride;

  void setGuestOverride(bool value) {
    if (_localGuestOverride == value) return;
    _localGuestOverride = value;
    notifyListeners();
  }

  /// Synchronous accessor for the last-known role.  Returns ``null``
  /// before the first ``getRole()`` resolves; callers that just need
  /// "guest until proven otherwise" should fall back to
  /// ``UserRole.guest``.  This lets ``HomePage.build`` decide which
  /// tab set to render without awaiting the network.
  UserRole? get cachedRole => _cached;

  /// Convenience for ``cachedRole == UserRole.owner`` — the home
  /// page reads this on every rebuild so guests don't pay for a
  /// null-check ladder.  Respects ``_localGuestOverride`` so an
  /// admin who opted into guest mode sees the guest tab set.
  bool get isOwnerSync =>
      !_localGuestOverride && _cached == UserRole.owner;

  // ── احفظ الـ role عبر API ─────────────────────────────────────
  Future<void> saveRole(UserRole role) async {
    await _api.put('/users/me/role', {'role': role.name});
    if (_cached != role) {
      _cached = role;
      notifyListeners();
    }
  }

  // ── اجيب الـ role من API ──────────────────────────────────────
  Future<UserRole> getRole() async {
    if (_cached != null) return _cached!;
    try {
      final profile = await UserService.getProfile();
      final role = profile.isOwner ? UserRole.owner : UserRole.guest;
      if (_cached != role) {
        _cached = role;
        notifyListeners();
      }
      return _cached!;
    } catch (_) {
      return UserRole.guest;
    }
  }

  // ── هل ده مالك؟ ─────────────────────────────────────────────
  Future<bool> get isOwner async => (await getRole()) == UserRole.owner;

  // ── Reset عند logout ─────────────────────────────────────────
  void clearCache() {
    final hadCache = _cached != null;
    final hadOverride = _localGuestOverride;
    _cached = null;
    _localGuestOverride = false;
    if (hadCache || hadOverride) notifyListeners();
  }
}
