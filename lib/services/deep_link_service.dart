import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/widgets.dart';

import 'notification_service.dart';
import 'referral_link_service.dart';

class DeepLinkService {
  DeepLinkService._();
  static final DeepLinkService instance = DeepLinkService._();

  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _subscription;
  bool _initialized = false;
  Uri? _pendingUri;
  Uri? _lastHandledUri;
  DateTime? _lastHandledAt;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        _handleUri(initialUri);
      }
    } catch (_) {}

    _subscription = _appLinks.uriLinkStream.listen(
      _handleUri,
      onError: (_) {},
    );
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
    _initialized = false;
  }

  Future<void> _handleUri(Uri uri) async {
    if (_isRecentDuplicate(uri)) return;
    final referralCode = _referralCodeFromUri(uri);
    if (referralCode != null) {
      await ReferralLinkService.saveReferralCode(referralCode);
      _openLogin();
      return;
    }
    final propertyId = _propertyIdFromUri(uri);
    if (propertyId == null) return;
    _openProperty(propertyId);
  }

  bool _isRecentDuplicate(Uri uri) {
    final now = DateTime.now();
    final lastAt = _lastHandledAt;
    if (_lastHandledUri == uri &&
        lastAt != null &&
        now.difference(lastAt) < const Duration(seconds: 2)) {
      return true;
    }
    _lastHandledUri = uri;
    _lastHandledAt = now;
    return false;
  }

  void _openProperty(int propertyId) {
    final nav = NotificationService.navigatorKey.currentState;
    if (nav == null) {
      _pendingUri = Uri.parse('talaa://properties/$propertyId');
      _flushWhenNavigatorIsReady();
      return;
    }
    nav.pushNamed('/property', arguments: {'propertyId': propertyId});
  }

  void _openLogin() {
    final nav = NotificationService.navigatorKey.currentState;
    if (nav == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _openLogin());
      return;
    }
    nav.pushNamed('/login');
  }

  void _flushWhenNavigatorIsReady() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final uri = _pendingUri;
      if (uri == null) return;
      _pendingUri = null;
      final propertyId = _propertyIdFromUri(uri);
      if (propertyId != null) {
        _openProperty(propertyId);
      }
    });
  }

  int? _propertyIdFromUri(Uri uri) {
    final scheme = uri.scheme.toLowerCase();
    final host = uri.host.toLowerCase();
    final segments = uri.pathSegments;

    if ((scheme == 'https' || scheme == 'http') &&
        (host == 'talaa.app' || host == 'www.talaa.app') &&
        segments.length >= 2 &&
        segments.first == 'p') {
      return int.tryParse(segments[1]);
    }

    if (scheme == 'talaa') {
      if (host == 'properties' && segments.isNotEmpty) {
        return int.tryParse(segments.first);
      }
      if (segments.length >= 2 && segments.first == 'properties') {
        return int.tryParse(segments[1]);
      }
    }

    return null;
  }

  String? _referralCodeFromUri(Uri uri) {
    final scheme = uri.scheme.toLowerCase();
    final host = uri.host.toLowerCase();
    final segments = uri.pathSegments;
    final code = uri.queryParameters['ref'] ??
        uri.queryParameters['referral_code'] ??
        uri.queryParameters['code'];

    if ((scheme == 'https' || scheme == 'http') &&
        (host == 'talaa.app' || host == 'www.talaa.app') &&
        segments.isNotEmpty &&
        segments.first == 'signup') {
      return code;
    }

    if (scheme == 'talaa' && host == 'signup') {
      return code ?? (segments.isNotEmpty ? segments.first : null);
    }

    return null;
  }
}
