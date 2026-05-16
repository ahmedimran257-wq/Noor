// lib/core/models/onboarding_data.dart
// ============================================================
// NOOR — Onboarding Data Accumulator
// An immutable value object that accumulates all onboarding
// field values across all steps using copyWith().
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
    this.heightCm,
    this.complexion,
    this.motherTongue,
    this.smokingStatus,
    this.community,

    // Step 5 — Islamic identity
    this.sect,
    this.subSect,
    this.deenLevel,
    this.praysFiveDaily,
    this.hijabStyle,    // women only — maps to profiles.hijab text
    this.beardStyle,    // men only  — maps to profiles.beard text ('yes','no','prefer_not_to_say')
    this.dietType,
    this.smokingHabit,
    this.vapingHabit,
    this.hookahHabit,

    // Step 6 — Background
    this.educationRank,
    this.educationLabel,
    this.fieldOfStudy,
    this.profession,
    this.employmentStatus,

    // Step 7 — Income
    this.incomeBracketId,        // int FK → income_brackets(id)
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
    this.livingExpectation,

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
    this.preferredLivingExpectation,

    // Step 11 — Photos
    this.photoLocalPaths,
    this.photoPrivacy,

    // Islamic marriage details (both genders)
    this.quranMemorization,      // 'none','some_surahs','partial','hafiz'
    this.religiousEducation,     // 'self_taught','madrasa','islamic_uni','alim_course','none'
    this.marriageTimeline,       // 'asap','6_months','1_year','2_plus_years','not_sure'
    this.willingToRelocate,      // 'yes','no','open_to_discussion'

    // Female-specific
    this.niqabPreference,        // 'wears_niqab','open_to_niqab','no_niqab','prefer_not_to_say'
    this.mahrExpectation,        // 'no_preference','modest','moderate','high','to_discuss'
    this.willingToWorkAfterMarriage, // true/false/null

    // Male-specific
    this.mahrBudget,             // 'modest','moderate','generous','to_discuss'
    this.canProvideHousing,      // true/false
    this.canProvideMaintenance,  // true/false
    this.debtStatus,             // 'no_debt','manageable','significant','prefer_not_to_say'
    this.religiousLeadership,    // 'leads_prayer','learning','not_yet','prefer_not_to_say'

    // Meta
    this.phone,
    this.guardianName,
    this.guardianRelationship,
    this.isGuardianMode = false,
    this.guardianPhone,
    this.guardianPhoneCountryCode,
    this.profileCreatorRelation,
    this.guardianEmail,
    this.guardianAuthorityScope,  // 'full','advisory','limited'

    // Phase 1 additions
    this.isRevert,               // 'yes','no','prefer_not_to_say'
    this.polygamyStatus,         // male: 'first_marriage','currently_married','prefer_not_to_say'
    this.polygamyAcceptance,     // female: 'yes','no','open_to_discussion','prefer_not_to_say'
    this.specialNeeds,           // 'none','physical','hearing','visual','other','prefer_not_to_say'
    this.residencyStatus,        // 'citizen','permanent_resident','work_visa','student_visa','other','prefer_not_to_say'
  });

  // Step 3
  final ProfileFor? profileFor;

  // Step 4
  final String?   firstName;
  final String?   lastName;
  final DateTime? dateOfBirth;
  final Gender?   gender;
  final String?   cityId;              // UUID string — matches cities(id) uuid
  final String?   cityName;
  final String?   countryCode;
  final int?      heightCm;          // e.g. 165
  final String?   complexion;        // 'Fair', 'Medium', 'Olive', 'Dark', 'Prefer not to say'
  final String?   motherTongue;      // e.g. 'Urdu', 'Hindi', 'Arabic'
  final String?   smokingStatus;     // 'Non-smoker', 'Occasional', 'Regular', 'Trying to quit'
  final String?   community;         // e.g. 'Syed','Pathan','Ansari','Memon','Rajput', etc.

  // Step 5
  final Sect?    sect;
  final String?  subSect;
  final DeenLevel? deenLevel;
  final bool?    praysFiveDaily;
  final String?  hijabStyle;         // maps to profiles.hijab text
  final String?  beardStyle;         // maps to profiles.beard text ('yes','no','prefer_not_to_say')
  final String?  dietType;       // 'zabiha_strict','halal_only','eats_anything','vegetarian','vegan'
  final String?  smokingHabit;   // 'never','occasionally','frequently','prefer_not'
  final String?  vapingHabit;    // 'never','occasionally','frequently','prefer_not'
  final String?  hookahHabit;    // 'never','occasionally','frequently','prefer_not'

  // Step 6
  final int?              educationRank;
  final String?           educationLabel;
  final String?           fieldOfStudy;
  final String?           profession;
  final EmploymentStatus? employmentStatus;

  // Step 7
  final int?    incomeBracketId;      // int FK → income_brackets(id)
  final String? incomeBracketLabel;
  final String? incomeVisibility;

  // Step 8
  final FamilyType?    familyType;
  final int?           siblingCount;
  final bool?          isEldestChild;
  final String?        parentsStatus;
  final MaritalStatus? maritalStatus;
  final bool?          hasChildren;
  final int?           childrenCount;
  final String?        livingExpectation; // 'with_inlaws','separate','open_to_discussion'

  // Step 9
  final String?       bio;
  final List<String>? interests;
  final List<String>? languages;

  // Step 10
  final int?                preferredAgeMin;
  final int?                preferredAgeMax;
  final LocationPreference? locationPreference;
  final String?             preferredSect;
  final String?             preferredDeenLevel;
  final int?                minEducationRank;
  final bool?               openToDivorced;
  final bool?               openToWidowed;
  final bool?               openToWithChildren;
  final String?             preferredLivingExpectation; // 'with_inlaws','separate','open_to_discussion','no_preference'

  // Step 11
  final List<String>? photoLocalPaths;
  final PhotoPrivacy? photoPrivacy;

  // Islamic marriage details (both genders)
  final String? quranMemorization;
  final String? religiousEducation;
  final String? marriageTimeline;
  final String? willingToRelocate;

  // Female-specific
  final String? niqabPreference;
  final String? mahrExpectation;
  final bool?   willingToWorkAfterMarriage;

  // Male-specific
  final String? mahrBudget;
  final bool?   canProvideHousing;
  final bool?   canProvideMaintenance;
  final String? debtStatus;
  final String? religiousLeadership;

  // Meta
  final String? phone;
  final String? guardianName;
  final String? guardianRelationship;
  final bool    isGuardianMode;
  final String? guardianPhone;
  final String? guardianPhoneCountryCode;
  final String? profileCreatorRelation; // 'self','parent','sibling','guardian'
  final String? guardianEmail;
  final String? guardianAuthorityScope;

  // Phase 1 additions
  final String? isRevert;
  final String? polygamyStatus;
  final String? polygamyAcceptance;
  final String? specialNeeds;
  final String? residencyStatus;

  OnboardingData copyWith({
    ProfileFor? profileFor,
    String?     firstName,
    String?     lastName,
    DateTime?   dateOfBirth,
    Gender?     gender,
    String?     cityId,
    String?     cityName,
    String?     countryCode,
    int?        heightCm,
    String?     complexion,
    String?     motherTongue,
    String?     smokingStatus,
    String?     community,
    Sect?       sect,
    String?     subSect,
    DeenLevel?  deenLevel,
    bool?       praysFiveDaily,
    String?     hijabStyle,
    String?     beardStyle,
    String?     dietType,
    String?     smokingHabit,
    String?     vapingHabit,
    String?     hookahHabit,
    int?        educationRank,
    String?     educationLabel,
    String?     fieldOfStudy,
    String?     profession,
    EmploymentStatus? employmentStatus,
    int?        incomeBracketId,
    String?     incomeBracketLabel,
    String?     incomeVisibility,
    FamilyType? familyType,
    int?        siblingCount,
    bool?       isEldestChild,
    String?     parentsStatus,
    MaritalStatus? maritalStatus,
    bool?       hasChildren,
    int?        childrenCount,
    String?     livingExpectation,
    String?     bio,
    List<String>? interests,
    List<String>? languages,
    int?        preferredAgeMin,
    int?        preferredAgeMax,
    LocationPreference? locationPreference,
    String?     preferredSect,
    String?     preferredDeenLevel,
    int?        minEducationRank,
    bool?       openToDivorced,
    bool?       openToWidowed,
    bool?       openToWithChildren,
    String?     preferredLivingExpectation,
    List<String>? photoLocalPaths,
    PhotoPrivacy? photoPrivacy,
    String?     quranMemorization,
    String?     religiousEducation,
    String?     marriageTimeline,
    String?     willingToRelocate,
    String?     niqabPreference,
    String?     mahrExpectation,
    bool?       willingToWorkAfterMarriage,
    String?     mahrBudget,
    bool?       canProvideHousing,
    bool?       canProvideMaintenance,
    String?     debtStatus,
    String?     religiousLeadership,
    String?     phone,
    String?     guardianName,
    String?     guardianRelationship,
    bool?       isGuardianMode,
    String?     guardianPhone,
    String?     guardianPhoneCountryCode,
    String?     profileCreatorRelation,
    String?     guardianEmail,
    String?     guardianAuthorityScope,
    String?     isRevert,
    String?     polygamyStatus,
    String?     polygamyAcceptance,
    String?     specialNeeds,
    String?     residencyStatus,
  }) {
    return OnboardingData(
      profileFor:               profileFor               ?? this.profileFor,
      firstName:                firstName                ?? this.firstName,
      lastName:                 lastName                 ?? this.lastName,
      dateOfBirth:              dateOfBirth              ?? this.dateOfBirth,
      gender:                   gender                   ?? this.gender,
      cityId:                   cityId                   ?? this.cityId,
      cityName:                 cityName                 ?? this.cityName,
      countryCode:              countryCode              ?? this.countryCode,
      heightCm:                 heightCm                 ?? this.heightCm,
      complexion:               complexion               ?? this.complexion,
      motherTongue:             motherTongue             ?? this.motherTongue,
      smokingStatus:            smokingStatus            ?? this.smokingStatus,
      community:                community                ?? this.community,
      sect:                     sect                     ?? this.sect,
      subSect:                  subSect                  ?? this.subSect,
      deenLevel:                deenLevel                ?? this.deenLevel,
      praysFiveDaily:           praysFiveDaily           ?? this.praysFiveDaily,
      hijabStyle:               hijabStyle               ?? this.hijabStyle,
      beardStyle:               beardStyle               ?? this.beardStyle,
      dietType:                 dietType                 ?? this.dietType,
      smokingHabit:             smokingHabit             ?? this.smokingHabit,
      vapingHabit:              vapingHabit              ?? this.vapingHabit,
      hookahHabit:              hookahHabit              ?? this.hookahHabit,
      educationRank:            educationRank            ?? this.educationRank,
      educationLabel:           educationLabel           ?? this.educationLabel,
      fieldOfStudy:             fieldOfStudy             ?? this.fieldOfStudy,
      profession:               profession               ?? this.profession,
      employmentStatus:         employmentStatus         ?? this.employmentStatus,
      incomeBracketId:          incomeBracketId          ?? this.incomeBracketId,
      incomeBracketLabel:       incomeBracketLabel       ?? this.incomeBracketLabel,
      incomeVisibility:         incomeVisibility         ?? this.incomeVisibility,
      familyType:               familyType               ?? this.familyType,
      siblingCount:             siblingCount             ?? this.siblingCount,
      isEldestChild:            isEldestChild            ?? this.isEldestChild,
      parentsStatus:            parentsStatus            ?? this.parentsStatus,
      maritalStatus:            maritalStatus            ?? this.maritalStatus,
      hasChildren:              hasChildren              ?? this.hasChildren,
      childrenCount:            childrenCount            ?? this.childrenCount,
      livingExpectation:        livingExpectation        ?? this.livingExpectation,
      bio:                      bio                      ?? this.bio,
      interests:                interests                ?? this.interests,
      languages:                languages                ?? this.languages,
      preferredAgeMin:          preferredAgeMin          ?? this.preferredAgeMin,
      preferredAgeMax:          preferredAgeMax          ?? this.preferredAgeMax,
      locationPreference:       locationPreference       ?? this.locationPreference,
      preferredSect:            preferredSect            ?? this.preferredSect,
      preferredDeenLevel:       preferredDeenLevel       ?? this.preferredDeenLevel,
      minEducationRank:         minEducationRank         ?? this.minEducationRank,
      openToDivorced:           openToDivorced           ?? this.openToDivorced,
      openToWidowed:            openToWidowed            ?? this.openToWidowed,
      openToWithChildren:       openToWithChildren       ?? this.openToWithChildren,
      preferredLivingExpectation: preferredLivingExpectation ?? this.preferredLivingExpectation,
      photoLocalPaths:          photoLocalPaths          ?? this.photoLocalPaths,
      photoPrivacy:             photoPrivacy             ?? this.photoPrivacy,
      quranMemorization:        quranMemorization        ?? this.quranMemorization,
      religiousEducation:       religiousEducation       ?? this.religiousEducation,
      marriageTimeline:         marriageTimeline         ?? this.marriageTimeline,
      willingToRelocate:        willingToRelocate        ?? this.willingToRelocate,
      niqabPreference:          niqabPreference          ?? this.niqabPreference,
      mahrExpectation:          mahrExpectation          ?? this.mahrExpectation,
      willingToWorkAfterMarriage: willingToWorkAfterMarriage ?? this.willingToWorkAfterMarriage,
      mahrBudget:               mahrBudget               ?? this.mahrBudget,
      canProvideHousing:        canProvideHousing        ?? this.canProvideHousing,
      canProvideMaintenance:    canProvideMaintenance    ?? this.canProvideMaintenance,
      debtStatus:               debtStatus               ?? this.debtStatus,
      religiousLeadership:      religiousLeadership      ?? this.religiousLeadership,
      phone:                    phone                    ?? this.phone,
      guardianName:             guardianName             ?? this.guardianName,
      guardianRelationship:     guardianRelationship     ?? this.guardianRelationship,
      isGuardianMode:           isGuardianMode           ?? this.isGuardianMode,
      guardianPhone:            guardianPhone            ?? this.guardianPhone,
      guardianPhoneCountryCode: guardianPhoneCountryCode ?? this.guardianPhoneCountryCode,
      profileCreatorRelation:   profileCreatorRelation   ?? this.profileCreatorRelation,
      guardianEmail:            guardianEmail            ?? this.guardianEmail,
      guardianAuthorityScope:   guardianAuthorityScope   ?? this.guardianAuthorityScope,
      isRevert:                 isRevert                 ?? this.isRevert,
      polygamyStatus:           polygamyStatus           ?? this.polygamyStatus,
      polygamyAcceptance:       polygamyAcceptance       ?? this.polygamyAcceptance,
      specialNeeds:             specialNeeds             ?? this.specialNeeds,
      residencyStatus:          residencyStatus          ?? this.residencyStatus,
    );
  }

  /// Maps the Flutter MaritalStatus enum to the DB `previously_married` text column.
  /// DB values: 'no', 'divorced', 'widowed'
  String? get previouslyMarried {
    if (maritalStatus == null) return null;
    switch (maritalStatus!) {
      case MaritalStatus.neverMarried: return 'no';
      case MaritalStatus.divorced:     return 'divorced';
      case MaritalStatus.widowed:      return 'widowed';
    }
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
