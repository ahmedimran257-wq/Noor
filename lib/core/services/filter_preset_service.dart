// lib/core/services/filter_preset_service.dart
// ============================================================
// MITHAQ — Filter Preset Service (Feature 9)
// Persists up to 3 named DiscoveryFilter presets via
// shared_preferences as JSON.
// ============================================================

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../cubits/discovery/discovery_filter.dart';

class FilterPreset {
  const FilterPreset({required this.name, required this.filter});

  final String          name;
  final DiscoveryFilter filter;

  Map<String, dynamic> toJson() => {
    'name':               name,
    'ageMin':             filter.ageMin,
    'ageMax':             filter.ageMax,
    'sect':               filter.sect,
    'deenLevel':          filter.deenLevel,
    'verifiedOnly':       filter.verifiedOnly,
    'activeRecentlyOnly': filter.activeRecentlyOnly,
    'maxDistanceKm':      filter.maxDistanceKm,
    'familyType':         filter.familyType,
    'openToDivorced':     filter.openToDivorced,
    'genderPref':         filter.genderPref,
    'maritalStatus':      filter.maritalStatus,
    'hasChildren':        filter.hasChildren,
    'educationMin':       filter.educationMin,
  };

  factory FilterPreset.fromJson(Map<String, dynamic> j) {
    return FilterPreset(
      name: j['name'] as String? ?? 'Preset',
      filter: DiscoveryFilter(
        ageMin:             j['ageMin'] as int?,
        ageMax:             j['ageMax'] as int?,
        sect:               j['sect'] as String?,
        deenLevel:          j['deenLevel'] as String?,
        verifiedOnly:       (j['verifiedOnly'] as bool?) ?? false,
        activeRecentlyOnly: (j['activeRecentlyOnly'] as bool?) ?? false,
        maxDistanceKm:      j['maxDistanceKm'] as int?,
        familyType:         j['familyType'] as String?,
        openToDivorced:     (j['openToDivorced'] as bool?) ?? false,
        genderPref:         j['genderPref'] as String?,
        maritalStatus:      j['maritalStatus'] as String?,
        hasChildren:        j['hasChildren'] as String?,
        educationMin:       j['educationMin'] as String?,
      ),
    );
  }
}

class FilterPresetService {
  static const _kKey     = 'filter_presets';
  static const maxPresets = 3;

  static Future<List<FilterPreset>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw   = prefs.getStringList(_kKey) ?? [];
    return raw.map((s) {
      try {
        return FilterPreset.fromJson(
            jsonDecode(s) as Map<String, dynamic>);
      } catch (_) {
        return null;
      }
    }).whereType<FilterPreset>().toList();
  }

  static Future<void> save(List<FilterPreset> presets) async {
    final prefs = await SharedPreferences.getInstance();
    final capped = presets.take(maxPresets).toList();
    await prefs.setStringList(
      _kKey,
      capped.map((p) => jsonEncode(p.toJson())).toList(),
    );
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kKey);
  }
}
