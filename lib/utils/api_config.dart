/// Backend base URL resolution order:
///   1. `--dart-define=API_BASE_URL=https://...` (CI / staging override)
///   2. Default → Railway production deployment (debug *and* release).
///
/// We intentionally do **not** auto-fallback to localhost in debug
/// mode anymore — the team has had multiple incidents where phone
/// login silently hit a stale local backend during dev builds.  If
/// you genuinely want to test against a local FastAPI instance, run:
///
///   flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000
///   flutter run --dart-define=API_BASE_URL=http://localhost:8000
library;

class ApiConfig {
  /// Production backend (Railway).  Override with `--dart-define`
  /// when pointing the app at a staging or local host.
  static const String _prodUrl =
      'https://yalla-trip-backend-production.up.railway.app';

  static const String _override =
      String.fromEnvironment('API_BASE_URL', defaultValue: '');

  static String get baseUrl {
    if (_override.isNotEmpty) return _override;
    return _prodUrl;
  }
}
