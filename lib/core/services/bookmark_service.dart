// lib/core/services/bookmark_service.dart
// ============================================================
// SILARAH - Bookmark Service
// Persists saved profile IDs in Supabase.
// ============================================================

import 'supabase_service.dart';

class BookmarkService {
  static const _freshness = Duration(minutes: 5);
  static String? _cachedUserId;
  static Set<String>? _cachedIds;
  static DateTime? _cachedAt;
  static Future<Set<String>>? _loadInFlight;

  /// Loads saved profile user IDs from the server. Bookmarks are account data,
  /// so production must not fall back to device-local state.
  static Future<Set<String>> load({bool force = false}) async {
    final userId = await SupabaseService.currentUserIdOrRefresh();
    if (!SupabaseService.isInitialized || userId == null) {
      throw StateError('Please sign in again to load saved profiles.');
    }

    final cachedAt = _cachedAt;
    if (!force &&
        _cachedUserId == userId &&
        _cachedIds != null &&
        cachedAt != null &&
        DateTime.now().difference(cachedAt) < _freshness) {
      return Set<String>.from(_cachedIds!);
    }
    final activeLoad = _loadInFlight;
    if (activeLoad != null && _cachedUserId == userId) return activeLoad;

    final request = _loadFromServer(userId);
    _cachedUserId = userId;
    _loadInFlight = request;
    try {
      return await request;
    } finally {
      if (identical(_loadInFlight, request)) _loadInFlight = null;
    }
  }

  static Future<Set<String>> _loadFromServer(String userId) async {
    final rows = await SupabaseService.client
        .from('profile_bookmarks')
        .select('saved_user_id')
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    final ids = (rows as List<dynamic>)
        .map((row) => row['saved_user_id']?.toString())
        .whereType<String>()
        .toSet();
    _cachedIds = ids;
    _cachedAt = DateTime.now();
    return Set<String>.from(ids);
  }

  /// Persists the full set of saved profile user IDs.
  static Future<void> save(Set<String> ids) async {
    final userId = await SupabaseService.currentUserIdOrRefresh();
    if (!SupabaseService.isInitialized || userId == null) {
      throw StateError('Please sign in again to save profiles.');
    }

    final existingIds = await load();

    final toAdd = ids.difference(existingIds);
    final toRemove = existingIds.difference(ids);

    if (toAdd.isNotEmpty) {
      await SupabaseService.client.from('profile_bookmarks').upsert(
            toAdd
                .map((id) => {
                      'user_id': userId,
                      'saved_user_id': id,
                    })
                .toList(),
            onConflict: 'user_id,saved_user_id',
          );
    }

    if (toRemove.isNotEmpty) {
      await SupabaseService.client
          .from('profile_bookmarks')
          .delete()
          .eq('user_id', userId)
          .inFilter('saved_user_id', toRemove.toList());
    }
    _setCache(userId, ids);
  }

  /// Saves/removes one profile deterministically, avoiding stale toggle races.
  static Future<Set<String>> setSaved(String profileUserId, bool saved) async {
    final userId = await SupabaseService.currentUserIdOrRefresh();

    if (!SupabaseService.isInitialized || userId == null) {
      throw StateError('Please sign in again to save profiles.');
    }

    if (saved) {
      await SupabaseService.client.from('profile_bookmarks').upsert(
        {
          'user_id': userId,
          'saved_user_id': profileUserId,
        },
        onConflict: 'user_id,saved_user_id',
      );
    } else {
      await SupabaseService.client
          .from('profile_bookmarks')
          .delete()
          .eq('user_id', userId)
          .eq('saved_user_id', profileUserId);
    }

    final next = await load();
    saved ? next.add(profileUserId) : next.remove(profileUserId);
    _setCache(userId, next);
    return next;
  }

  /// Atomic single-profile toggle used by older callers.
  static Future<Set<String>> toggle(String profileUserId) async {
    final ids = await load();
    return setSaved(profileUserId, !ids.contains(profileUserId));
  }

  static void _setCache(String userId, Set<String> ids) {
    _cachedUserId = userId;
    _cachedIds = Set<String>.from(ids);
    _cachedAt = DateTime.now();
  }

  static void clearCache() {
    _cachedUserId = null;
    _cachedIds = null;
    _cachedAt = null;
    _loadInFlight = null;
  }
}
