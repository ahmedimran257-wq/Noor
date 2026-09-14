import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'supabase_service.dart';

/// Persists lightweight, non-blocking product guidance per account.
///
/// IDs are versioned so a materially redesigned journey can teach a new
/// interaction without bringing old tips back on every release. This remains
/// device-local by design and never adds a database read to app startup.
class CoachMarkService {
  CoachMarkService({String? userId})
      : _namespace = (userId ?? SupabaseService.currentUserId ?? 'signed-out')
            .replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');

  static const _version = 'v1';
  static final replayRevision = ValueNotifier<int>(0);
  final String _namespace;

  String get _prefix => 'silarah_coach_${_version}_$_namespace';
  String get _disabledKey => '${_prefix}_disabled';
  String get _replayKey => '${_prefix}_replay';
  String _seenKey(String id) => '${_prefix}_seen_$id';

  Future<bool> shouldShow(String id, {bool alreadyUsed = false}) async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(_disabledKey) != true &&
        preferences.getBool(_seenKey(id)) != true &&
        (!alreadyUsed || preferences.getBool(_replayKey) == true);
  }

  Future<void> markSeen(String id) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_seenKey(id), true);
  }

  Future<void> disableAll() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_disabledKey, true);
  }

  /// Restores the contextual guide for this account on this device.
  ///
  /// Clearing by the account-scoped prefix also covers tips introduced in a
  /// later app update without affecting another member's preferences.
  Future<void> resetAll() async {
    final preferences = await SharedPreferences.getInstance();
    final keys = preferences
        .getKeys()
        .where((key) =>
            key == _disabledKey ||
            key == _replayKey ||
            key.startsWith('${_prefix}_seen_'))
        .toList(growable: false);
    for (final key in keys) {
      await preferences.remove(key);
    }
    await preferences.setBool(_replayKey, true);
    replayRevision.value++;
  }
}
