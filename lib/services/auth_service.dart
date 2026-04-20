// ═══════════════════════════════════════════════════════════════
//  TALAA — Auth Service
//  Exchanges Firebase token for backend JWT, stores tokens
// ═══════════════════════════════════════════════════════════════

import 'dart:convert';

import 'package:http/http.dart' as http;

import '../utils/api_client.dart';
import '../utils/api_config.dart';

class AuthService {
  static final _api = ApiClient();

  /// After Firebase sign-in, call this to exchange the Firebase ID token
  /// for a backend JWT and store it for future API calls.  The refresh
  /// token is also persisted so the client can silently rotate when
  /// the access token expires without re-prompting Firebase.
  static Future<void> exchangeFirebaseToken(String firebaseIdToken) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/auth/verify-token'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'firebase_token': firebaseIdToken}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final accessToken = data['access_token'] as String;
      final refreshToken = data['refresh_token'] as String?;
      await _api.setToken(accessToken, refreshToken: refreshToken);
    } else {
      final detail = _tryParseDetail(response.body);
      throw Exception(
          'Auth exchange failed: ${response.statusCode} — $detail');
    }
  }

  /// Rotate the stored refresh token against the backend.
  ///
  /// Returns ``true`` on success (new access + refresh are now stored)
  /// and ``false`` if there's no refresh token available or the server
  /// rejected it (caller should trigger a fresh sign-in).
  static Future<bool> tryRefresh() async {
    final refresh = await _api.getRefreshToken();
    if (refresh == null || refresh.isEmpty) return false;
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/auth/refresh'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refresh_token': refresh}),
      );
      if (response.statusCode != 200) return false;
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final accessToken = data['access_token'] as String;
      final newRefresh = data['refresh_token'] as String?;
      await _api.setToken(accessToken, refreshToken: newRefresh);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Extract server detail from JSON response body (for logging).
  static String _tryParseDetail(String body) {
    try {
      final j = jsonDecode(body);
      if (j is Map) return j['detail']?.toString() ?? body;
    } catch (_) {}
    return body;
  }

  /// Revoke the current session on the server (best-effort) and clear
  /// local tokens.  Swallows network errors — logout must always
  /// succeed from the user's perspective.
  static Future<void> logout() async {
    final refresh = await _api.getRefreshToken();
    if (refresh != null && refresh.isNotEmpty) {
      try {
        await _api.post('/auth/logout', {'refresh_token': refresh});
      } catch (_) {
        // Best-effort – stale/expired tokens are fine to ignore here.
      }
    }
    await _api.clearToken();
  }
}
