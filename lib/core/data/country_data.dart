// lib/core/data/country_data.dart
// ============================================================
// SILARAH — Complete Country Database
//
// • All 198 supported countries
// • Emoji flags derived from ISO2 — no hardcoded emojis
// • Phone format patterns for top 60 countries
// • Device-locale auto-detection (same as Telegram)
//
// HOW TELEGRAM DOES IT: They bundle the full country list
// statically inside the app — same as this file. The "dynamic"
// part is auto-detecting the device country and live-formatting
// the number. There is no API call for country data.
// ============================================================

import 'package:flutter/widgets.dart';

// ── Model ─────────────────────────────────────────────────────

class CountryInfo {
  const CountryInfo({
    required this.iso2,
    required this.dialCode,
    required this.name,
    this.format,
    this.priority = 0,
  });

  final String iso2; // 'IN', 'GB', 'SA'
  final String dialCode; // '+91', '+44', '+966'
  final String name; // 'India', 'United Kingdom'
  final String? format; // '#' = digit. e.g. '##### #####' for India
  final int priority; // > 0 → shown in "Popular" section first

  // Derive flag emoji from ISO2 at runtime — no hardcoded emoji
  // 'I' (0x49) → regional indicator I (0x1F1EE), etc.
  String get flag {
    return iso2.toUpperCase().split('').map((c) {
      return String.fromCharCode(c.codeUnitAt(0) - 0x41 + 0x1F1E6);
    }).join();
  }

  // Format a raw digit string using the format pattern
  // Input: '9876543210', pattern: '##### #####' → '98765 43210'
  String formatNumber(String digits) {
    if (format == null || digits.isEmpty) return digits;
    final buf = StringBuffer();
    int di = 0;
    for (int i = 0; i < format!.length; i++) {
      if (di >= digits.length) break;
      if (format![i] == '#') {
        buf.write(digits[di++]);
      } else {
        // Only insert spacer if we have more digits coming
        if (di < digits.length) buf.write(format![i]);
      }
    }
    return buf.toString();
  }

  // How many raw digits the national number has
  int get maxDigits {
    return format?.split('').where((c) => c == '#').length ??
        10; // safe default
  }
}

// ── Auto-detect device country ────────────────────────────────
//
// Reads the device locale's country code (e.g. 'IN', 'GB').
// Works on iOS and Android without any permissions.

CountryInfo deviceCountry() {
  try {
    final code = WidgetsBinding.instance.platformDispatcher.locale.countryCode
        ?.toUpperCase();
    if (code != null) {
      final match = kAllCountries.where((c) => c.iso2 == code);
      if (match.isNotEmpty) return match.first;
    }
  } catch (_) {}
  // Fallback to United States
  return kAllCountries.firstWhere((c) => c.iso2 == 'US');
}

// ── Lookup by typed dial prefix ───────────────────────────────
//
// When user types '+9178...' we try:
//   4 digits: +9178 → no match
//   3 digits: +917  → no match
//   2 digits: +91   → India ✓
// Longest match wins (prevents +1 matching before +1-809, etc.)

CountryInfo? countryByDialPrefix(String digitsAfterPlus) {
  for (final len in [4, 3, 2, 1]) {
    if (digitsAfterPlus.length < len) continue;
    final prefix = '+${digitsAfterPlus.substring(0, len)}';
    final matches =
        kAllCountries.where((c) => c.dialCode == prefix && c.priority > 0);
    if (matches.isNotEmpty) return matches.first;
    final anyMatch = kAllCountries.where((c) => c.dialCode == prefix);
    if (anyMatch.isNotEmpty) return anyMatch.first;
  }
  return null;
}

// ── Complete country list — 198 entries ───────────────────────
//
// Priority field:
//   10 = Muslim-majority top markets (shown first in Popular section)
//    5 = Major diaspora destinations / English-speaking
//    0 = All other countries
//
// Format patterns:
//   '#' = digit placeholder
//   ' ' = space separator
//   '-' = dash separator
//   '(' ')' = parentheses

const List<CountryInfo> kAllCountries = [
  // ── Popular — Muslim-majority markets ──────────────────────
  CountryInfo(
      iso2: 'IN',
      dialCode: '+91',
      name: 'India',
      format: '##### #####',
      priority: 10),
  CountryInfo(
      iso2: 'PK',
      dialCode: '+92',
      name: 'Pakistan',
      format: '### #######',
      priority: 10),
  CountryInfo(
      iso2: 'BD',
      dialCode: '+880',
      name: 'Bangladesh',
      format: '####-######',
      priority: 10),
  CountryInfo(
      iso2: 'ID',
      dialCode: '+62',
      name: 'Indonesia',
      format: '### #### ####',
      priority: 10),
  CountryInfo(
      iso2: 'SA',
      dialCode: '+966',
      name: 'Saudi Arabia',
      format: '## ### ####',
      priority: 10),
  CountryInfo(
      iso2: 'AE',
      dialCode: '+971',
      name: 'UAE',
      format: '## ### ####',
      priority: 10),
  CountryInfo(
      iso2: 'MY',
      dialCode: '+60',
      name: 'Malaysia',
      format: '##-#### ####',
      priority: 10),
  CountryInfo(
      iso2: 'TR',
      dialCode: '+90',
      name: 'Turkey',
      format: '### ### ####',
      priority: 10),
  CountryInfo(
      iso2: 'EG',
      dialCode: '+20',
      name: 'Egypt',
      format: '### #### ####',
      priority: 10),
  CountryInfo(
      iso2: 'NG',
      dialCode: '+234',
      name: 'Nigeria',
      format: '### ### ####',
      priority: 10),
  CountryInfo(
      iso2: 'QA',
      dialCode: '+974',
      name: 'Qatar',
      format: '#### ####',
      priority: 10),
  CountryInfo(
      iso2: 'KW',
      dialCode: '+965',
      name: 'Kuwait',
      format: '#### ####',
      priority: 10),
  CountryInfo(
      iso2: 'BH',
      dialCode: '+973',
      name: 'Bahrain',
      format: '#### ####',
      priority: 10),
  CountryInfo(
      iso2: 'OM',
      dialCode: '+968',
      name: 'Oman',
      format: '#### ####',
      priority: 10),

  // ── Popular — Major diaspora destinations ──────────────────
  CountryInfo(
      iso2: 'GB',
      dialCode: '+44',
      name: 'United Kingdom',
      format: '#### ######',
      priority: 5),
  CountryInfo(
      iso2: 'US',
      dialCode: '+1',
      name: 'United States',
      format: '(###) ###-####',
      priority: 5),
  CountryInfo(
      iso2: 'CA',
      dialCode: '+1',
      name: 'Canada',
      format: '(###) ###-####',
      priority: 5),
  CountryInfo(
      iso2: 'AU',
      dialCode: '+61',
      name: 'Australia',
      format: '### ### ###',
      priority: 5),
  CountryInfo(
      iso2: 'DE',
      dialCode: '+49',
      name: 'Germany',
      format: '#### #######',
      priority: 5),
  CountryInfo(
      iso2: 'FR',
      dialCode: '+33',
      name: 'France',
      format: '# ## ## ## ##',
      priority: 5),
  CountryInfo(
      iso2: 'NL',
      dialCode: '+31',
      name: 'Netherlands',
      format: '## ### ####',
      priority: 5),
  CountryInfo(
      iso2: 'SE',
      dialCode: '+46',
      name: 'Sweden',
      format: '## ### ## ##',
      priority: 5),
  CountryInfo(
      iso2: 'NO',
      dialCode: '+47',
      name: 'Norway',
      format: '### ## ###',
      priority: 5),
  CountryInfo(
      iso2: 'SG',
      dialCode: '+65',
      name: 'Singapore',
      format: '#### ####',
      priority: 5),
  CountryInfo(
      iso2: 'ZA',
      dialCode: '+27',
      name: 'South Africa',
      format: '## ### ####',
      priority: 5),

  // ── A ──────────────────────────────────────────────────────
  CountryInfo(
      iso2: 'AF', dialCode: '+93', name: 'Afghanistan', format: '## ### ####'),
  CountryInfo(
      iso2: 'AL', dialCode: '+355', name: 'Albania', format: '## ### ####'),
  CountryInfo(
      iso2: 'DZ', dialCode: '+213', name: 'Algeria', format: '### ## ## ##'),
  CountryInfo(iso2: 'AD', dialCode: '+376', name: 'Andorra', format: '### ###'),
  CountryInfo(
      iso2: 'AO', dialCode: '+244', name: 'Angola', format: '### ### ###'),
  CountryInfo(iso2: 'AG', dialCode: '+1', name: 'Antigua & Barbuda'),
  CountryInfo(
      iso2: 'AR', dialCode: '+54', name: 'Argentina', format: '## ####-####'),
  CountryInfo(
      iso2: 'AM', dialCode: '+374', name: 'Armenia', format: '## ######'),
  CountryInfo(
      iso2: 'AT', dialCode: '+43', name: 'Austria', format: '### #######'),
  CountryInfo(
      iso2: 'AZ', dialCode: '+994', name: 'Azerbaijan', format: '## ### ## ##'),

  // ── B ──────────────────────────────────────────────────────
  CountryInfo(iso2: 'BS', dialCode: '+1', name: 'Bahamas'),
  CountryInfo(iso2: 'BB', dialCode: '+1', name: 'Barbados'),
  CountryInfo(
      iso2: 'BY', dialCode: '+375', name: 'Belarus', format: '## ###-##-##'),
  CountryInfo(
      iso2: 'BE', dialCode: '+32', name: 'Belgium', format: '### ## ## ##'),
  CountryInfo(iso2: 'BZ', dialCode: '+501', name: 'Belize', format: '### ####'),
  CountryInfo(
      iso2: 'BJ', dialCode: '+229', name: 'Benin', format: '## ## ## ##'),
  CountryInfo(
      iso2: 'BT', dialCode: '+975', name: 'Bhutan', format: '## ### ###'),
  CountryInfo(
      iso2: 'BO', dialCode: '+591', name: 'Bolivia', format: '# ### ####'),
  CountryInfo(
      iso2: 'BA',
      dialCode: '+387',
      name: 'Bosnia & Herzegovina',
      format: '## ### ###'),
  CountryInfo(
      iso2: 'BW', dialCode: '+267', name: 'Botswana', format: '## ### ###'),
  CountryInfo(
      iso2: 'BR', dialCode: '+55', name: 'Brazil', format: '(##) # ####-####'),
  CountryInfo(iso2: 'BN', dialCode: '+673', name: 'Brunei', format: '### ####'),
  CountryInfo(
      iso2: 'BG', dialCode: '+359', name: 'Bulgaria', format: '## ### ####'),
  CountryInfo(
      iso2: 'BF',
      dialCode: '+226',
      name: 'Burkina Faso',
      format: '## ## ## ##'),
  CountryInfo(
      iso2: 'BI', dialCode: '+257', name: 'Burundi', format: '## ## ## ##'),

  // ── C ──────────────────────────────────────────────────────
  CountryInfo(
      iso2: 'CV', dialCode: '+238', name: 'Cabo Verde', format: '### ## ##'),
  CountryInfo(
      iso2: 'KH', dialCode: '+855', name: 'Cambodia', format: '## ### ###'),
  CountryInfo(
      iso2: 'CM', dialCode: '+237', name: 'Cameroon', format: '## ## ## ##'),
  CountryInfo(
      iso2: 'CF',
      dialCode: '+236',
      name: 'Central African Rep.',
      format: '## ## ## ##'),
  CountryInfo(
      iso2: 'TD', dialCode: '+235', name: 'Chad', format: '## ## ## ##'),
  CountryInfo(
      iso2: 'CL', dialCode: '+56', name: 'Chile', format: '# #### ####'),
  CountryInfo(
      iso2: 'CN', dialCode: '+86', name: 'China', format: '### #### ####'),
  CountryInfo(
      iso2: 'CO', dialCode: '+57', name: 'Colombia', format: '### ### ####'),
  CountryInfo(
      iso2: 'KM', dialCode: '+269', name: 'Comoros', format: '### ## ##'),
  CountryInfo(
      iso2: 'CG', dialCode: '+242', name: 'Congo', format: '## ### ####'),
  CountryInfo(
      iso2: 'CD', dialCode: '+243', name: 'Congo (DRC)', format: '### ### ###'),
  CountryInfo(
      iso2: 'CR', dialCode: '+506', name: 'Costa Rica', format: '#### ####'),
  CountryInfo(
      iso2: 'CI',
      dialCode: '+225',
      name: "Côte d'Ivoire",
      format: '## ## ## ##'),
  CountryInfo(
      iso2: 'HR', dialCode: '+385', name: 'Croatia', format: '## ### ###'),
  CountryInfo(iso2: 'CU', dialCode: '+53', name: 'Cuba', format: '# ### ####'),
  CountryInfo(
      iso2: 'CY', dialCode: '+357', name: 'Cyprus', format: '## ######'),
  CountryInfo(
      iso2: 'CZ',
      dialCode: '+420',
      name: 'Czech Republic',
      format: '### ### ###'),

  // ── D ──────────────────────────────────────────────────────
  CountryInfo(
      iso2: 'DK', dialCode: '+45', name: 'Denmark', format: '## ## ## ##'),
  CountryInfo(
      iso2: 'DJ', dialCode: '+253', name: 'Djibouti', format: '## ## ## ##'),
  CountryInfo(iso2: 'DM', dialCode: '+1', name: 'Dominica'),
  CountryInfo(iso2: 'DO', dialCode: '+1', name: 'Dominican Republic'),

  // ── E ──────────────────────────────────────────────────────
  CountryInfo(
      iso2: 'EC', dialCode: '+593', name: 'Ecuador', format: '## ### ####'),
  CountryInfo(
      iso2: 'SV', dialCode: '+503', name: 'El Salvador', format: '#### ####'),
  CountryInfo(
      iso2: 'GQ',
      dialCode: '+240',
      name: 'Equatorial Guinea',
      format: '## ### ####'),
  CountryInfo(
      iso2: 'ER', dialCode: '+291', name: 'Eritrea', format: '# ### ###'),
  CountryInfo(
      iso2: 'EE', dialCode: '+372', name: 'Estonia', format: '## ## ####'),
  CountryInfo(
      iso2: 'SZ', dialCode: '+268', name: 'Eswatini', format: '## ## ####'),
  CountryInfo(
      iso2: 'ET', dialCode: '+251', name: 'Ethiopia', format: '## ### ####'),

  // ── F ──────────────────────────────────────────────────────
  CountryInfo(iso2: 'FJ', dialCode: '+679', name: 'Fiji', format: '### ####'),
  CountryInfo(
      iso2: 'FI', dialCode: '+358', name: 'Finland', format: '## ### ####'),

  // ── G ──────────────────────────────────────────────────────
  CountryInfo(
      iso2: 'GA', dialCode: '+241', name: 'Gabon', format: '# ## ## ##'),
  CountryInfo(iso2: 'GM', dialCode: '+220', name: 'Gambia', format: '### ####'),
  CountryInfo(
      iso2: 'GE', dialCode: '+995', name: 'Georgia', format: '### ## ## ##'),
  CountryInfo(
      iso2: 'GH', dialCode: '+233', name: 'Ghana', format: '## ### ####'),
  CountryInfo(
      iso2: 'GR', dialCode: '+30', name: 'Greece', format: '### ### ####'),
  CountryInfo(iso2: 'GD', dialCode: '+1', name: 'Grenada'),
  CountryInfo(
      iso2: 'GT', dialCode: '+502', name: 'Guatemala', format: '#### ####'),
  CountryInfo(
      iso2: 'GN', dialCode: '+224', name: 'Guinea', format: '### ### ###'),
  CountryInfo(
      iso2: 'GW', dialCode: '+245', name: 'Guinea-Bissau', format: '# ## ####'),
  CountryInfo(iso2: 'GY', dialCode: '+592', name: 'Guyana', format: '### ####'),

  // ── H ──────────────────────────────────────────────────────
  CountryInfo(
      iso2: 'HT', dialCode: '+509', name: 'Haiti', format: '## ## ####'),
  CountryInfo(
      iso2: 'HN', dialCode: '+504', name: 'Honduras', format: '#### ####'),
  CountryInfo(
      iso2: 'HK', dialCode: '+852', name: 'Hong Kong', format: '#### ####'),
  CountryInfo(
      iso2: 'HU', dialCode: '+36', name: 'Hungary', format: '## ### ####'),

  // ── I ──────────────────────────────────────────────────────
  CountryInfo(
      iso2: 'IS', dialCode: '+354', name: 'Iceland', format: '### ####'),
  CountryInfo(
      iso2: 'IR', dialCode: '+98', name: 'Iran', format: '### ### ####'),
  CountryInfo(
      iso2: 'IQ', dialCode: '+964', name: 'Iraq', format: '### ### ####'),
  CountryInfo(
      iso2: 'IE', dialCode: '+353', name: 'Ireland', format: '## ### ####'),
  CountryInfo(
      iso2: 'IL', dialCode: '+972', name: 'Israel', format: '##-### ####'),
  CountryInfo(
      iso2: 'IT', dialCode: '+39', name: 'Italy', format: '### ### ####'),

  // ── J ──────────────────────────────────────────────────────
  CountryInfo(iso2: 'JM', dialCode: '+1', name: 'Jamaica'),
  CountryInfo(
      iso2: 'JP', dialCode: '+81', name: 'Japan', format: '## #### ####'),
  CountryInfo(
      iso2: 'JO', dialCode: '+962', name: 'Jordan', format: '# #### ####'),

  // ── K ──────────────────────────────────────────────────────
  CountryInfo(
      iso2: 'KZ', dialCode: '+7', name: 'Kazakhstan', format: '### ###-##-##'),
  CountryInfo(
      iso2: 'KE', dialCode: '+254', name: 'Kenya', format: '### ######'),
  CountryInfo(iso2: 'KI', dialCode: '+686', name: 'Kiribati', format: '## ###'),
  CountryInfo(
      iso2: 'XK', dialCode: '+383', name: 'Kosovo', format: '## ### ###'),
  CountryInfo(
      iso2: 'KG', dialCode: '+996', name: 'Kyrgyzstan', format: '### ## ## ##'),
  CountryInfo(
      iso2: 'KP',
      dialCode: '+850',
      name: 'North Korea',
      format: '### ### ####'),
  CountryInfo(
      iso2: 'KR', dialCode: '+82', name: 'South Korea', format: '##-####-####'),

  // ── L ──────────────────────────────────────────────────────
  CountryInfo(
      iso2: 'LA', dialCode: '+856', name: 'Laos', format: '## ## ### ###'),
  CountryInfo(
      iso2: 'LV', dialCode: '+371', name: 'Latvia', format: '## ### ###'),
  CountryInfo(
      iso2: 'LB', dialCode: '+961', name: 'Lebanon', format: '## ### ###'),
  CountryInfo(
      iso2: 'LS', dialCode: '+266', name: 'Lesotho', format: '## ### ###'),
  CountryInfo(
      iso2: 'LR', dialCode: '+231', name: 'Liberia', format: '## ### ###'),
  CountryInfo(
      iso2: 'LY', dialCode: '+218', name: 'Libya', format: '## ### ####'),
  CountryInfo(
      iso2: 'LI', dialCode: '+423', name: 'Liechtenstein', format: '### ####'),
  CountryInfo(
      iso2: 'LT', dialCode: '+370', name: 'Lithuania', format: '### #####'),
  CountryInfo(
      iso2: 'LU', dialCode: '+352', name: 'Luxembourg', format: '## ## ##'),

  // ── M ──────────────────────────────────────────────────────
  CountryInfo(iso2: 'MO', dialCode: '+853', name: 'Macau', format: '#### ####'),
  CountryInfo(
      iso2: 'MG', dialCode: '+261', name: 'Madagascar', format: '## ## ### ##'),
  CountryInfo(
      iso2: 'MW', dialCode: '+265', name: 'Malawi', format: '## ### ####'),
  CountryInfo(
      iso2: 'MV', dialCode: '+960', name: 'Maldives', format: '### ####'),
  CountryInfo(
      iso2: 'ML', dialCode: '+223', name: 'Mali', format: '## ## ## ##'),
  CountryInfo(iso2: 'MT', dialCode: '+356', name: 'Malta', format: '#### ####'),
  CountryInfo(
      iso2: 'MH',
      dialCode: '+692',
      name: 'Marshall Islands',
      format: '### ####'),
  CountryInfo(
      iso2: 'MR', dialCode: '+222', name: 'Mauritania', format: '## ## ## ##'),
  CountryInfo(
      iso2: 'MU', dialCode: '+230', name: 'Mauritius', format: '#### ####'),
  CountryInfo(
      iso2: 'MX', dialCode: '+52', name: 'Mexico', format: '### ### ####'),
  CountryInfo(
      iso2: 'FM', dialCode: '+691', name: 'Micronesia', format: '### ####'),
  CountryInfo(
      iso2: 'MD', dialCode: '+373', name: 'Moldova', format: '## ### ###'),
  CountryInfo(
      iso2: 'MC', dialCode: '+377', name: 'Monaco', format: '## ## ## ##'),
  CountryInfo(
      iso2: 'MN', dialCode: '+976', name: 'Mongolia', format: '## ## ####'),
  CountryInfo(
      iso2: 'ME', dialCode: '+382', name: 'Montenegro', format: '## ### ###'),
  CountryInfo(
      iso2: 'MA', dialCode: '+212', name: 'Morocco', format: '##-### ## ##'),
  CountryInfo(
      iso2: 'MZ', dialCode: '+258', name: 'Mozambique', format: '## ### ####'),
  CountryInfo(
      iso2: 'MM', dialCode: '+95', name: 'Myanmar', format: '## ### ####'),

  // ── N ──────────────────────────────────────────────────────
  CountryInfo(
      iso2: 'NA', dialCode: '+264', name: 'Namibia', format: '## ### ####'),
  CountryInfo(iso2: 'NR', dialCode: '+674', name: 'Nauru', format: '### ####'),
  CountryInfo(
      iso2: 'NP', dialCode: '+977', name: 'Nepal', format: '##-### ####'),
  CountryInfo(
      iso2: 'NZ', dialCode: '+64', name: 'New Zealand', format: '## ### ####'),
  CountryInfo(
      iso2: 'NI', dialCode: '+505', name: 'Nicaragua', format: '#### ####'),
  CountryInfo(
      iso2: 'NE', dialCode: '+227', name: 'Niger', format: '## ## ## ##'),
  CountryInfo(
      iso2: 'MK',
      dialCode: '+389',
      name: 'North Macedonia',
      format: '## ### ###'),

  // ── O ──────────────────────────────────────────────────────
  // Oman already in popular

  // ── P ──────────────────────────────────────────────────────
  CountryInfo(iso2: 'PW', dialCode: '+680', name: 'Palau', format: '### ####'),
  CountryInfo(
      iso2: 'PS', dialCode: '+970', name: 'Palestine', format: '### ### ###'),
  CountryInfo(iso2: 'PA', dialCode: '+507', name: 'Panama', format: '### ####'),
  CountryInfo(
      iso2: 'PG',
      dialCode: '+675',
      name: 'Papua New Guinea',
      format: '### ####'),
  CountryInfo(
      iso2: 'PY', dialCode: '+595', name: 'Paraguay', format: '### ######'),
  CountryInfo(iso2: 'PE', dialCode: '+51', name: 'Peru', format: '### ### ###'),
  CountryInfo(
      iso2: 'PH', dialCode: '+63', name: 'Philippines', format: '### ### ####'),
  CountryInfo(
      iso2: 'PL', dialCode: '+48', name: 'Poland', format: '### ### ###'),
  CountryInfo(
      iso2: 'PT', dialCode: '+351', name: 'Portugal', format: '### ### ###'),

  // ── Q ──────────────────────────────────────────────────────
  // Qatar already in popular

  // ── R ──────────────────────────────────────────────────────
  CountryInfo(
      iso2: 'RO', dialCode: '+40', name: 'Romania', format: '## ### ####'),
  CountryInfo(
      iso2: 'RU', dialCode: '+7', name: 'Russia', format: '### ###-##-##'),
  CountryInfo(
      iso2: 'RW', dialCode: '+250', name: 'Rwanda', format: '### ### ###'),

  // ── S ──────────────────────────────────────────────────────
  CountryInfo(iso2: 'KN', dialCode: '+1', name: 'Saint Kitts & Nevis'),
  CountryInfo(iso2: 'LC', dialCode: '+1', name: 'Saint Lucia'),
  CountryInfo(iso2: 'VC', dialCode: '+1', name: 'Saint Vincent & Grenadines'),
  CountryInfo(iso2: 'WS', dialCode: '+685', name: 'Samoa', format: '## ####'),
  CountryInfo(
      iso2: 'SM', dialCode: '+378', name: 'San Marino', format: '## ######'),
  CountryInfo(
      iso2: 'ST',
      dialCode: '+239',
      name: 'São Tomé & Príncipe',
      format: '## #####'),
  CountryInfo(
      iso2: 'SN', dialCode: '+221', name: 'Senegal', format: '## ### ## ##'),
  CountryInfo(
      iso2: 'RS', dialCode: '+381', name: 'Serbia', format: '## ### ####'),
  CountryInfo(
      iso2: 'SC', dialCode: '+248', name: 'Seychelles', format: '# ### ###'),
  CountryInfo(
      iso2: 'SL', dialCode: '+232', name: 'Sierra Leone', format: '## ######'),
  CountryInfo(
      iso2: 'SK', dialCode: '+421', name: 'Slovakia', format: '### ### ###'),
  CountryInfo(
      iso2: 'SI', dialCode: '+386', name: 'Slovenia', format: '## ### ###'),
  CountryInfo(
      iso2: 'SB', dialCode: '+677', name: 'Solomon Islands', format: '## ###'),
  CountryInfo(
      iso2: 'SO', dialCode: '+252', name: 'Somalia', format: '## ### ###'),
  CountryInfo(
      iso2: 'SS', dialCode: '+211', name: 'South Sudan', format: '## ### ####'),
  CountryInfo(
      iso2: 'ES', dialCode: '+34', name: 'Spain', format: '### ### ###'),
  CountryInfo(
      iso2: 'LK', dialCode: '+94', name: 'Sri Lanka', format: '## # ######'),
  CountryInfo(
      iso2: 'SD', dialCode: '+249', name: 'Sudan', format: '## ### ####'),
  CountryInfo(
      iso2: 'SR', dialCode: '+597', name: 'Suriname', format: '### ####'),
  CountryInfo(
      iso2: 'CH', dialCode: '+41', name: 'Switzerland', format: '## ### ## ##'),
  CountryInfo(
      iso2: 'SY', dialCode: '+963', name: 'Syria', format: '### ### ###'),

  // ── T ──────────────────────────────────────────────────────
  CountryInfo(
      iso2: 'TW', dialCode: '+886', name: 'Taiwan', format: '#### ### ###'),
  CountryInfo(
      iso2: 'TJ', dialCode: '+992', name: 'Tajikistan', format: '## ### ####'),
  CountryInfo(
      iso2: 'TZ', dialCode: '+255', name: 'Tanzania', format: '### ### ###'),
  CountryInfo(
      iso2: 'TH', dialCode: '+66', name: 'Thailand', format: '## ### ####'),
  CountryInfo(
      iso2: 'TL', dialCode: '+670', name: 'Timor-Leste', format: '### ####'),
  CountryInfo(
      iso2: 'TG', dialCode: '+228', name: 'Togo', format: '## ## ## ##'),
  CountryInfo(iso2: 'TO', dialCode: '+676', name: 'Tonga', format: '### ####'),
  CountryInfo(iso2: 'TT', dialCode: '+1', name: 'Trinidad & Tobago'),
  CountryInfo(
      iso2: 'TN', dialCode: '+216', name: 'Tunisia', format: '## ### ###'),
  CountryInfo(
      iso2: 'TM', dialCode: '+993', name: 'Turkmenistan', format: '## ######'),
  CountryInfo(iso2: 'TV', dialCode: '+688', name: 'Tuvalu', format: '## ###'),

  // ── U ──────────────────────────────────────────────────────
  CountryInfo(
      iso2: 'UG', dialCode: '+256', name: 'Uganda', format: '### ######'),
  CountryInfo(
      iso2: 'UA', dialCode: '+380', name: 'Ukraine', format: '## ### ## ##'),
  CountryInfo(
      iso2: 'UY', dialCode: '+598', name: 'Uruguay', format: '## ### ####'),
  CountryInfo(
      iso2: 'UZ', dialCode: '+998', name: 'Uzbekistan', format: '## ### ## ##'),

  // ── V ──────────────────────────────────────────────────────
  CountryInfo(
      iso2: 'VU', dialCode: '+678', name: 'Vanuatu', format: '### ####'),
  CountryInfo(
      iso2: 'VE', dialCode: '+58', name: 'Venezuela', format: '###-### ####'),
  CountryInfo(
      iso2: 'VN', dialCode: '+84', name: 'Vietnam', format: '### ### ####'),

  // ── Y ──────────────────────────────────────────────────────
  CountryInfo(
      iso2: 'YE', dialCode: '+967', name: 'Yemen', format: '### ### ###'),

  // ── Z ──────────────────────────────────────────────────────
  CountryInfo(
      iso2: 'ZM', dialCode: '+260', name: 'Zambia', format: '## ### ####'),
  CountryInfo(
      iso2: 'ZW', dialCode: '+263', name: 'Zimbabwe', format: '## ### ####'),
];
