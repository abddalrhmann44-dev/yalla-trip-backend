// ═══════════════════════════════════════════════════════════════
//  TALAA — Secure Token Storage
//  Stores access + refresh JWTs in the platform keystore:
//    • iOS      → Keychain (kSecAttrAccessibleFirstUnlock)
//    • Android  → EncryptedSharedPreferences (AES-256, MasterKey)
//  Falls back to SharedPreferences on the one-time migration path
//  so users who already have a session don't get logged out after
//  the upgrade.
// ═══════════════════════════════════════════════════════════════

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SecureTokenStorage {
  SecureTokenStorage._();

  static const _accessKey = 'auth_token';
  static const _refreshKey = 'refresh_token';
  static const _migrationDoneKey = 'secure_tokens_migrated_v1';

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  // ── Public API ──────────────────────────────────────────────

  static Future<String?> readAccessToken() async {
    await _migrateIfNeeded();
    return _storage.read(key: _accessKey);
  }

  static Future<String?> readRefreshToken() async {
    await _migrateIfNeeded();
    return _storage.read(key: _refreshKey);
  }

  static Future<void> writeTokens({
    required String accessToken,
    String? refreshToken,
  }) async {
    await _storage.write(key: _accessKey, value: accessToken);
    if (refreshToken != null) {
      await _storage.write(key: _refreshKey, value: refreshToken);
    }
  }

  static Future<void> clear() async {
    await _storage.delete(key: _accessKey);
    await _storage.delete(key: _refreshKey);
  }

  // ── One-time migration from SharedPreferences ──────────────

  /// Move any existing plaintext tokens from SharedPreferences into
  /// the secure store, then delete the plaintext copies.  Runs at
  /// most once per device thanks to the ``_migrationDoneKey`` flag.
  static Future<void> _migrateIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_migrationDoneKey) == true) return;

    final legacyAccess = prefs.getString(_accessKey);
    final legacyRefresh = prefs.getString(_refreshKey);

    if (legacyAccess != null && legacyAccess.isNotEmpty) {
      await _storage.write(key: _accessKey, value: legacyAccess);
    }
    if (legacyRefresh != null && legacyRefresh.isNotEmpty) {
      await _storage.write(key: _refreshKey, value: legacyRefresh);
    }

    // Wipe plaintext copies regardless of whether there was data
    // so a future rollback can't leave them behind.
    await prefs.remove(_accessKey);
    await prefs.remove(_refreshKey);
    await prefs.setBool(_migrationDoneKey, true);
  }
}
