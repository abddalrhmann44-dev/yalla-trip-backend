/// Backend base URL resolution order:
///   1. `--dart-define=API_BASE_URL=https://...` (CI / staging override)
///   2. Release build → Railway production deployment
///   3. Debug build → platform-aware local dev fallbacks
///        - Android emulator → `http://10.0.2.2:8000`
///        - iOS simulator / desktop / web → `http://localhost:8000`
///
/// Usage:
///   flutter run                                        # debug → localhost
///   flutter run --release                              # → Railway prod
///   flutter run --dart-define=API_BASE_URL=https://staging.example.com
///   flutter build apk --release                        # → Railway prod
library;

import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;

class ApiConfig {
  /// Production backend (Railway).  Override with `--dart-define`
  /// when pointing the app at a staging host.
  static const String _prodUrl =
      'https://yalla-trip-backend-production.up.railway.app';

  static const String _override =
      String.fromEnvironment('API_BASE_URL', defaultValue: '');

  static String get baseUrl {
    if (_override.isNotEmpty) return _override;

    // Release builds always hit the deployed API.
    if (!kDebugMode) return _prodUrl;

    // Debug builds — platform-aware localhost fallbacks.
    if (kIsWeb) return 'http://localhost:8000';
    try {
      if (Platform.isAndroid) return 'http://10.0.2.2:8000';
      return 'http://localhost:8000';
    } catch (_) {
      return 'http://localhost:8000';
    }
  }
}
