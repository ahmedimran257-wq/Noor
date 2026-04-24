// lib/core/cubits/discovery/discovery_filter.dart
// ============================================================
// NOOR — Discovery Filter Model
// Active filter selections, serialisation helpers, and
// label generation for the chip bar.
// ============================================================

class DiscoveryFilter {
  const DiscoveryFilter({
    this.ageMin,
    this.ageMax,
    this.sect,
    this.deenLevel,
    this.verifiedOnly       = false,
    this.activeRecentlyOnly = false,
    this.maxDistanceKm,
    this.familyType,
    this.openToDivorced     = false,
    // New fields (Feature 8)
    this.genderPref,       // 'Any' | 'Male' | 'Female'
    this.maritalStatus,    // 'Never Married' | 'Divorced' | 'Widowed' | 'Any'
    this.hasChildren,      // "Doesn't matter" | 'No' | 'Yes'
    this.educationMin,     // "Any" | "Matric" | ... | "PhD"
    this.distanceLabel,    // "Same City" | "50km" | ...
  });

  final int?    ageMin;
  final int?    ageMax;
  final String? sect;
  final String? deenLevel;
  final bool    verifiedOnly;
  final bool    activeRecentlyOnly;
  final int?    maxDistanceKm;
  final String? familyType;
  final bool    openToDivorced;

  // Extended
  final String? genderPref;
  final String? maritalStatus;
  final String? hasChildren;
  final String? educationMin;
  final String? distanceLabel;

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
      openToDivorced ||
      genderPref != null ||
      maritalStatus != null ||
      hasChildren != null ||
      educationMin != null ||
      distanceLabel != null;

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
    if (genderPref != null) count++;
    if (maritalStatus != null) count++;
    if (hasChildren != null) count++;
    if (educationMin != null) count++;
    if (distanceLabel != null) count++;
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
    String? genderPref,
    String? maritalStatus,
    String? hasChildren,
    String? educationMin,
    String? distanceLabel,
    // Nulling sentinels
    bool clearSect         = false,
    bool clearDeenLevel    = false,
    bool clearMaxDistance  = false,
    bool clearFamilyType   = false,
    bool clearAgeRange     = false,
    bool clearGenderPref   = false,
    bool clearMaritalStatus= false,
    bool clearHasChildren  = false,
    bool clearEducationMin = false,
    bool clearDistanceLabel= false,
  }) {
    return DiscoveryFilter(
      ageMin:             clearAgeRange       ? null : (ageMin        ?? this.ageMin),
      ageMax:             clearAgeRange       ? null : (ageMax        ?? this.ageMax),
      sect:               clearSect           ? null : (sect          ?? this.sect),
      deenLevel:          clearDeenLevel      ? null : (deenLevel     ?? this.deenLevel),
      verifiedOnly:       verifiedOnly        ?? this.verifiedOnly,
      activeRecentlyOnly: activeRecentlyOnly  ?? this.activeRecentlyOnly,
      maxDistanceKm:      clearMaxDistance    ? null : (maxDistanceKm ?? this.maxDistanceKm),
      familyType:         clearFamilyType     ? null : (familyType    ?? this.familyType),
      openToDivorced:     openToDivorced      ?? this.openToDivorced,
      genderPref:         clearGenderPref     ? null : (genderPref    ?? this.genderPref),
      maritalStatus:      clearMaritalStatus  ? null : (maritalStatus ?? this.maritalStatus),
      hasChildren:        clearHasChildren    ? null : (hasChildren   ?? this.hasChildren),
      educationMin:       clearEducationMin   ? null : (educationMin  ?? this.educationMin),
      distanceLabel:      clearDistanceLabel  ? null : (distanceLabel ?? this.distanceLabel),
    );
  }

  static const empty = DiscoveryFilter();
}
