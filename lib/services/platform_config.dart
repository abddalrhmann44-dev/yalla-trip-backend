import 'package:flutter/foundation.dart';

import '../utils/api_client.dart';

/// Global platform-level configuration fetched from the backend once
/// at app startup (and refreshed whenever the admin saves changes).
///
/// Accessible anywhere via the top-level [platformConfig] singleton.
/// Widgets that should rebuild when the value changes can
/// ``ListenableBuilder(listenable: platformConfig, ...)`` — the same
/// pattern used by ``appSettings``.
class PlatformConfig extends ChangeNotifier {
  double _adminFeePercent = 0.0;

  /// Administrative fee percentage charged to the guest on top of the
  /// booking subtotal.  Mirrors ``platform_settings.admin_fee_percent``
  /// in the backend.  Defaults to ``0`` until the first successful
  /// load so bookings never block on network.
  double get adminFeePercent => _adminFeePercent;

  Future<void> load() async {
    try {
      final data = await ApiClient().get('/pricing/public-settings')
          as Map<String, dynamic>;
      final pct = (data['admin_fee_percent'] as num?)?.toDouble() ?? 0.0;
      if (pct != _adminFeePercent) {
        _adminFeePercent = pct;
        notifyListeners();
      }
    } catch (_) {
      // Network/parse failures are silently swallowed — the app keeps
      // the last-known value (0 on first boot) and the booking flow
      // remains fully functional.
    }
  }
}

final platformConfig = PlatformConfig();
