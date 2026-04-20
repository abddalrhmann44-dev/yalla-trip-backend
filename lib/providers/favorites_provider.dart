// ═══════════════════════════════════════════════════════════════
//  TALAA — Favorites Provider
//  Single source of truth for the user's favorite property IDs.
//  Call loadIds() after login, then use isFavorite / toggle from UI.
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/foundation.dart';

import '../services/favorites_service.dart';

class FavoritesProvider extends ChangeNotifier {
  final Set<int> _ids = {};
  bool _loaded = false;
  bool _loading = false;

  // ── Getters ─────────────────────────────────────────────────
  Set<int> get ids => Set.unmodifiable(_ids);
  bool get loaded => _loaded;
  bool get loading => _loading;
  int get count => _ids.length;
  bool isFavorite(int propertyId) => _ids.contains(propertyId);

  // ── Load all favorite IDs from backend ──────────────────────
  Future<void> loadIds({bool force = false}) async {
    if (_loaded && !force) return;
    if (_loading) return;
    _loading = true;
    try {
      final set = await FavoritesService.getFavoriteIds();
      _ids
        ..clear()
        ..addAll(set);
      _loaded = true;
    } catch (e) {
      debugPrint('FavoritesProvider load error: $e');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Optimistic toggle — updates UI immediately, rolls back on failure.
  /// Returns the new state (true = now favorited).
  Future<bool> toggle(int propertyId) async {
    final wasFav = _ids.contains(propertyId);
    // Optimistic update
    if (wasFav) {
      _ids.remove(propertyId);
    } else {
      _ids.add(propertyId);
    }
    notifyListeners();

    try {
      if (wasFav) {
        await FavoritesService.remove(propertyId);
      } else {
        await FavoritesService.add(propertyId);
      }
      return !wasFav;
    } catch (e) {
      // Rollback
      if (wasFav) {
        _ids.add(propertyId);
      } else {
        _ids.remove(propertyId);
      }
      notifyListeners();
      rethrow;
    }
  }

  void clear() {
    _ids.clear();
    _loaded = false;
    notifyListeners();
  }
}
