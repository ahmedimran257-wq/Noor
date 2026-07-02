// lib/core/models/onboarding_data.dart
// ============================================================
// MITHAQ — Onboarding Data Accumulator
// An immutable value object that accumulates all onboarding
// field values across all steps using copyWith().
// ============================================================

/// Who the profile is being created for.
enum ProfileFor { myself, guardian }

/// Explicit owner-type field for the fast-start branch.
enum ProfileOwnerType { self, guardian }

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
enum PhotoPrivacy { publicAll, mutualOnly, requestOnly }

/// Location preference for partner.
enum LocationPreference { sameCity, sameCountry, openToAbroad, diaspora }

/// Immutable model shared by fast-start onboarding and profile completion.
class OnboardingData {
  const OnboardingData({
    // Fast-start: profile owner
    this.profileFor,
    this.profileOwnerType,
    this.wardRelationship,
    this.wardGender,

    // Fast-start: identity and confirmed location
    this.firstName,
    this.lastName,
    this.dateOfBirth,
    this.gender,
    this.cityId,
    this.cityName,
    this.stateName,
    this.countryCode,
    this.heightCm,
    this.complexion,
    this.motherTongue,
    this.smokingStatus,
    this.community,

    // Fast-start: Islamic identity
    this.sect,
    this.subSect,
    this.deenLevel,
    this.praysFiveDaily,
    this.hijabStyle, // women only — maps to profiles.hijab text
    this.beardStyle, // men only  — maps to profiles.beard text ('yes','no','prefer_not_to_say')
    this.dietType,
    this.smokingHabit,
    this.vapingHabit,
    this.hookahHabit,

    // Profile completion: education and work
    this.educationRank,
    this.educationLabel,
    this.fieldOfStudy,
    this.profession,
    this.employmentStatus,

    // Profile completion: income
    this.incomeBracketId, // int FK → income_brackets(id)
    this.incomeBracketLabel,
    this.incomeVisibility,

    // Profile completion: family
    this.familyType,
    this.siblingCount,
    this.isEldestChild,
    this.parentsStatus,
    this.maritalStatus,
    this.hasChildren,
    this.childrenCount,
    this.livingExpectation,

    // Profile completion: bio and interests
    this.bio,
    this.interests,
    this.languages,

    // Discovery preferences
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

    // Photo and privacy
    this.photoLocalPaths,
    this.photoPrivacy,

    // Islamic marriage details (both genders)
    this.quranMemorization, // 'none','some_surahs','partial','hafiz'
    this.religiousEducation, // 'self_taught','madrasa','islamic_uni','alim_course','none'
    this.marriageTimeline, // 'asap','6_months','1_year','2_plus_years','not_sure'
    this.willingToRelocate, // 'yes','no','open_to_discussion'

    // Female-specific
    this.niqabPreference, // 'wears_niqab','open_to_niqab','no_niqab','prefer_not_to_say'
    this.mahrExpectation, // 'no_preference','modest','moderate','high','to_discuss'
    this.willingToWorkAfterMarriage, // true/false/null

    // Male-specific
    this.mahrBudget, // 'modest','moderate','generous','to_discuss'
    this.canProvideHousing, // true/false
    this.canProvideMaintenance, // true/false
    this.debtStatus, // 'no_debt','manageable','significant','prefer_not_to_say'
    this.religiousLeadership, // 'leads_prayer','learning','not_yet','prefer_not_to_say'

    // Meta
    this.email,
    this.phone,
    this.guardianName,
    this.guardianRelationship,
    this.isGuardianMode = false,
    this.guardianPhone,
    this.guardianPhoneCountryCode,
    this.profileCreatorRelation,
    this.guardianEmail,
    this.guardianAuthorityScope, // 'full','advisory','limited'
    this.guardianMode, // 'passive','active'

    // Phase 1 additions
    this.isRevert, // 'yes','no','prefer_not_to_say'
    this.polygamyStatus, // male: 'first_marriage','currently_married','prefer_not_to_say'
    this.polygamyAcceptance, // female: 'yes','no','open_to_discussion','prefer_not_to_say'
    this.specialNeeds, // 'none','physical','hearing','visual','other','prefer_not_to_say'
    this.residencyStatus, // 'citizen','permanent_resident','work_visa','student_visa','other','prefer_not_to_say'

    // Geo fields
    this.postalCode,
    this.lat,
    this.lng,
  });

  // Fast-start: profile owner
  final ProfileFor? profileFor;
  final ProfileOwnerType? profileOwnerType;
  final String? wardRelationship; // 'son','daughter','brother','sister'
  final Gender? wardGender; // Derived from wardRelationship for guardian flow.

  // Fast-start: identity and confirmed location
  final String? firstName;
  final String? lastName;
  final DateTime? dateOfBirth;
  final Gender? gender;
  final String? cityId; // Database city id as a string; persisted as INT.
  final String? cityName;
  final String? stateName;
  final String? countryCode;
  final int? heightCm; // e.g. 165
  final String?
      complexion; // 'Fair', 'Medium', 'Olive', 'Dark', 'Prefer not to say'
  final String? motherTongue; // e.g. 'Urdu', 'Hindi', 'Arabic'
  final String?
      smokingStatus; // 'Non-smoker', 'Occasional', 'Regular', 'Trying to quit'
  final String?
      community; // e.g. 'Syed','Pathan','Ansari','Memon','Rajput', etc.

  // Fast-start: Islamic identity
  final Sect? sect;
  final String? subSect;
  final DeenLevel? deenLevel;
  final bool? praysFiveDaily;
  final String? hijabStyle; // maps to profiles.hijab text
  final String?
      beardStyle; // maps to profiles.beard text ('yes','no','prefer_not_to_say')
  final String?
      dietType; // 'zabiha_strict','halal_only','eats_anything','vegetarian','vegan'
  final String?
      smokingHabit; // 'never','occasionally','frequently','prefer_not'
  final String? vapingHabit; // 'never','occasionally','frequently','prefer_not'
  final String? hookahHabit; // 'never','occasionally','frequently','prefer_not'

  // Profile completion: education and work
  final int? educationRank;
  final String? educationLabel;
  final String? fieldOfStudy;
  final String? profession;
  final EmploymentStatus? employmentStatus;

  // Profile completion: income
  final int? incomeBracketId; // int FK → income_brackets(id)
  final String? incomeBracketLabel;
  final String? incomeVisibility;

  // Profile completion: family
  final FamilyType? familyType;
  final int? siblingCount;
  final bool? isEldestChild;
  final String? parentsStatus;
  final MaritalStatus? maritalStatus;
  final bool? hasChildren;
  final int? childrenCount;
  final String?
      livingExpectation; // 'with_inlaws','separate','open_to_discussion'

  // Profile completion: bio and interests
  final String? bio;
  final List<String>? interests;
  final List<String>? languages;

  // Discovery preferences
  final int? preferredAgeMin;
  final int? preferredAgeMax;
  final LocationPreference? locationPreference;
  final String? preferredSect;
  final String? preferredDeenLevel;
  final int? minEducationRank;
  final bool? openToDivorced;
  final bool? openToWidowed;
  final bool? openToWithChildren;
  final String?
      preferredLivingExpectation; // 'with_inlaws','separate','open_to_discussion','no_preference'

  // Photo and privacy
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
  final bool? willingToWorkAfterMarriage;

  // Male-specific
  final String? mahrBudget;
  final bool? canProvideHousing;
  final bool? canProvideMaintenance;
  final String? debtStatus;
  final String? religiousLeadership;

  // Meta
  final String? email;
  final String? phone;
  final String? guardianName;
  final String? guardianRelationship;
  final bool isGuardianMode;
  final String? guardianPhone;
  final String? guardianPhoneCountryCode;
  final String?
      profileCreatorRelation; // 'self','son','daughter','brother','sister'
  final String? guardianEmail;
  final String? guardianAuthorityScope;
  final String? guardianMode; // 'passive' or 'active'

  // Phase 1 additions
  final String? isRevert;
  final String? polygamyStatus;
  final String? polygamyAcceptance;
  final String? specialNeeds;
  final String? residencyStatus;

  // Geo fields
  final String? postalCode;
  final double? lat;
  final double? lng;

  OnboardingData copyWith({
    ProfileFor? profileFor,
    ProfileOwnerType? profileOwnerType,
    String? wardRelationship,
    Gender? wardGender,
    String? firstName,
    String? lastName,
    DateTime? dateOfBirth,
    Gender? gender,
    String? cityId,
    String? cityName,
    String? stateName,
    String? countryCode,
    int? heightCm,
    String? complexion,
    String? motherTongue,
    String? smokingStatus,
    String? community,
    Sect? sect,
    String? subSect,
    DeenLevel? deenLevel,
    bool? praysFiveDaily,
    String? hijabStyle,
    String? beardStyle,
    String? dietType,
    String? smokingHabit,
    String? vapingHabit,
    String? hookahHabit,
    int? educationRank,
    String? educationLabel,
    String? fieldOfStudy,
    String? profession,
    EmploymentStatus? employmentStatus,
    int? incomeBracketId,
    String? incomeBracketLabel,
    String? incomeVisibility,
    FamilyType? familyType,
    int? siblingCount,
    bool? isEldestChild,
    String? parentsStatus,
    MaritalStatus? maritalStatus,
    bool? hasChildren,
    int? childrenCount,
    String? livingExpectation,
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
    String? preferredLivingExpectation,
    List<String>? photoLocalPaths,
    PhotoPrivacy? photoPrivacy,
    String? quranMemorization,
    String? religiousEducation,
    String? marriageTimeline,
    String? willingToRelocate,
    String? niqabPreference,
    String? mahrExpectation,
    bool? willingToWorkAfterMarriage,
    String? mahrBudget,
    bool? canProvideHousing,
    bool? canProvideMaintenance,
    String? debtStatus,
    String? religiousLeadership,
    String? email,
    String? phone,
    String? guardianName,
    String? guardianRelationship,
    bool? isGuardianMode,
    String? guardianPhone,
    String? guardianPhoneCountryCode,
    String? profileCreatorRelation,
    String? guardianEmail,
    String? guardianAuthorityScope,
    String? guardianMode,
    String? isRevert,
    String? polygamyStatus,
    String? polygamyAcceptance,
    String? specialNeeds,
    String? residencyStatus,
    String? postalCode,
    double? lat,
    double? lng,
  }) {
    return OnboardingData(
      profileFor: profileFor ?? this.profileFor,
      profileOwnerType: profileOwnerType ?? this.profileOwnerType,
      wardRelationship: wardRelationship ?? this.wardRelationship,
      wardGender: wardGender ?? this.wardGender,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      gender: gender ?? this.gender,
      cityId: cityId ?? this.cityId,
      cityName: cityName ?? this.cityName,
      stateName: stateName ?? this.stateName,
      countryCode: countryCode ?? this.countryCode,
      heightCm: heightCm ?? this.heightCm,
      complexion: complexion ?? this.complexion,
      motherTongue: motherTongue ?? this.motherTongue,
      smokingStatus: smokingStatus ?? this.smokingStatus,
      community: community ?? this.community,
      sect: sect ?? this.sect,
      subSect: subSect ?? this.subSect,
      deenLevel: deenLevel ?? this.deenLevel,
      praysFiveDaily: praysFiveDaily ?? this.praysFiveDaily,
      hijabStyle: hijabStyle ?? this.hijabStyle,
      beardStyle: beardStyle ?? this.beardStyle,
      dietType: dietType ?? this.dietType,
      smokingHabit: smokingHabit ?? this.smokingHabit,
      vapingHabit: vapingHabit ?? this.vapingHabit,
      hookahHabit: hookahHabit ?? this.hookahHabit,
      educationRank: educationRank ?? this.educationRank,
      educationLabel: educationLabel ?? this.educationLabel,
      fieldOfStudy: fieldOfStudy ?? this.fieldOfStudy,
      profession: profession ?? this.profession,
      employmentStatus: employmentStatus ?? this.employmentStatus,
      incomeBracketId: incomeBracketId ?? this.incomeBracketId,
      incomeBracketLabel: incomeBracketLabel ?? this.incomeBracketLabel,
      incomeVisibility: incomeVisibility ?? this.incomeVisibility,
      familyType: familyType ?? this.familyType,
      siblingCount: siblingCount ?? this.siblingCount,
      isEldestChild: isEldestChild ?? this.isEldestChild,
      parentsStatus: parentsStatus ?? this.parentsStatus,
      maritalStatus: maritalStatus ?? this.maritalStatus,
      hasChildren: hasChildren ?? this.hasChildren,
      childrenCount: childrenCount ?? this.childrenCount,
      livingExpectation: livingExpectation ?? this.livingExpectation,
      bio: bio ?? this.bio,
      interests: interests ?? this.interests,
      languages: languages ?? this.languages,
      preferredAgeMin: preferredAgeMin ?? this.preferredAgeMin,
      preferredAgeMax: preferredAgeMax ?? this.preferredAgeMax,
      locationPreference: locationPreference ?? this.locationPreference,
      preferredSect: preferredSect ?? this.preferredSect,
      preferredDeenLevel: preferredDeenLevel ?? this.preferredDeenLevel,
      minEducationRank: minEducationRank ?? this.minEducationRank,
      openToDivorced: openToDivorced ?? this.openToDivorced,
      openToWidowed: openToWidowed ?? this.openToWidowed,
      openToWithChildren: openToWithChildren ?? this.openToWithChildren,
      preferredLivingExpectation:
          preferredLivingExpectation ?? this.preferredLivingExpectation,
      photoLocalPaths: photoLocalPaths ?? this.photoLocalPaths,
      photoPrivacy: photoPrivacy ?? this.photoPrivacy,
      quranMemorization: quranMemorization ?? this.quranMemorization,
      religiousEducation: religiousEducation ?? this.religiousEducation,
      marriageTimeline: marriageTimeline ?? this.marriageTimeline,
      willingToRelocate: willingToRelocate ?? this.willingToRelocate,
      niqabPreference: niqabPreference ?? this.niqabPreference,
      mahrExpectation: mahrExpectation ?? this.mahrExpectation,
      willingToWorkAfterMarriage:
          willingToWorkAfterMarriage ?? this.willingToWorkAfterMarriage,
      mahrBudget: mahrBudget ?? this.mahrBudget,
      canProvideHousing: canProvideHousing ?? this.canProvideHousing,
      canProvideMaintenance:
          canProvideMaintenance ?? this.canProvideMaintenance,
      debtStatus: debtStatus ?? this.debtStatus,
      religiousLeadership: religiousLeadership ?? this.religiousLeadership,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      guardianName: guardianName ?? this.guardianName,
      guardianRelationship: guardianRelationship ?? this.guardianRelationship,
      isGuardianMode: isGuardianMode ?? this.isGuardianMode,
      guardianPhone: guardianPhone ?? this.guardianPhone,
      guardianPhoneCountryCode:
          guardianPhoneCountryCode ?? this.guardianPhoneCountryCode,
      profileCreatorRelation:
          profileCreatorRelation ?? this.profileCreatorRelation,
      guardianEmail: guardianEmail ?? this.guardianEmail,
      guardianAuthorityScope:
          guardianAuthorityScope ?? this.guardianAuthorityScope,
      guardianMode: guardianMode ?? this.guardianMode,
      isRevert: isRevert ?? this.isRevert,
      polygamyStatus: polygamyStatus ?? this.polygamyStatus,
      polygamyAcceptance: polygamyAcceptance ?? this.polygamyAcceptance,
      specialNeeds: specialNeeds ?? this.specialNeeds,
      residencyStatus: residencyStatus ?? this.residencyStatus,
      postalCode: postalCode ?? this.postalCode,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
    );
  }

  /// Maps the Flutter MaritalStatus enum to the DB `previously_married` text column.
  /// DB values: 'no', 'divorced', 'widowed'
  String? get previouslyMarried {
    if (maritalStatus == null) return null;
    switch (maritalStatus!) {
      case MaritalStatus.neverMarried:
        return 'no';
      case MaritalStatus.divorced:
        return 'divorced';
      case MaritalStatus.widowed:
        return 'widowed';
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

  Map<String, dynamic> toJson() {
    return {
      'profileFor': profileFor?.name,
      'profileOwnerType': profileOwnerType?.name,
      'wardRelationship': wardRelationship,
      'wardGender': wardGender?.name,
      'firstName': firstName,
      'lastName': lastName,
      'dateOfBirth': dateOfBirth?.toIso8601String(),
      'gender': gender?.name,
      'cityId': cityId,
      'cityName': cityName,
      'stateName': stateName,
      'countryCode': countryCode,
      'heightCm': heightCm,
      'complexion': complexion,
      'motherTongue': motherTongue,
      'smokingStatus': smokingStatus,
      'community': community,
      'sect': sect?.name,
      'subSect': subSect,
      'deenLevel': deenLevel?.name,
      'praysFiveDaily': praysFiveDaily,
      'hijabStyle': hijabStyle,
      'beardStyle': beardStyle,
      'dietType': dietType,
      'smokingHabit': smokingHabit,
      'vapingHabit': vapingHabit,
      'hookahHabit': hookahHabit,
      'educationRank': educationRank,
      'educationLabel': educationLabel,
      'fieldOfStudy': fieldOfStudy,
      'profession': profession,
      'employmentStatus': employmentStatus?.name,
      'incomeBracketId': incomeBracketId,
      'incomeBracketLabel': incomeBracketLabel,
      'incomeVisibility': incomeVisibility,
      'familyType': familyType?.name,
      'siblingCount': siblingCount,
      'isEldestChild': isEldestChild,
      'parentsStatus': parentsStatus,
      'maritalStatus': maritalStatus?.name,
      'hasChildren': hasChildren,
      'childrenCount': childrenCount,
      'livingExpectation': livingExpectation,
      'bio': bio,
      'interests': interests,
      'languages': languages,
      'preferredAgeMin': preferredAgeMin,
      'preferredAgeMax': preferredAgeMax,
      'locationPreference': locationPreference?.name,
      'preferredSect': preferredSect,
      'preferredDeenLevel': preferredDeenLevel,
      'minEducationRank': minEducationRank,
      'openToDivorced': openToDivorced,
      'openToWidowed': openToWidowed,
      'openToWithChildren': openToWithChildren,
      'preferredLivingExpectation': preferredLivingExpectation,
      'photoLocalPaths': photoLocalPaths,
      'photoPrivacy': photoPrivacy?.name,
      'quranMemorization': quranMemorization,
      'religiousEducation': religiousEducation,
      'marriageTimeline': marriageTimeline,
      'willingToRelocate': willingToRelocate,
      'niqabPreference': niqabPreference,
      'mahrExpectation': mahrExpectation,
      'willingToWorkAfterMarriage': willingToWorkAfterMarriage,
      'mahrBudget': mahrBudget,
      'canProvideHousing': canProvideHousing,
      'canProvideMaintenance': canProvideMaintenance,
      'debtStatus': debtStatus,
      'religiousLeadership': religiousLeadership,
      'email': email,
      'phone': phone,
      'guardianName': guardianName,
      'guardianRelationship': guardianRelationship,
      'isGuardianMode': isGuardianMode,
      'guardianPhone': guardianPhone,
      'guardianPhoneCountryCode': guardianPhoneCountryCode,
      'profileCreatorRelation': profileCreatorRelation,
      'guardianEmail': guardianEmail,
      'guardianAuthorityScope': guardianAuthorityScope,
      'guardianMode': guardianMode,
      'isRevert': isRevert,
      'polygamyStatus': polygamyStatus,
      'polygamyAcceptance': polygamyAcceptance,
      'specialNeeds': specialNeeds,
      'residencyStatus': residencyStatus,
      'postalCode': postalCode,
      'lat': lat,
      'lng': lng,
    };
  }

  factory OnboardingData.fromJson(Map<String, dynamic> json) {
    return OnboardingData(
      profileFor: json['profileFor'] != null
          ? ProfileFor.values.byName(json['profileFor'] as String)
          : null,
      profileOwnerType: json['profileOwnerType'] != null
          ? ProfileOwnerType.values.byName(json['profileOwnerType'] as String)
          : null,
      wardRelationship: json['wardRelationship'] as String?,
      wardGender: json['wardGender'] != null
          ? Gender.values.byName(json['wardGender'] as String)
          : null,
      firstName: json['firstName'] as String?,
      lastName: json['lastName'] as String?,
      dateOfBirth: json['dateOfBirth'] != null
          ? DateTime.tryParse(json['dateOfBirth'] as String)
          : null,
      gender: json['gender'] != null
          ? Gender.values.byName(json['gender'] as String)
          : null,
      cityId: json['cityId'] as String?,
      cityName: json['cityName'] as String?,
      stateName: json['stateName'] as String?,
      countryCode: json['countryCode'] as String?,
      heightCm: json['heightCm'] as int?,
      complexion: json['complexion'] as String?,
      motherTongue: json['motherTongue'] as String?,
      smokingStatus: json['smokingStatus'] as String?,
      community: json['community'] as String?,
      sect: json['sect'] != null
          ? Sect.values.byName(json['sect'] as String)
          : null,
      subSect: json['subSect'] as String?,
      deenLevel: json['deenLevel'] != null
          ? DeenLevel.values.byName(json['deenLevel'] as String)
          : null,
      praysFiveDaily: json['praysFiveDaily'] as bool?,
      hijabStyle: json['hijabStyle'] as String?,
      beardStyle: json['beardStyle'] as String?,
      dietType: json['dietType'] as String?,
      smokingHabit: json['smokingHabit'] as String?,
      vapingHabit: json['vapingHabit'] as String?,
      hookahHabit: json['hookahHabit'] as String?,
      educationRank: json['educationRank'] as int?,
      educationLabel: json['educationLabel'] as String?,
      fieldOfStudy: json['fieldOfStudy'] as String?,
      profession: json['profession'] as String?,
      employmentStatus: json['employmentStatus'] != null
          ? EmploymentStatus.values.byName(json['employmentStatus'] as String)
          : null,
      incomeBracketId: json['incomeBracketId'] as int?,
      incomeBracketLabel: json['incomeBracketLabel'] as String?,
      incomeVisibility: json['incomeVisibility'] as String?,
      familyType: json['familyType'] != null
          ? FamilyType.values.byName(json['familyType'] as String)
          : null,
      siblingCount: json['siblingCount'] as int?,
      isEldestChild: json['isEldestChild'] as bool?,
      parentsStatus: json['parentsStatus'] as String?,
      maritalStatus: json['maritalStatus'] != null
          ? MaritalStatus.values.byName(json['maritalStatus'] as String)
          : null,
      hasChildren: json['hasChildren'] as bool?,
      childrenCount: json['childrenCount'] as int?,
      livingExpectation: json['livingExpectation'] as String?,
      bio: json['bio'] as String?,
      interests: json['interests'] != null
          ? List<String>.from(json['interests'] as Iterable)
          : null,
      languages: json['languages'] != null
          ? List<String>.from(json['languages'] as Iterable)
          : null,
      preferredAgeMin: json['preferredAgeMin'] as int?,
      preferredAgeMax: json['preferredAgeMax'] as int?,
      locationPreference: json['locationPreference'] != null
          ? LocationPreference.values
              .byName(json['locationPreference'] as String)
          : null,
      preferredSect: json['preferredSect'] as String?,
      preferredDeenLevel: json['preferredDeenLevel'] as String?,
      minEducationRank: json['minEducationRank'] as int?,
      openToDivorced: json['openToDivorced'] as bool?,
      openToWidowed: json['openToWidowed'] as bool?,
      openToWithChildren: json['openToWithChildren'] as bool?,
      preferredLivingExpectation: json['preferredLivingExpectation'] as String?,
      photoLocalPaths: json['photoLocalPaths'] != null
          ? List<String>.from(json['photoLocalPaths'] as Iterable)
          : null,
      photoPrivacy: json['photoPrivacy'] != null
          ? PhotoPrivacy.values.byName(json['photoPrivacy'] as String)
          : null,
      quranMemorization: json['quranMemorization'] as String?,
      religiousEducation: json['religiousEducation'] as String?,
      marriageTimeline: json['marriageTimeline'] as String?,
      willingToRelocate: json['willingToRelocate'] as String?,
      niqabPreference: json['niqabPreference'] as String?,
      mahrExpectation: json['mahrExpectation'] as String?,
      willingToWorkAfterMarriage: json['willingToWorkAfterMarriage'] as bool?,
      mahrBudget: json['mahrBudget'] as String?,
      canProvideHousing: json['canProvideHousing'] as bool?,
      canProvideMaintenance: json['canProvideMaintenance'] as bool?,
      debtStatus: json['debtStatus'] as String?,
      religiousLeadership: json['religiousLeadership'] as String?,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      guardianName: json['guardianName'] as String?,
      guardianRelationship: json['guardianRelationship'] as String?,
      isGuardianMode: (json['isGuardianMode'] as bool?) ?? false,
      guardianPhone: json['guardianPhone'] as String?,
      guardianPhoneCountryCode: json['guardianPhoneCountryCode'] as String?,
      profileCreatorRelation: json['profileCreatorRelation'] as String?,
      guardianEmail: json['guardianEmail'] as String?,
      guardianAuthorityScope: json['guardianAuthorityScope'] as String?,
      guardianMode: json['guardianMode'] as String?,
      isRevert: json['isRevert'] as String?,
      polygamyStatus: json['polygamyStatus'] as String?,
      polygamyAcceptance: json['polygamyAcceptance'] as String?,
      specialNeeds: json['specialNeeds'] as String?,
      residencyStatus: json['residencyStatus'] as String?,
      postalCode: json['postalCode'] as String?,
      lat: json['lat'] as double?,
      lng: json['lng'] as double?,
    );
  }
}
