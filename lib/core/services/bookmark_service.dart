// lib/core/services/bookmark_service.dart
// ============================================================
// NOOR — Bookmark Service
// Persists a Set<String> of bookmarked profile IDs using
// SharedPreferences so bookmarks survive app restarts.
// ============================================================

import 'package:shared_preferences/shared_preferences.dart';

class BookmarkService {
  static const _kKey = 'bookmarked_ids';

  /// Loads the persisted set of bookmarked profile IDs.
  static Future<Set<String>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final list  = prefs.getStringList(_kKey) ?? [];
    return list.toSet();
  }

  /// Persists the full set of bookmarked profile IDs.
  static Future<void> save(Set<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_kKey, ids.toList());
  }
}
