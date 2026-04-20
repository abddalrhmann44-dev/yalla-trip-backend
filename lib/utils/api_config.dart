/// Backend base URL resolution order:
///   1. `--dart-define=API_BASE_URL=https://api.talaa-trip.com` (CI / release)
///   2. Platform-aware default for local dev:
///        - Android emulator → `http://10.0.2.2:8000`
///        - iOS simulator / desktop / web → `http://localhost:8000`
///
/// Usage:
///   flutter run --dart-define=API_BASE_URL=https://api.talaa-trip.com
///   flutter build apk --dart-define=API_BASE_URL=https://api.talaa-trip.com
library;

import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

class ApiConfig {
  static const String _override =
      String.fromEnvironment('API_BASE_URL', defaultValue: '');

  static String get baseUrl {
    if (_override.isNotEmpty) return _override;
    // Web / desktop dev fallback
    if (kIsWeb) return 'http://localhost:8000';
    try {
      if (Platform.isAndroid) return 'http://10.0.2.2:8000';
      return 'http://localhost:8000';
    } catch (_) {
      return 'http://localhost:8000';
    }
  }
}
