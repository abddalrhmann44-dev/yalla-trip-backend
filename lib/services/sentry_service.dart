// ═══════════════════════════════════════════════════════════════
//  TALAA — Sentry Service
//  Crash + error reporting for the Flutter client.
// ═══════════════════════════════════════════════════════════════

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Environment hook so CI / self-built flavours can override without
/// touching source.  Pass `--dart-define=SENTRY_DSN=https://…` at
/// build time.  When empty Sentry stays disabled and `runApp` runs
/// normally.
const String _kDsn =
    String.fromEnvironment('SENTRY_DSN', defaultValue: '');

const String _kEnv =
    String.fromEnvironment('APP_ENV', defaultValue: 'production');

class SentryService {
  SentryService._();

  static bool _enabled = false;
  static bool get isEnabled => _enabled;

  /// Wrap [runner] (typically the `runApp` call) with a Sentry zone so
  /// uncaught exceptions are forwarded.  No-ops when no DSN is
  /// configured – we still call [runner] so the app boots normally.
  static Future<void> bootstrap(
    Future<void> Function() runner,
  ) async {
    if (_kDsn.isEmpty) {
      // Nothing to configure – fall straight through.
      await runner();
      return;
    }

    final pkg = await _safePackageInfo();
    await SentryFlutter.init(
      (o) {
        o.dsn = _kDsn;
        o.environment = _kEnv;
        o.release = pkg == null
            ? null
            : '${pkg.packageName}@${pkg.version}+${pkg.buildNumber}';
        o.debug = kDebugMode;
        // Tracing adds noticeable overhead on low-end devices; keep
        // it off by default and opt-in with a flag if needed.
        o.tracesSampleRate = 0.0;
        o.sendDefaultPii = false;
        // Scrub common sensitive keys from breadcrumbs + extras before
        // they leave the device.
        o.beforeSend = _scrub;
      },
      appRunner: runner,
    );
    _enabled = true;
  }

  /// Attach (or clear) the current authenticated user on the active
  /// Sentry scope.  Called after login / logout.
  static Future<void> setUser({
    required int? userId,
    String? role,
    String? email,
  }) async {
    if (!_enabled) return;
    await Sentry.configureScope((scope) async {
      if (userId == null) {
        await scope.setUser(null);
      } else {
        await scope.setUser(SentryUser(
          id: userId.toString(),
          email: email,
          data: {
            if (role != null) 'role': role,
          },
        ));
      }
    });
  }

  /// Manually report an exception that was caught by application code
  /// but still represents a bug worth investigating.
  static Future<void> captureException(
    Object error,
    StackTrace? stack, {
    Map<String, String>? tags,
  }) async {
    if (!_enabled) return;
    await Sentry.captureException(
      error,
      stackTrace: stack,
      withScope: (scope) {
        tags?.forEach(scope.setTag);
      },
    );
  }

  /// Add a breadcrumb – used by the API client to record outgoing
  /// HTTP calls before the failure point.
  static void breadcrumb({
    required String message,
    String? category,
    SentryLevel level = SentryLevel.info,
    Map<String, dynamic>? data,
  }) {
    if (!_enabled) return;
    Sentry.addBreadcrumb(Breadcrumb(
      message: message,
      category: category ?? 'app',
      level: level,
      data: data,
    ));
  }

  // ── internals ───────────────────────────────────────────
  static Future<PackageInfo?> _safePackageInfo() async {
    try {
      return await PackageInfo.fromPlatform();
    } catch (_) {
      return null;
    }
  }

  static FutureOr<SentryEvent?> _scrub(
    SentryEvent event, Hint hint,
  ) {
    // Strip sensitive keys from breadcrumbs.  Sentry Flutter already
    // redacts common HTTP auth headers, but we belt-and-brace our
    // own ``auth_token`` etc.
    const sensitive = {
      'authorization', 'cookie', 'password', 'token',
      'auth_token', 'fcm_token', 'secret', 'api_key',
      'refresh_token', 'id_token',
    };
    final crumbs = event.breadcrumbs;
    if (crumbs != null) {
      for (final c in crumbs) {
        final data = c.data;
        if (data != null) {
          for (final k in data.keys.toList()) {
            if (sensitive.contains(k.toLowerCase())) {
              data[k] = '[REDACTED]';
            }
          }
        }
      }
    }
    return event;
  }
}
