// lib/core/config/demographics_config.dart
// ============================================================
// NOOR — Demographics Configuration
// Maps ISO country codes to communities and languages.
// Uses regional files for 75+ countries.
//
// TODO (Phase 4): replace with Supabase query:
// SELECT communities, languages FROM country_demographics
// WHERE country_code = ?
// ============================================================

import 'country_demographics/index.dart';

class DemographicsConfig {
  DemographicsConfig._();

  /// Default fallback for any country not in the regional data.
  static const Map<String, List<String>> _fallback = {
    'communities': ['Arab', 'South Asian', 'African', 'Other'],
    'languages':   ['Arabic', 'English', 'Urdu', 'French', 'Other'],
  };

  // ── Public API ──────────────────────────────────────────────

  /// Returns a map with keys 'communities' and 'languages' (both List<String>)
  /// for the given ISO-2 [countryCode]. Falls back to a default list for
  /// unknown country codes.
  ///
  /// TODO (backend): replace with Supabase query when Phase 4 launches.
  static Map<String, List<String>> forCountry(String countryCode) {
    final entry = kAllDemographics[countryCode.toUpperCase()];
    if (entry != null) return entry;
    return _fallback;
  }

  /// Returns a display-friendly community label.
  /// Currently returns the value as-is; can be extended for localisation.
  static String getCommunityLabel(String code) => code;

  /// Convenience: returns community list for [countryCode].
  static List<String> communities(String countryCode) =>
      forCountry(countryCode)['communities'] ?? _fallback['communities']!;

  /// Convenience: returns language list for [countryCode].
  static List<String> languages(String countryCode) =>
      forCountry(countryCode)['languages'] ?? _fallback['languages']!;

  /// Returns all supported country codes (sorted alphabetically).
  static List<String> get supportedCountryCodes {
    final codes = kAllDemographics.keys.toList()..sort();
    return codes;
  }
}
