// ═══════════════════════════════════════════════════════════════
//  TALAA — Favorites Service
//  REST calls for wishlist management (/favorites/*)
// ═══════════════════════════════════════════════════════════════

import '../models/property_model_api.dart';
import '../utils/api_client.dart';

class FavoritesService {
  static final _api = ApiClient();

  /// Full property objects the user has favorited (for the Favorites tab).
  static Future<List<PropertyApi>> getFavorites() async {
    final data = await _api.get('/favorites');
    return (data as List)
        .map((e) => PropertyApi.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Cheap call — only returns the IDs. Used on app start to populate
  /// the FavoritesProvider so heart icons render correctly everywhere.
  static Future<Set<int>> getFavoriteIds() async {
    final data = await _api.get('/favorites/ids');
    return (data as List).map((e) => e as int).toSet();
  }

  /// Idempotent — safe to call even if already favorited.
  static Future<void> add(int propertyId) async {
    await _api.post('/favorites/$propertyId', {});
  }

  static Future<void> remove(int propertyId) async {
    await _api.delete('/favorites/$propertyId');
  }
}
