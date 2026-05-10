// ═══════════════════════════════════════════════════════════════
//  TALAA — Auth Service
//  Exchanges Firebase token for backend JWT, stores tokens
// ═══════════════════════════════════════════════════════════════

import 'dart:convert';

import 'package:http/http.dart' as http;

import '../utils/api_client.dart';
import '../utils/api_config.dart';
import 'referral_link_service.dart';

class AuthService {
  static final _api = ApiClient();

  /// After Firebase sign-in, call this to exchange the Firebase ID token
  /// for a backend JWT and store it for future API calls.  The refresh
  /// token is also persisted so the client can silently rotate when
  /// the access token expires without re-prompting Firebase.
  static Future<void> exchangeFirebaseToken(
    String firebaseIdToken, {
    String? referralCode,
  }) async {
    final pendingReferralCode =
        referralCode ?? await ReferralLinkService.getPendingReferralCode();
    final body = <String, dynamic>{
      'firebase_token': firebaseIdToken,
      if (pendingReferralCode != null && pendingReferralCode.isNotEmpty)
        'referral_code': pendingReferralCode,
    };
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/auth/verify-token'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final accessToken = data['access_token'] as String;
      final refreshToken = data['refresh_token'] as String?;
      await _api.setToken(accessToken, refreshToken: refreshToken);
      if (pendingReferralCode != null && pendingReferralCode.isNotEmpty) {
        await ReferralLinkService.clearPendingReferralCode();
      }
    } else {
      final detail = _tryParseDetail(response.body);
      throw Exception(
          'Auth exchange failed: ${response.statusCode} — $detail');
    }
  }

  /// Ask the backend to send a WhatsApp OTP to ``phone`` for the
  /// public login / register flow.  Returns ``null`` on success or
  /// a human-readable error message on failure.
  ///
  /// Hits ``POST /auth/whatsapp/start-otp``.  No auth required —
  /// this is the very first call in the sign-in funnel.
  static Future<String?> startWhatsappOtp(String phone) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/auth/whatsapp/start-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phone': phone}),
      );
      if (response.statusCode == 200) return null;
      return _tryParseDetail(response.body);
    } catch (e) {
      return 'Network error: $e';
    }
  }

  /// Verify the WhatsApp OTP and exchange the result for a backend
  /// JWT pair.  On success the access + refresh tokens are stored
  /// (just like [exchangeFirebaseToken]) and the method returns
  /// ``(isNewUser: bool, errorMessage: null)``; on failure it returns
  /// ``(isNewUser: false, errorMessage: '<reason>')`` without
  /// touching the stored tokens.
  ///
  /// Hits ``POST /auth/whatsapp/verify-otp``.
  static Future<({bool isNewUser, String? error})> verifyWhatsappOtp({
    required String phone,
    required String code,
    String name = '',
    String? referralCode,
  }) async {
    try {
      final pendingReferralCode =
          referralCode ?? await ReferralLinkService.getPendingReferralCode();
      final body = <String, dynamic>{
        'phone': phone,
        'code': code,
        'name': name,
        if (pendingReferralCode != null && pendingReferralCode.isNotEmpty)
          'referral_code': pendingReferralCode,
      };
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/auth/whatsapp/verify-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );
      if (response.statusCode != 200) {
        return (isNewUser: false, error: _tryParseDetail(response.body));
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final accessToken = data['access_token'] as String;
      final refreshToken = data['refresh_token'] as String?;
      await _api.setToken(accessToken, refreshToken: refreshToken);
      if (pendingReferralCode != null && pendingReferralCode.isNotEmpty) {
        await ReferralLinkService.clearPendingReferralCode();
      }
      // Heuristic: a brand-new user has the placeholder name "User"
      // (the backend assigns it when no name is supplied) AND no
      // email yet.  The dedicated [RegisterPage] then collects the
      // real profile data.
      final user = data['user'] as Map<String, dynamic>?;
      final displayName = (user?['name'] as String?)?.trim() ?? '';
      final emailValue = (user?['email'] as String?)?.trim() ?? '';
      final isNew = (displayName.isEmpty || displayName == 'User') &&
          emailValue.isEmpty;
      return (isNewUser: isNew, error: null);
    } catch (e) {
      return (isNewUser: false, error: 'Network error: $e');
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
