// ═══════════════════════════════════════════════════════════════
//  TALAA — Analytics Service
// ═══════════════════════════════════════════════════════════════

import '../models/owner_analytics.dart';
import '../utils/api_client.dart';

class AnalyticsService {
  static final _api = ApiClient();

  /// Fetch the current owner's analytics.  [period] is one of
  /// `month` / `quarter` / `year`.
  static Future<OwnerAnalytics> ownerAnalytics({
    String period = 'month',
  }) async {
    final data = await _api.get('/analytics/owner?period=$period');
    return OwnerAnalytics.fromJson(data as Map<String, dynamic>);
  }
}
