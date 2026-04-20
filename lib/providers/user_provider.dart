// ═══════════════════════════════════════════════════════════════
//  TALAA — User Provider
//  Single source of truth for current user data across all pages
// ═══════════════════════════════════════════════════════════════

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model_api.dart';
import '../services/user_service.dart';
import '../services/auth_service.dart';
import '../services/sentry_service.dart';
import '../utils/api_client.dart';

class UserProvider extends ChangeNotifier {
  UserApi? _user;
  bool _loading = false;
  String? _error;

  // ── Getters ──────────────────────────────────────────────────
  UserApi? get user => _user;
  bool get loading => _loading;
  String? get error => _error;
  bool get hasUser => _user != null;

  String get name {
    if (_user != null && _user!.name.isNotEmpty) return _user!.name;
    return _firebaseName;
  }

  String get email {
    if (_user?.email != null && _user!.email!.isNotEmpty) return _user!.email!;
    return _firebaseEmail;
  }

  String get phone => _user?.phone ?? '';
  String? get avatarUrl => _user?.avatarUrl ?? _firebasePhoto;
  bool get isOwner => _user?.isOwner ?? false;
  bool get isAdmin => _user?.isAdmin ?? false;
  bool get isVerified => _user?.isVerified ?? false;
  bool get phoneVerified => _user?.phoneVerified ?? false;

  // ── Firebase Auth fallback values ────────────────────────────
  String get _firebaseName =>
      FirebaseAuth.instance.currentUser?.displayName ?? '';
  String get _firebaseEmail =>
      FirebaseAuth.instance.currentUser?.email ?? '';
  String? get _firebasePhoto =>
      FirebaseAuth.instance.currentUser?.photoURL;

  // ── Load profile from API (auto-refreshes JWT on 401) ────────
  Future<void> loadProfile({bool force = false}) async {
    if (_loading) return;
    if (_user != null && !force) return;

    _loading = true;
    _error = null;
    notifyListeners();

    try {
      _user = await _fetchWithAutoRefresh();
      _error = null;
      // Tag Sentry with the authenticated user so crashes are
      // attributed correctly.  No-op when Sentry is disabled.
      final u = _user;
      if (u != null) {
        unawaited(SentryService.setUser(
          userId: u.id,
          role: u.role,
          email: u.email,
        ));
      }
    } catch (e) {
      _error = e.toString();
      debugPrint('UserProvider load error: $e');
      // Even on failure, name/email getters fall back to Firebase Auth
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  // ── Try API call; on 401 refresh JWT and retry once ──────────
  Future<UserApi> _fetchWithAutoRefresh() async {
    try {
      return await UserService.getProfile();
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        // Token expired — refresh from Firebase and retry
        final fbUser = FirebaseAuth.instance.currentUser;
        if (fbUser != null) {
          final idToken = await fbUser.getIdToken(true);
          if (idToken != null) {
            await AuthService.exchangeFirebaseToken(idToken);
            return await UserService.getProfile();
          }
        }
      }
      rethrow;
    }
  }

  // ── Update profile (name, email, phone) ──────────────────────
  Future<void> updateProfile(Map<String, dynamic> updates) async {
    final updated = await UserService.updateProfile(updates);
    _user = updated;
    notifyListeners();
  }

  // ── Upload avatar ────────────────────────────────────────────
  Future<void> uploadAvatar(File image) async {
    final updated = await UserService.uploadAvatar(image);
    _user = updated;
    notifyListeners();
  }

  // ── Clear on logout ──────────────────────────────────────────
  void clear() {
    _user = null;
    _loading = false;
    _error = null;
    unawaited(SentryService.setUser(userId: null));
    notifyListeners();
  }
}
