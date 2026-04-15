// ═══════════════════════════════════════════════════════════════
//  TALAA — User Service
//  User profile API calls (get, update, avatar, delete)
// ═══════════════════════════════════════════════════════════════

import 'dart:io';

import '../models/user_model_api.dart';
import '../utils/api_client.dart';

class UserService {
  static final _api = ApiClient();

  // ── Get current user profile ────────────────────────────────
  static Future<UserApi> getProfile() async {
    final data = await _api.get('/users/me');
    return UserApi.fromJson(data as Map<String, dynamic>);
  }

  // ── Update profile ──────────────────────────────────────────
  static Future<UserApi> updateProfile(Map<String, dynamic> updates) async {
    final data = await _api.put('/users/me', updates);
    return UserApi.fromJson(data as Map<String, dynamic>);
  }

  // ── Upload avatar ───────────────────────────────────────────
  static Future<UserApi> uploadAvatar(File image) async {
    final data = await _api.postMultipart('/users/me/avatar', [image]);
    return UserApi.fromJson(data as Map<String, dynamic>);
  }

  // ── Delete account ──────────────────────────────────────────
  static Future<void> deleteAccount() async {
    await _api.delete('/users/me');
  }
}
