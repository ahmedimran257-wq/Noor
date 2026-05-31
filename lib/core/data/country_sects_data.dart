// lib/core/data/country_sects_data.dart
// ============================================================
// NOOR — Country-Adaptive Sect Configuration
//
// What Telegram-calibre apps actually do:
//   • Show/hide sect based on country sensitivity
//   • Show sub-sect only when relevant
//   • Reorder options to match the country's Muslim majority
//   • Hide fields in countries where it's politically sensitive
//
// Saudi Arabia, Qatar, UAE → No sect shown (govt policy + sensitivity)
// Iran, Iraq, Bahrain → Shia prominent
// Turkey → Hanafi + Alevi acknowledged
// Indonesia, Malaysia → Shafi'i first
// South Asia → Full biradari-aware list
//
// FUTURE: Replace forCountry() with:
//   SELECT sect_config FROM country_config WHERE iso2 = ?
// ============================================================

class CountrySectConfig {
  const CountrySectConfig({
    required this.showSect,
    required this.showSubSect,
    required this.sects,
    required this.subSects,
    required this.sensitivityNote,
  });

  /// Whether to show the sect selector at all
  final bool showSect;

  /// Whether to show sub-sect (madhab etc.) after sect is chosen
  final bool showSubSect;

  /// Top-level sect options for this country
  final List<String> sects;

  /// Sub-sect map: sect key → list of sub-sects
  final Map<String, List<String>> subSects;

  /// Optional note shown below the field (e.g. "We focus on deen over sect")
  final String? sensitivityNote;

  /// Flattened list for simple display (main sects + Others)
  List<String> get displaySects => sects;
}

class CountrySectData {
  CountrySectData._();

  // Countries where showing sect is politically or culturally sensitive
  static const _sectSensitiveCountries = {
    'SA', 'QA', 'AE', 'KW', 'BH', 'OM', // Gulf — government policy
    'EG',                                  // Egypt — sectarian tensions
    'MA', 'TN', 'DZ', 'LY',              // North Africa — Sunni majority, no diversity
    'TR',                                  // Turkey — state secular tradition
  };

  // Countries where Shia is prominent / majority
  // ignore: unused_field
  static const _shiaProminentCountries = {
    'IR', 'IQ', 'AZ',
  };

  // Countries where Baharna / minority Shia exists
  // ignore: unused_field
  static const _shiaMinorityCountries = {
    'BH', 'SA', 'KW', 'LB',
  };

  static CountrySectConfig forCountry(String rawIso2) {
    final iso2 = rawIso2.toUpperCase();

    // ── Gulf / politically sensitive ────────────────────────
    if (_sectSensitiveCountries.contains(iso2)) {
      return const CountrySectConfig(
        showSect:    false,
        showSubSect: false,
        sects:       [],
        subSects:    {},
        sensitivityNote:
            'We focus on deen level and values rather than sect for your region.',
      );
    }

    // ── Iran / Shia-majority ────────────────────────────────
    if (iso2 == 'IR') {
      return const CountrySectConfig(
        showSect:    true,
        showSubSect: true,
        sects: ['Shia (Ithna Ashari / Twelver)', 'Sunni', 'Sufi', 'Other'],
        subSects: {
          'Shia (Ithna Ashari / Twelver)': [
            'Usuli', 'Akhbari', 'Shaykhi', 'Other Shia',
          ],
          'Sunni': ['Hanafi', 'Shafi\'i', 'Other Sunni'],
        },
        sensitivityNote: null,
      );
    }

    // ── Iraq / Mixed ─────────────────────────────────────────
    if (iso2 == 'IQ') {
      return const CountrySectConfig(
        showSect:    true,
        showSubSect: true,
        sects: [
          'Shia (Ithna Ashari)',
          'Sunni',
          'Yazidi (minority)',
          'Mandaean (minority)',
          'Other',
        ],
        subSects: {
          'Shia (Ithna Ashari)': [
            'Najafi', 'Basrawi', 'Other Shia',
          ],
          'Sunni': [
            'Hanafi', 'Shafi\'i', 'Salafi', 'Other Sunni',
          ],
        },
        sensitivityNote: null,
      );
    }

    // ── Lebanon ──────────────────────────────────────────────
    if (iso2 == 'LB') {
      return const CountrySectConfig(
        showSect:    true,
        showSubSect: false,
        sects: [
          'Sunni',
          'Shia (Hezbollah / Amal region)',
          'Druze',
          'Alawite',
          'Other',
        ],
        subSects: {},
        sensitivityNote:
            'Lebanon has 18 officially recognised sects. Select the one closest to your background.',
      );
    }

    // ── Syria ────────────────────────────────────────────────
    if (iso2 == 'SY') {
      return const CountrySectConfig(
        showSect:    true,
        showSubSect: false,
        sects: [
          'Sunni', 'Alawite', 'Druze', 'Ismaili',
          'Shia', 'Other',
        ],
        subSects: {},
        sensitivityNote: null,
      );
    }

    // ── South Asia — Full biradari-aware sect list ───────────
    if (['IN', 'PK', 'BD', 'AF', 'LK', 'NP'].contains(iso2)) {
      return const CountrySectConfig(
        showSect:    true,
        showSubSect: true,
        sects: [
          'Sunni',
          'Shia (Ithna Ashari / Twelver)',
          'Shia (Ismaili / Aga Khan)',
          'Shia (Bohra — Dawoodi)',
          'Shia (Bohra — Sulaimani)',
          'Ahmadiyya (Qadiani)',
          'Ahmadiyya (Lahori)',
          'Other',
          'Prefer not to say',
        ],
        subSects: {
          'Sunni': [
            'Hanafi', 'Shafi\'i', 'Maliki', 'Hanbali',
            'Barelvi / Ahl-e-Sunnat', 'Deobandi',
            'Ahl-e-Hadith / Salafi', 'Tablighi Jamaat',
            'Other Sunni',
          ],
          'Shia (Ithna Ashari / Twelver)': [
            'Usuli', 'Other Twelver Shia',
          ],
        },
        sensitivityNote: null,
      );
    }

    // ── Southeast Asia — Shafi'i majority ───────────────────
    if (['ID', 'MY', 'SG', 'BN', 'TH', 'PH'].contains(iso2)) {
      return const CountrySectConfig(
        showSect:    true,
        showSubSect: true,
        sects: [
          'Sunni', 'Shia', 'Ahmadiyya', 'Other', 'Prefer not to say',
        ],
        subSects: {
          'Sunni': [
            'Shafi\'i', 'Hanafi', 'Maliki', 'Hanbali',
            'Salafi / Wahhabi', 'Other Sunni',
          ],
        },
        sensitivityNote: null,
      );
    }

    // ── Central Asia ─────────────────────────────────────────
    if (['KZ', 'UZ', 'KG', 'TJ', 'TM'].contains(iso2)) {
      return const CountrySectConfig(
        showSect:    true,
        showSubSect: true,
        sects: [
          'Sunni', 'Shia (minority)', 'Other', 'Prefer not to say',
        ],
        subSects: {
          'Sunni': [
            'Hanafi', 'Salafi / Wahhabi',
            'Sufi (Naqshbandi)', 'Other Sunni',
          ],
        },
        sensitivityNote: null,
      );
    }

    // ── Turkey (shown but with nuance) ──────────────────────
    if (iso2 == 'TR') {
      return const CountrySectConfig(
        showSect:    true,
        showSubSect: true,
        sects: [
          'Sunni', 'Alevi', 'Bektashi', 'Other', 'Prefer not to say',
        ],
        subSects: {
          'Sunni': ['Hanafi', 'Shafi\'i', 'Other Sunni'],
          'Alevi': ['Alevi Bektashi', 'Kurdish Alevi', 'Other Alevi'],
        },
        sensitivityNote: 'Turkey has a diverse Islamic tradition. Select what feels closest to your background.',
      );
    }

    // ── Sub-Saharan Africa ───────────────────────────────────
    if (['NG', 'GH', 'SN', 'ML', 'ET', 'SO', 'SD', 'TZ', 'KE',
         'CI', 'BF', 'NE', 'MR', 'GM', 'GN', 'MZ', 'CM'].contains(iso2)) {
      return const CountrySectConfig(
        showSect:    true,
        showSubSect: true,
        sects: [
          'Sunni', 'Sufi (Tijaniyya)', 'Sufi (Qadiriyya)',
          'Sufi (Muridiyya)', 'Salafi / Wahhabi',
          'Ahmadiyya', 'Other', 'Prefer not to say',
        ],
        subSects: {
          'Sunni': ['Maliki', 'Hanafi', 'Shafi\'i', 'Other Sunni'],
        },
        sensitivityNote: null,
      );
    }

    // ── Western diaspora (UK, US, CA, AU, EU) ───────────────
    if (['GB', 'US', 'CA', 'AU', 'NZ', 'FR', 'DE', 'NL',
         'BE', 'SE', 'NO', 'DK', 'IT', 'ES', 'AT', 'CH'].contains(iso2)) {
      return const CountrySectConfig(
        showSect:    true,
        showSubSect: true,
        sects: [
          'Sunni', 'Shia (Ithna Ashari)',
          'Shia (Ismaili / Aga Khan)', 'Shia (Bohra)',
          'Ahmadiyya', 'Sufi', 'Quran-only / Non-denominational',
          'Convert — still learning', 'Other', 'Prefer not to say',
        ],
        subSects: {
          'Sunni': [
            'Hanafi', 'Shafi\'i', 'Maliki', 'Hanbali',
            'Barelvi', 'Deobandi', 'Salafi / Wahhabi',
            'Other Sunni',
          ],
        },
        sensitivityNote:
            'Diaspora communities are diverse. Choose what reflects your background.',
      );
    }

    // ── Balkans ──────────────────────────────────────────────
    if (['BA', 'AL', 'XK', 'MK', 'ME'].contains(iso2)) {
      return const CountrySectConfig(
        showSect:    true,
        showSubSect: true,
        sects: [
          'Sunni', 'Bektashi', 'Other', 'Prefer not to say',
        ],
        subSects: {
          'Sunni': ['Hanafi', 'Salafi', 'Other Sunni'],
        },
        sensitivityNote: null,
      );
    }

    // ── Azerbaijani / mixed ──────────────────────────────────
    if (iso2 == 'AZ') {
      return const CountrySectConfig(
        showSect:    true,
        showSubSect: false,
        sects: [
          'Shia (majority)', 'Sunni', 'Non-practising / Secular background',
          'Other', 'Prefer not to say',
        ],
        subSects: {},
        sensitivityNote:
            'Azerbaijan has a secular tradition. Many identify culturally rather than by sect.',
      );
    }

    // ── Russia & post-Soviet ─────────────────────────────────
    if (iso2 == 'RU') {
      return const CountrySectConfig(
        showSect:    true,
        showSubSect: true,
        sects: [
          'Sunni', 'Shia (Azerbaijani background)',
          'Other', 'Prefer not to say',
        ],
        subSects: {
          'Sunni': [
            'Hanafi', 'Shafi\'i',
            'Sufi (Naqshbandi)', 'Sufi (Qadiri)',
            'Salafi', 'Other Sunni',
          ],
        },
        sensitivityNote: null,
      );
    }

    // ── China ────────────────────────────────────────────────
    if (iso2 == 'CN') {
      return const CountrySectConfig(
        showSect:    true,
        showSubSect: false,
        sects: [
          'Sunni (Gedimu)', 'Sunni (Yihewani / Ikhwan)',
          'Sunni (Salafi / Wahabi)',
          'Sufi (Menhuan)', 'Shia (small minority)',
          'Other', 'Prefer not to say',
        ],
        subSects: {},
        sensitivityNote: null,
      );
    }

    // ── Default — generic Sunni-first world list ─────────────
    return const CountrySectConfig(
      showSect:    true,
      showSubSect: true,
      sects: [
        'Sunni', 'Shia (Ithna Ashari)',
        'Shia (Ismaili)', 'Shia (Bohra)',
        'Ahmadiyya', 'Sufi',
        'Non-denominational / Just Muslim',
        'Other', 'Prefer not to say',
      ],
      subSects: {
        'Sunni': [
          'Hanafi', 'Shafi\'i', 'Maliki', 'Hanbali',
          'Salafi / Wahhabi', 'Other Sunni',
        ],
      },
      sensitivityNote: null,
    );
  }
}
