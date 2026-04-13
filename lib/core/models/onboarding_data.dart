// lib/core/models/onboarding_data.dart
// ============================================================
// NOOR — Onboarding Data Accumulator
// An immutable value object that accumulates all onboarding
// field values across all 14 steps using copyWith().
// ============================================================

/// Who the profile is being created for.
enum ProfileFor { myself, guardian }

/// Gender options (matrimony context: binary only).
enum Gender { male, female }

/// Sect options.
enum Sect { sunni, shia, preferNotToSay, other }

/// Deen level options.
enum DeenLevel { practicing, moderate, cultural }

/// Employment status options.
enum EmploymentStatus { employed, selfEmployed, student, notWorking }

/// Marital status options.
enum MaritalStatus { neverMarried, divorced, widowed }

/// Family type options.
enum FamilyType { nuclear, joint, extended }

/// Photo privacy for women.
enum PhotoPrivacy { publicAll, mutualOnly }

/// Location preference for partner.
enum LocationPreference { sameCity, sameCountry, openToAbroad, diaspora }

/// Immutable model that accumulates all form data across onboarding steps.
class OnboardingData {
  const OnboardingData({
    // Step 3 — Profile for whom
    this.profileFor,

    // Step 4 — Basic identity
    this.firstName,
    this.lastName,
    this.dateOfBirth,
    this.gender,
    this.cityId,
    this.cityName,
    this.countryCode,

    // Step 5 — Islamic identity
    this.sect,
    this.subSect,
    this.deenLevel,
    this.praysFiveDaily,
    this.hijabStyle,    // women only
    this.hasBrard,      // men only

    // Step 6 — Background
    this.educationRank,
    this.educationLabel,
    this.fieldOfStudy,
    this.profession,
    this.employmentStatus,

    // Step 7 — Income
    this.incomeBracketId,
    this.incomeBracketLabel,
    this.incomeVisibility,

    // Step 8 — Family
    this.familyType,
    this.siblingCount,
    this.isEldestChild,
    this.parentsStatus,
    this.maritalStatus,
    this.hasChildren,
    this.childrenCount,

    // Step 9 — About yourself
    this.bio,
    this.interests,
    this.languages,

    // Step 10 — Partner preferences
    this.preferredAgeMin,
    this.preferredAgeMax,
    this.locationPreference,
    this.preferredSect,
    this.preferredDeenLevel,
    this.minEducationRank,
    this.openToDivorced,
    this.openToWidowed,
    this.openToWithChildren,

    // Step 11 — Photos
    this.photoLocalPaths,
    this.photoPrivacy,

    // Meta
    this.phone,
    this.guardianName,
    this.guardianRelationship,
  });

  // Step 3
  final ProfileFor? profileFor;

  // Step 4
  final String? firstName;
  final String? lastName;
  final DateTime? dateOfBirth;
  final Gender? gender;
  final String? cityId;
  final String? cityName;
  final String? countryCode;

  // Step 5
  final Sect? sect;
  final String? subSect;
  final DeenLevel? deenLevel;
  final bool? praysFiveDaily;
  final String? hijabStyle;
  final bool? hasBrard;

  // Step 6
  final int? educationRank;
  final String? educationLabel;
  final String? fieldOfStudy;
  final String? profession;
  final EmploymentStatus? employmentStatus;

  // Step 7
  final String? incomeBracketId;
  final String? incomeBracketLabel;
  final String? incomeVisibility;

  // Step 8
  final FamilyType? familyType;
  final int? siblingCount;
  final bool? isEldestChild;
  final String? parentsStatus;
  final MaritalStatus? maritalStatus;
  final bool? hasChildren;
  final int? childrenCount;

  // Step 9
  final String? bio;
  final List<String>? interests;
  final List<String>? languages;

  // Step 10
  final int? preferredAgeMin;
  final int? preferredAgeMax;
  final LocationPreference? locationPreference;
  final String? preferredSect;
  final String? preferredDeenLevel;
  final int? minEducationRank;
  final bool? openToDivorced;
  final bool? openToWidowed;
  final bool? openToWithChildren;

  // Step 11
  final List<String>? photoLocalPaths;
  final PhotoPrivacy? photoPrivacy;

  // Meta
  final String? phone;
  final String? guardianName;
  final String? guardianRelationship;

  OnboardingData copyWith({
    ProfileFor? profileFor,
    String? firstName,
    String? lastName,
    DateTime? dateOfBirth,
    Gender? gender,
    String? cityId,
    String? cityName,
    String? countryCode,
    Sect? sect,
    String? subSect,
    DeenLevel? deenLevel,
    bool? praysFiveDaily,
    String? hijabStyle,
    bool? hasBrard,
    int? educationRank,
    String? educationLabel,
    String? fieldOfStudy,
    String? profession,
    EmploymentStatus? employmentStatus,
    String? incomeBracketId,
    String? incomeBracketLabel,
    String? incomeVisibility,
    FamilyType? familyType,
    int? siblingCount,
    bool? isEldestChild,
    String? parentsStatus,
    MaritalStatus? maritalStatus,
    bool? hasChildren,
    int? childrenCount,
    String? bio,
    List<String>? interests,
    List<String>? languages,
    int? preferredAgeMin,
    int? preferredAgeMax,
    LocationPreference? locationPreference,
    String? preferredSect,
    String? preferredDeenLevel,
    int? minEducationRank,
    bool? openToDivorced,
    bool? openToWidowed,
    bool? openToWithChildren,
    List<String>? photoLocalPaths,
    PhotoPrivacy? photoPrivacy,
    String? phone,
    String? guardianName,
    String? guardianRelationship,
  }) {
    return OnboardingData(
      profileFor:         profileFor          ?? this.profileFor,
      firstName:          firstName           ?? this.firstName,
      lastName:           lastName            ?? this.lastName,
      dateOfBirth:        dateOfBirth         ?? this.dateOfBirth,
      gender:             gender              ?? this.gender,
      cityId:             cityId              ?? this.cityId,
      cityName:           cityName            ?? this.cityName,
      countryCode:        countryCode         ?? this.countryCode,
      sect:               sect                ?? this.sect,
      subSect:            subSect             ?? this.subSect,
      deenLevel:          deenLevel           ?? this.deenLevel,
      praysFiveDaily:     praysFiveDaily      ?? this.praysFiveDaily,
      hijabStyle:         hijabStyle          ?? this.hijabStyle,
      hasBrard:           hasBrard            ?? this.hasBrard,
      educationRank:      educationRank       ?? this.educationRank,
      educationLabel:     educationLabel      ?? this.educationLabel,
      fieldOfStudy:       fieldOfStudy        ?? this.fieldOfStudy,
      profession:         profession          ?? this.profession,
      employmentStatus:   employmentStatus    ?? this.employmentStatus,
      incomeBracketId:    incomeBracketId     ?? this.incomeBracketId,
      incomeBracketLabel: incomeBracketLabel  ?? this.incomeBracketLabel,
      incomeVisibility:   incomeVisibility    ?? this.incomeVisibility,
      familyType:         familyType          ?? this.familyType,
      siblingCount:       siblingCount        ?? this.siblingCount,
      isEldestChild:      isEldestChild       ?? this.isEldestChild,
      parentsStatus:      parentsStatus       ?? this.parentsStatus,
      maritalStatus:      maritalStatus       ?? this.maritalStatus,
      hasChildren:        hasChildren         ?? this.hasChildren,
      childrenCount:      childrenCount       ?? this.childrenCount,
      bio:                bio                 ?? this.bio,
      interests:          interests           ?? this.interests,
      languages:          languages           ?? this.languages,
      preferredAgeMin:    preferredAgeMin     ?? this.preferredAgeMin,
      preferredAgeMax:    preferredAgeMax     ?? this.preferredAgeMax,
      locationPreference: locationPreference  ?? this.locationPreference,
      preferredSect:      preferredSect       ?? this.preferredSect,
      preferredDeenLevel: preferredDeenLevel  ?? this.preferredDeenLevel,
      minEducationRank:   minEducationRank    ?? this.minEducationRank,
      openToDivorced:     openToDivorced      ?? this.openToDivorced,
      openToWidowed:      openToWidowed       ?? this.openToWidowed,
      openToWithChildren: openToWithChildren  ?? this.openToWithChildren,
      photoLocalPaths:    photoLocalPaths     ?? this.photoLocalPaths,
      photoPrivacy:       photoPrivacy        ?? this.photoPrivacy,
      phone:              phone               ?? this.phone,
      guardianName:       guardianName        ?? this.guardianName,
      guardianRelationship: guardianRelationship ?? this.guardianRelationship,
    );
  }

  /// Returns the user's computed age from DOB, or null.
  int? get age {
    if (dateOfBirth == null) return null;
    final now = DateTime.now();
    int years = now.year - dateOfBirth!.year;
    if (now.month < dateOfBirth!.month ||
        (now.month == dateOfBirth!.month && now.day < dateOfBirth!.day)) {
      years--;
    }
    return years;
  }

  /// Display name for the preview card.
  String get displayName {
    final f = firstName ?? '';
    final l = lastName?.isNotEmpty == true ? ' ${lastName![0]}.' : '';
    return '$f$l'.trim();
  }
}
