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
  /// for a backend JWT and store it for future API calls.
  static Future<void> exchangeFirebaseToken(String firebaseIdToken) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/auth/verify-token'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'firebase_token': firebaseIdToken}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final accessToken = data['access_token'] as String;
      await _api.setToken(accessToken);
    } else {
      throw Exception('Auth exchange failed: ${response.statusCode}');
    }
  }

  /// Clear stored tokens on logout.
  static Future<void> logout() async {
    await _api.clearToken();
  }
}
