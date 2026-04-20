// ═══════════════════════════════════════════════════════════════
//  TALAA — Device Service
//  Register / unregister push devices against /devices on the backend.
// ═══════════════════════════════════════════════════════════════

import 'dart:io' show Platform;

import 'package:package_info_plus/package_info_plus.dart';

import '../utils/api_client.dart';

class DeviceService {
  static final _api = ApiClient();

  /// Register (or refresh) the current device's FCM token with the
  /// backend.  Safe to call multiple times – the endpoint is
  /// idempotent and bumps ``last_seen_at`` on duplicate tokens.
  static Future<void> register(String fcmToken) async {
    final info = await PackageInfo.fromPlatform();
    await _api.post('/devices', {
      'token': fcmToken,
      'platform': _platformName(),
      'app_version': '${info.version}+${info.buildNumber}',
    });
  }

  /// Clear every push target for the current user.  Called on sign-out
  /// so notifications stop going to a device the user no longer uses.
  static Future<void> unregisterAll() async {
    try {
      await _api.delete('/devices');
    } catch (_) {
      // Best-effort – never break the sign-out flow on network errors.
    }
  }

  static String _platformName() {
    if (Platform.isIOS) return 'ios';
    if (Platform.isAndroid) return 'android';
    return 'web';
  }
}
