// ══════════════════════════════════════════════════════════════════
//  Recently Viewed Service (Wave 28)
//
//  Local-only memory of the last few property IDs the guest opened
//  in the details page.  Backed by SharedPreferences so it survives
//  app restarts but is intentionally NOT synced to the server —
//  guests' browsing trail stays on-device.
//
//  Usage:
//    await RecentlyViewedService.instance.markViewed(propertyId);
//    final ids = await RecentlyViewedService.instance.getIds();
//
//  The home page reads ``getIds()`` and intersects it with the
//  current PropertyApi list to render the horizontal "اللي شوفتهم
//  مؤخراً" row underneath the Offers section.
// ══════════════════════════════════════════════════════════════════

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class RecentlyViewedService {
  RecentlyViewedService._();
  static final RecentlyViewedService instance = RecentlyViewedService._();

  /// Store key in SharedPreferences.  Versioned so we can change the
  /// payload format later without crashing on stale entries.
  static const _kKey = 'recently_viewed_v1';

  /// How many properties we remember per user.  Anything older drops
  /// off the tail when [markViewed] is called.
  static const int kMaxEntries = 10;

  /// Push [propertyId] to the front of the recents list.  De-dupes
  /// (so re-viewing a property only refreshes its position) and
  /// trims the tail to [kMaxEntries] entries.
  Future<void> markViewed(int propertyId) async {
    if (propertyId <= 0) return;
    final prefs = await SharedPreferences.getInstance();
    final ids = _decode(prefs.getString(_kKey));
    ids.remove(propertyId);
    ids.insert(0, propertyId);
    if (ids.length > kMaxEntries) {
      ids.removeRange(kMaxEntries, ids.length);
    }
    await prefs.setString(_kKey, jsonEncode(ids));
  }

  /// Returns the property IDs the user opened recently, most-recent
  /// first.  Empty list when there are no recents or the cache got
  /// corrupted.
  Future<List<int>> getIds() async {
    final prefs = await SharedPreferences.getInstance();
    return _decode(prefs.getString(_kKey));
  }

  /// Wipes the recents.  Wired to the "clear browsing history" tile
  /// in the profile page (Wave 28+).
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kKey);
  }

  // ── Internal ────────────────────────────────────────────────
  List<int> _decode(String? raw) {
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .map((e) => e is int ? e : int.tryParse('$e'))
          .whereType<int>()
          .toList();
    } catch (_) {
      // Corrupted entry — ignore so the app keeps booting.
      return [];
    }
  }
}
