// lib/core/services/filter_preset_service.dart
// ============================================================
// SILARAH — Filter Preset Service (Feature 9)
// Persists up to 3 named DiscoveryFilter presets via
// shared_preferences as JSON.
// ============================================================

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../cubits/discovery/discovery_filter.dart';

class FilterPreset {
  const FilterPreset({required this.name, required this.filter});

  final String name;
  final DiscoveryFilter filter;

  Map<String, dynamic> toJson() => {
        'name': name,
        'ageMin': filter.ageMin,
        'ageMax': filter.ageMax,
        'sect': filter.sect,
        'deenLevel': filter.deenLevel,
        'verifiedOnly': filter.verifiedOnly,
        'activeRecentlyOnly': filter.activeRecentlyOnly,
        'maxDistanceKm': filter.maxDistanceKm,
        'familyType': filter.familyType,
        'openToDivorced': filter.openToDivorced,
        'genderPref': filter.genderPref,
        'maritalStatus': filter.maritalStatus,
        'hasChildren': filter.hasChildren,
        'educationMin': filter.educationMin,
        'distanceLabel': filter.distanceLabel,
        'motherTongue': filter.motherTongue,
        'community': filter.community,
        'livingExpectation': filter.livingExpectation,
        'quranMemorization': filter.quranMemorization,
        'marriageTimeline': filter.marriageTimeline,
        'willingToRelocate': filter.willingToRelocate,
        'diasporaMode': filter.diasporaMode,
        'diasporaCountries': filter.diasporaCountries,
        'browseCountries': filter.browseCountries,
      };

  factory FilterPreset.fromJson(Map<String, dynamic> j) {
    return FilterPreset(
      name: j['name'] as String? ?? 'Preset',
      filter: DiscoveryFilter(
        ageMin: j['ageMin'] as int?,
        ageMax: j['ageMax'] as int?,
        sect: j['sect'] as String?,
        deenLevel: j['deenLevel'] as String?,
        verifiedOnly: (j['verifiedOnly'] as bool?) ?? false,
        activeRecentlyOnly: (j['activeRecentlyOnly'] as bool?) ?? false,
        maxDistanceKm: j['maxDistanceKm'] as int?,
        familyType: j['familyType'] as String?,
        openToDivorced: (j['openToDivorced'] as bool?) ?? false,
        genderPref: j['genderPref'] as String?,
        maritalStatus: j['maritalStatus'] as String?,
        hasChildren: j['hasChildren'] as String?,
        educationMin: j['educationMin'] as String?,
        distanceLabel: j['distanceLabel'] as String?,
        motherTongue: j['motherTongue'] as String?,
        community: j['community'] as String?,
        livingExpectation: j['livingExpectation'] as String?,
        quranMemorization: j['quranMemorization'] as String?,
        marriageTimeline: j['marriageTimeline'] as String?,
        willingToRelocate: j['willingToRelocate'] as String?,
        diasporaMode: (j['diasporaMode'] as bool?) ?? false,
        diasporaCountries: j['diasporaCountries'] == null
            ? null
            : List<String>.from(j['diasporaCountries'] as Iterable),
        browseCountries: j['browseCountries'] == null
            ? null
            : List<String>.from(j['browseCountries'] as Iterable),
      ),
    );
  }
}

class FilterPresetService {
  static const _kKey = 'filter_presets';
  static const maxPresets = 3;

  static Future<List<FilterPreset>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_kKey) ?? [];
    return raw
        .map((s) {
          try {
            return FilterPreset.fromJson(jsonDecode(s) as Map<String, dynamic>);
          } catch (_) {
            return null;
          }
        })
        .whereType<FilterPreset>()
        .toList();
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
