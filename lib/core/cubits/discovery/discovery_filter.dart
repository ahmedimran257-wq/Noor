// lib/core/cubits/discovery/discovery_filter.dart
// ============================================================
// NOOR — Discovery Filter Model
// Active filter selections, serialisation helpers, and
// label generation for the chip bar.
//
// Blueprint (Part 8, Search & Filters):
//   "Age range dual slider. Sect and sub-sect. Deen level.
//    Verified only. Active recently. Distance radius."
// ============================================================

class DiscoveryFilter {
  const DiscoveryFilter({
    this.ageMin,
    this.ageMax,
    this.sect,
    this.deenLevel,
    this.verifiedOnly      = false,
    this.activeRecentlyOnly = false,
    this.maxDistanceKm,
    this.familyType,
    this.openToDivorced    = false,
  });

  final int?    ageMin;
  final int?    ageMax;
  final String? sect;        // 'Sunni' | 'Shia' | etc.
  final String? deenLevel;   // 'practicing' | 'moderate' | 'cultural'
  final bool    verifiedOnly;
  final bool    activeRecentlyOnly;
  final int?    maxDistanceKm;
  final String? familyType;  // 'Nuclear' | 'Joint' | 'Extended'
  final bool    openToDivorced;

  // Whether any filter is active
  bool get isActive =>
      ageMin != null ||
      ageMax != null ||
      sect != null ||
      deenLevel != null ||
      verifiedOnly ||
      activeRecentlyOnly ||
      maxDistanceKm != null ||
      familyType != null ||
      openToDivorced;

  // How many filters are active (for badge count)
  int get activeCount {
    int count = 0;
    if (ageMin != null || ageMax != null) count++;
    if (sect != null) count++;
    if (deenLevel != null) count++;
    if (verifiedOnly) count++;
    if (activeRecentlyOnly) count++;
    if (maxDistanceKm != null) count++;
    if (familyType != null) count++;
    if (openToDivorced) count++;
    return count;
  }

  DiscoveryFilter copyWith({
    int?    ageMin,
    int?    ageMax,
    String? sect,
    String? deenLevel,
    bool?   verifiedOnly,
    bool?   activeRecentlyOnly,
    int?    maxDistanceKm,
    String? familyType,
    bool?   openToDivorced,
    // Nulling sentinel: pass empty string to clear optional strings
    bool clearSect        = false,
    bool clearDeenLevel   = false,
    bool clearMaxDistance = false,
    bool clearFamilyType  = false,
    bool clearAgeRange    = false,
  }) {
    return DiscoveryFilter(
      ageMin:             clearAgeRange    ? null : (ageMin       ?? this.ageMin),
      ageMax:             clearAgeRange    ? null : (ageMax       ?? this.ageMax),
      sect:               clearSect        ? null : (sect         ?? this.sect),
      deenLevel:          clearDeenLevel   ? null : (deenLevel    ?? this.deenLevel),
      verifiedOnly:       verifiedOnly      ?? this.verifiedOnly,
      activeRecentlyOnly: activeRecentlyOnly ?? this.activeRecentlyOnly,
      maxDistanceKm:      clearMaxDistance ? null : (maxDistanceKm ?? this.maxDistanceKm),
      familyType:         clearFamilyType  ? null : (familyType   ?? this.familyType),
      openToDivorced:     openToDivorced    ?? this.openToDivorced,
    );
  }

  static const empty = DiscoveryFilter();
}
