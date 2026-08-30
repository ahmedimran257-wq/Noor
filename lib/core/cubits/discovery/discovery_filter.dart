// SILARAH — Discovery Filter Model
// Active filter selections, serialisation helpers, and
// label generation for the chip bar.
//
//   • motherTongue  — filter by mother tongue
//   • community     — filter by community / biradari
//   • livingExpectation — filter by post-marriage living preference
class DiscoveryFilter {
  const DiscoveryFilter({
    this.ageMin,
    this.ageMax,
    this.sect,
    this.deenLevel,
    this.trustFilter,
    this.activeRecentlyOnly = false,
    this.maxDistanceKm,
    this.familyType,
    this.openToDivorced = false,
    // Feature 8
    this.genderPref,
    this.maritalStatus,
    this.hasChildren,
    this.educationMin,
    this.distanceLabel,
    this.stateName,
    this.cityId,
    this.cityName,
    this.motherTongue,
    this.community,
    this.livingExpectation,
    this.quranMemorization,
    this.marriageTimeline,
    this.willingToRelocate,
    this.diasporaMode = false,
    this.diasporaCountries,
    this.browseCountries,
  });

  final int? ageMin;
  final int? ageMax;
  final String? sect;
  final String? deenLevel;

  /// null | photo | guardian
  final String? trustFilter;
  final bool activeRecentlyOnly;
  final int? maxDistanceKm;
  final String? familyType;
  final bool openToDivorced;

  // Feature 8
  final String? genderPref;
  final String? maritalStatus;
  final String? hasChildren;
  final String? educationMin;
  final String? distanceLabel;
  final String? stateName;
  final String? cityId;
  final String? cityName;
  final String? motherTongue; // e.g. 'Urdu', 'Arabic', 'Bengali'
  final String? community; // e.g. 'Syed', 'Pathan', 'Arab'
  final String?
      livingExpectation; // 'with_inlaws' | 'separate' | 'open_to_discussion'
  final String? quranMemorization; // 'none','some_surahs','partial','hafiz'
  final String?
      marriageTimeline; // 'asap','6_months','1_year','2_plus_years','not_sure'
  final String? willingToRelocate; // 'yes','no','open_to_discussion'

  final bool diasporaMode;
  final List<String>? diasporaCountries;
  final List<String>? browseCountries;

  /// The single geographic contract sent to Supabase. Keeping this derived
  /// prevents contradictory combinations such as radius + diaspora from
  /// reaching the database when an older saved preset is restored.
  String get locationScope {
    if (diasporaMode) return 'diaspora';
    if (browseCountries != null && browseCountries!.isNotEmpty) {
      return 'countries';
    }
    if (effectiveMaxDistanceKm != null) return 'radius';
    switch (distanceLabel) {
      case 'Same City':
        return 'same_city';
      case 'Same State':
      case 'Same State / Region':
        return 'same_region';
      case 'Same Country':
      case 'All India':
      case 'Anywhere in India':
        return 'same_country';
      default:
        return 'global';
    }
  }

  /// Canonical radius used by PostGIS. Legacy label-only filters are retained
  /// so existing saved presets continue to work after the numeric migration.
  int? get effectiveMaxDistanceKm {
    final explicit = maxDistanceKm;
    if (explicit != null) return explicit.clamp(1, 20000).toInt();
    final match = RegExp(r'^(\d+)\s*km$', caseSensitive: false)
        .firstMatch(distanceLabel ?? '');
    return int.tryParse(match?.group(1) ?? '')?.clamp(1, 20000).toInt();
  }

  // Whether any filter is active
  bool get isActive =>
      ageMin != null ||
      ageMax != null ||
      sect != null ||
      deenLevel != null ||
      trustFilter != null ||
      activeRecentlyOnly ||
      maxDistanceKm != null ||
      familyType != null ||
      openToDivorced ||
      genderPref != null ||
      maritalStatus != null ||
      hasChildren != null ||
      educationMin != null ||
      distanceLabel != null ||
      stateName != null ||
      cityId != null ||
      motherTongue != null ||
      community != null ||
      livingExpectation != null ||
      quranMemorization != null ||
      marriageTimeline != null ||
      willingToRelocate != null ||
      diasporaMode ||
      (diasporaCountries != null && diasporaCountries!.isNotEmpty) ||
      (browseCountries != null && browseCountries!.isNotEmpty);

  int get activeCount {
    int count = 0;
    if (ageMin != null || ageMax != null) count++;
    if (sect != null) count++;
    if (deenLevel != null) count++;
    if (trustFilter != null) count++;
    if (activeRecentlyOnly) count++;
    if (maxDistanceKm != null ||
        RegExp(r'^\d+\s*km$', caseSensitive: false)
            .hasMatch(distanceLabel ?? '')) {
      count++;
    }
    if (familyType != null) count++;
    if (openToDivorced) count++;
    if (genderPref != null) count++;
    if (maritalStatus != null) count++;
    if (hasChildren != null) count++;
    if (educationMin != null) count++;
    if (distanceLabel != null && effectiveMaxDistanceKm == null) count++;
    if (stateName != null || cityId != null) count++;
    if (motherTongue != null) count++;
    if (community != null) count++;
    if (livingExpectation != null) count++;
    if (quranMemorization != null) count++;
    if (marriageTimeline != null) count++;
    if (willingToRelocate != null) count++;
    if (diasporaMode) count++;
    if (!diasporaMode &&
        browseCountries != null &&
        browseCountries!.isNotEmpty) {
      count++;
    }
    return count;
  }

  DiscoveryFilter copyWith({
    int? ageMin,
    int? ageMax,
    String? sect,
    String? deenLevel,
    String? trustFilter,
    bool? activeRecentlyOnly,
    int? maxDistanceKm,
    String? familyType,
    bool? openToDivorced,
    String? genderPref,
    String? maritalStatus,
    String? hasChildren,
    String? educationMin,
    String? distanceLabel,
    String? stateName,
    String? cityId,
    String? cityName,
    String? motherTongue,
    String? community,
    String? livingExpectation,
    String? quranMemorization,
    String? marriageTimeline,
    String? willingToRelocate,
    bool? diasporaMode,
    List<String>? diasporaCountries,
    List<String>? browseCountries,
    // Nulling sentinels
    bool clearSect = false,
    bool clearDeenLevel = false,
    bool clearTrustFilter = false,
    bool clearMaxDistance = false,
    bool clearFamilyType = false,
    bool clearAgeRange = false,
    bool clearGenderPref = false,
    bool clearMaritalStatus = false,
    bool clearHasChildren = false,
    bool clearEducationMin = false,
    bool clearDistanceLabel = false,
    bool clearState = false,
    bool clearCity = false,
    bool clearMotherTongue = false,
    bool clearCommunity = false,
    bool clearLivingExpectation = false,
    bool clearQuranMemorization = false,
    bool clearMarriageTimeline = false,
    bool clearWillingToRelocate = false,
    bool clearDiasporaCountries = false,
    bool clearBrowseCountries = false,
  }) {
    return DiscoveryFilter(
      ageMin: clearAgeRange ? null : (ageMin ?? this.ageMin),
      ageMax: clearAgeRange ? null : (ageMax ?? this.ageMax),
      sect: clearSect ? null : (sect ?? this.sect),
      deenLevel: clearDeenLevel ? null : (deenLevel ?? this.deenLevel),
      trustFilter: clearTrustFilter ? null : (trustFilter ?? this.trustFilter),
      activeRecentlyOnly: activeRecentlyOnly ?? this.activeRecentlyOnly,
      maxDistanceKm:
          clearMaxDistance ? null : (maxDistanceKm ?? this.maxDistanceKm),
      familyType: clearFamilyType ? null : (familyType ?? this.familyType),
      openToDivorced: openToDivorced ?? this.openToDivorced,
      genderPref: clearGenderPref ? null : (genderPref ?? this.genderPref),
      maritalStatus:
          clearMaritalStatus ? null : (maritalStatus ?? this.maritalStatus),
      hasChildren: clearHasChildren ? null : (hasChildren ?? this.hasChildren),
      educationMin:
          clearEducationMin ? null : (educationMin ?? this.educationMin),
      distanceLabel:
          clearDistanceLabel ? null : (distanceLabel ?? this.distanceLabel),
      stateName: clearState ? null : (stateName ?? this.stateName),
      cityId: clearCity ? null : (cityId ?? this.cityId),
      cityName: clearCity ? null : (cityName ?? this.cityName),
      motherTongue:
          clearMotherTongue ? null : (motherTongue ?? this.motherTongue),
      community: clearCommunity ? null : (community ?? this.community),
      livingExpectation: clearLivingExpectation
          ? null
          : (livingExpectation ?? this.livingExpectation),
      quranMemorization: clearQuranMemorization
          ? null
          : (quranMemorization ?? this.quranMemorization),
      marriageTimeline: clearMarriageTimeline
          ? null
          : (marriageTimeline ?? this.marriageTimeline),
      willingToRelocate: clearWillingToRelocate
          ? null
          : (willingToRelocate ?? this.willingToRelocate),
      diasporaMode: diasporaMode ?? this.diasporaMode,
      diasporaCountries: clearDiasporaCountries
          ? null
          : (diasporaCountries ?? this.diasporaCountries),
      browseCountries: clearBrowseCountries
          ? null
          : (browseCountries ?? this.browseCountries),
    );
  }

  static const empty = DiscoveryFilter();
}
