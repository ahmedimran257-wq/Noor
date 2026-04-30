// lib/core/config/demographics_config.dart
// ============================================================
// NOOR — Demographics Configuration
// Maps ISO country codes to communities and languages.
// Stored locally for speed; rarely changes.
//
// TODO (Phase 4): replace with Supabase query:
// SELECT communities, languages FROM country_demographics
// WHERE country_code = ?
// ============================================================

class DemographicsConfig {
  DemographicsConfig._();

  // ── Country data map ────────────────────────────────────────

  static const Map<String, Map<String, List<String>>> _data = {
    'IN': {
      'communities': [
        'Syed', 'Pathan', 'Qureshi', 'Ansari', 'Memon',
        'Rajput', 'Sheikh', 'Mirza', 'Mughal', 'Khan', 'Siddiqui',
        'Alvi', 'Dehlvi', 'Nomani', 'Sulaimani', 'Other',
      ],
      'languages': [
        'Urdu', 'Hindi', 'Bengali', 'Tamil', 'Telugu',
        'Malayalam', 'Kannada', 'Marathi', 'Gujarati', 'Punjabi',
        'Kashmiri', 'Sindhi', 'Other',
      ],
    },
    'PK': {
      'communities': [
        'Syed', 'Pathan', 'Qureshi', 'Memon', 'Rajput',
        'Awan', 'Chaudhry', 'Sheikh', 'Arain', 'Gujjar', 'Mirza',
        'Baloch', 'Sindhi', 'Brahui', 'Other',
      ],
      'languages': [
        'Urdu', 'Punjabi', 'Sindhi', 'Pashto', 'Balochi',
        'Saraiki', 'Brahui', 'Hindko', 'Other',
      ],
    },
    'BD': {
      'communities': [
        'Syed', 'Sheikh', 'Bhuiyan', 'Chowdhury',
        'Khan', 'Talukdar', 'Other',
      ],
      'languages': [
        'Bengali', 'Chittagonian', 'Sylheti', 'Other',
      ],
    },
    'GB': {
      'communities': [
        'Pakistani-Mirpuri', 'Sylheti', 'Arab',
        'Somali', 'Turkish', 'Afghan', 'Bengali', 'Gujarati', 'Other',
      ],
      'languages': [
        'English', 'Urdu', 'Bengali', 'Somali',
        'Arabic', 'Turkish', 'Punjabi', 'Other',
      ],
    },
    'US': {
      'communities': [
        'South Asian', 'Arab', 'Somali', 'Turkish',
        'African American Muslim', 'Indonesian', 'Other',
      ],
      'languages': [
        'English', 'Arabic', 'Urdu', 'Somali',
        'Bengali', 'Turkish', 'Other',
      ],
    },
    'CA': {
      'communities': [
        'South Asian', 'Arab', 'Somali', 'Afghan', 'Other',
      ],
      'languages': [
        'English', 'French', 'Arabic', 'Urdu', 'Other',
      ],
    },
    'AE': {
      'communities': [
        'Emirati', 'Arab', 'South Asian', 'Egyptian',
        'Pakistani', 'Indian', 'Other',
      ],
      'languages': [
        'Arabic', 'English', 'Urdu', 'Hindi', 'Other',
      ],
    },
    'SA': {
      'communities': [
        'Saudi Arab', 'Yemeni', 'Egyptian', 'Pakistani',
        'Indian', 'Other',
      ],
      'languages': [
        'Arabic', 'English', 'Urdu', 'Other',
      ],
    },
    'MY': {
      'communities': [
        'Malay', 'Indian Muslim', 'Arab', 'Other',
      ],
      'languages': [
        'Malay', 'English', 'Tamil', 'Arabic', 'Other',
      ],
    },
    'ID': {
      'communities': [
        'Javanese', 'Sundanese', 'Madurese',
        'Bugis', 'Betawi', 'Other',
      ],
      'languages': [
        'Indonesian', 'Javanese', 'Sundanese',
        'Madurese', 'Other',
      ],
    },
    'TR': {
      'communities': [
        'Turkish', 'Kurdish', 'Arab', 'Other',
      ],
      'languages': [
        'Turkish', 'Kurdish', 'Arabic', 'Other',
      ],
    },
    'EG': {
      'communities': [
        'Egyptian Arab', 'Coptic Muslim',
        'Nubian', 'Other',
      ],
      'languages': [
        'Arabic', 'English', 'Other',
      ],
    },
    'NG': {
      'communities': [
        'Hausa', 'Fulani', 'Yoruba Muslim',
        'Kanuri', 'Nupe', 'Other',
      ],
      'languages': [
        'Hausa', 'Yoruba', 'English', 'Fulfulde', 'Other',
      ],
    },
    'DE': {
      'communities': [
        'Turkish', 'Arab', 'Bosnian',
        'Afghan', 'South Asian', 'Other',
      ],
      'languages': [
        'German', 'Turkish', 'Arabic',
        'Bosnian', 'Urdu', 'Other',
      ],
    },
    'FR': {
      'communities': [
        'Algerian', 'Moroccan', 'Tunisian',
        'West African', 'Turkish', 'Other',
      ],
      'languages': [
        'French', 'Arabic', 'Berber', 'Wolof', 'Other',
      ],
    },
  };

  /// Default fallback for any country not in [_data].
  static const Map<String, List<String>> _fallback = {
    'communities': ['Syed', 'Pathan', 'Arab', 'Other'],
    'languages':   ['Arabic', 'English', 'Urdu', 'Other'],
  };

  // ── Public API ──────────────────────────────────────────────

  /// Returns a map with keys 'communities' and 'languages' (both List<String>)
  /// for the given ISO-2 [countryCode]. Falls back to a default list for
  /// unknown country codes.
  ///
  /// TODO (backend): replace with Supabase query when Phase 4 launches.
  static Map<String, List<String>> forCountry(String countryCode) {
    final entry = _data[countryCode.toUpperCase()];
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
}
