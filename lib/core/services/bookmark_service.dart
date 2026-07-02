// lib/core/services/bookmark_service.dart
// ============================================================
// MITHAQ - Bookmark Service
// Persists saved profile IDs in Supabase and mirrors them locally for
// instant startup display.
// ============================================================

import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

import 'supabase_service.dart';

class BookmarkService {
  static const _kKey = 'bookmarked_ids';

  static Future<Set<String>> _cachedIds() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_kKey) ?? []).toSet();
  }

  static Future<void> _cacheIds(Set<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_kKey, ids.toList());
  }

  /// Loads saved profile user IDs. Supabase is authoritative; local cache is
  /// only used when offline/not configured so the UI can still open quickly.
  static Future<Set<String>> load() async {
    final cached = await _cachedIds();

    if (!SupabaseService.isInitialized ||
        SupabaseService.currentUserId == null) {
      return cached;
    }

    try {
      final rows = await SupabaseService.client
          .from('profile_bookmarks')
          .select('saved_user_id')
          .eq('user_id', SupabaseService.currentUserId!)
          .order('created_at', ascending: false);
      final ids = (rows as List<dynamic>)
          .map((row) => row['saved_user_id']?.toString())
          .whereType<String>()
          .toSet();
      await _cacheIds(ids);
      return ids;
    } catch (error) {
      debugPrint('[BookmarkService] Falling back to cached bookmarks: $error');
      return cached;
    }
  }

  /// Persists the full set of saved profile user IDs.
  static Future<void> save(Set<String> ids) async {
    final userId = SupabaseService.currentUserId;
    if (!SupabaseService.isInitialized || userId == null) {
      await _cacheIds(ids);
      return;
    }

    final existing = await SupabaseService.client
        .from('profile_bookmarks')
        .select('saved_user_id')
        .eq('user_id', userId);
    final existingIds = (existing as List<dynamic>)
        .map((row) => row['saved_user_id']?.toString())
        .whereType<String>()
        .toSet();

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

    await _cacheIds(ids);
  }

  /// Saves/removes one profile deterministically, avoiding stale toggle races.
  static Future<Set<String>> setSaved(String profileUserId, bool saved) async {
    final userId = SupabaseService.currentUserId;
    final ids = await _cachedIds();

    if (saved) {
      ids.add(profileUserId);
    } else {
      ids.remove(profileUserId);
    }

    if (!SupabaseService.isInitialized || userId == null) {
      await _cacheIds(ids);
      return ids;
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

    await _cacheIds(ids);
    return ids;
  }

  /// Atomic single-profile toggle used by older callers.
  static Future<Set<String>> toggle(String profileUserId) async {
    final ids = await load();
    return setSaved(profileUserId, !ids.contains(profileUserId));
  }
}
