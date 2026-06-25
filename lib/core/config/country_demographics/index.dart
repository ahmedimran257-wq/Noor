// lib/core/config/country_demographics/index.dart
// ============================================================
// MITHAQ — Country Demographics Barrel File
// Merges all regional demographic maps into one unified map.
// ============================================================

import 'south_asia.dart';
import 'mena.dart';
import 'southeast_asia.dart';
import 'sub_saharan_africa.dart';
import 'europe.dart';
import 'central_asia.dart';
import 'americas.dart';
import 'oceania.dart';

/// Unified demographics map: ISO-2 country code → {communities, languages}.
/// Total: 75 countries.
final Map<String, Map<String, List<String>>> kAllDemographics = {
  ...kSouthAsiaDemographics,
  ...kMenaDemographics,
  ...kSoutheastAsiaDemographics,
  ...kSubSaharanAfricaDemographics,
  ...kEuropeDemographics,
  ...kCentralAsiaDemographics,
  ...kAmericasDemographics,
  ...kOceaniaDemographics,
};
