// lib/core/mock/mock_profiles.dart
// ============================================================
// MITHAQ — Mock Profile Data
// Used by the Discovery Feed for demo-without-backend.
// Each entry maps to the MithaqProfileCard constructor params.
// ============================================================

class MockProfile {
  const MockProfile({
    String? id,
    required this.firstName,
    required this.lastNameInitial,
    required this.age,
    required this.cityName,
    this.sect,
    this.deenLevel,
    this.photoUrl,
    this.photoCount = 0,
    this.isPhotoPrivate = false,
    this.isVerified = false,
    this.occupation,
    this.education,
    this.bio,
    this.languages,
    this.maritalStatus,
    this.familyType,
    this.interests,
    // Partner preferences
    this.partnerAgeMin,
    this.partnerAgeMax,
    this.partnerSect,
    this.partnerDeenLevel,
    this.partnerEducationMinRank,
    // Existing fields
    this.heightCm,
    this.complexion,
    this.motherTongue,
    this.smokingHabit,
    this.vapingHabit,
    this.hookahHabit,
    this.isGuardianProfile = false,
    // Phase 2 fields
    this.community,
    this.dietType,
    this.livingExpectation,
    // Phase 7 fields — Islamic marriage details
    this.quranMemorization,
    this.religiousEducation,
    this.marriageTimeline,
    this.willingToRelocate,
    // Phase 9 audit fields — filter support
    this.gender,
    this.hasChildren = false,
    // D3: Last active timestamp for recency display
    this.lastActiveAt,
    this.countryCode,
    this.lastName,
    this.incomeBracket,
    this.familyOriginCity,
    this.blurhash,
  }) : _id = id;

  final String? _id;
  final String firstName;
  final String lastNameInitial;
  final int age;
  final String cityName;
  final String? sect;
  final String? deenLevel;
  final String? photoUrl;
  final int photoCount;
  final bool isPhotoPrivate;
  final bool isVerified;
  final String? occupation;
  final String? education;
  final String? bio;
  final List<String>? languages;
  final String? maritalStatus;
  final String? familyType;
  final List<String>? interests;
  final int? partnerAgeMin;
  final int? partnerAgeMax;
  final String? partnerSect;
  final String? partnerDeenLevel;
  final int? partnerEducationMinRank;
  final int? heightCm;
  final String? complexion;
  final String? motherTongue;
  final String? smokingHabit;
  final String? vapingHabit;
  final String? hookahHabit;
  final bool isGuardianProfile;
  // Phase 2 fields
  final String? community;
  final String? dietType;
  final String? livingExpectation;
  final String? quranMemorization; // 'none','some_surahs','partial','hafiz'
  final String?
      religiousEducation; // 'self_taught','madrasa','islamic_uni','alim_course','none'
  final String?
      marriageTimeline; // 'asap','6_months','1_year','2_plus_years','not_sure'
  final String? willingToRelocate; // 'yes','no','open_to_discussion'
  // Phase 9 audit fields
  final String? gender; // 'male','female'
  final bool hasChildren;
  // D3: Last active timestamp
  final DateTime? lastActiveAt;
  final String? countryCode;
  final String? lastName;
  final String? incomeBracket;
  final String? familyOriginCity;
  final String? blurhash;

  /// Stable mock ID — derived from name. Replaced by real UUID in Step 12.
  String get id =>
      _id ?? '${firstName.toLowerCase()}_${lastNameInitial.toLowerCase()}';

  MockProfile copyWith({
    String? id,
    String? firstName,
    String? lastNameInitial,
    int? age,
    String? cityName,
    String? sect,
    String? deenLevel,
    String? photoUrl,
    int? photoCount,
    bool? isPhotoPrivate,
    bool? isVerified,
    String? occupation,
    String? education,
    String? bio,
    List<String>? languages,
    String? maritalStatus,
    String? familyType,
    List<String>? interests,
    int? partnerAgeMin,
    int? partnerAgeMax,
    String? partnerSect,
    String? partnerDeenLevel,
    int? partnerEducationMinRank,
    int? heightCm,
    String? complexion,
    String? motherTongue,
    String? smokingHabit,
    String? vapingHabit,
    String? hookahHabit,
    bool? isGuardianProfile,
    String? community,
    String? dietType,
    String? livingExpectation,
    String? quranMemorization,
    String? religiousEducation,
    String? marriageTimeline,
    String? willingToRelocate,
    String? gender,
    bool? hasChildren,
    DateTime? lastActiveAt,
    String? countryCode,
    String? lastName,
    String? incomeBracket,
    String? familyOriginCity,
    String? blurhash,
    bool clearPhotoUrl = false,
  }) {
    return MockProfile(
      id: id ?? _id,
      firstName: firstName ?? this.firstName,
      lastNameInitial: lastNameInitial ?? this.lastNameInitial,
      age: age ?? this.age,
      cityName: cityName ?? this.cityName,
      sect: sect ?? this.sect,
      deenLevel: deenLevel ?? this.deenLevel,
      photoUrl: clearPhotoUrl ? null : (photoUrl ?? this.photoUrl),
      photoCount: photoCount ?? this.photoCount,
      isPhotoPrivate: isPhotoPrivate ?? this.isPhotoPrivate,
      isVerified: isVerified ?? this.isVerified,
      occupation: occupation ?? this.occupation,
      education: education ?? this.education,
      bio: bio ?? this.bio,
      languages: languages ?? this.languages,
      maritalStatus: maritalStatus ?? this.maritalStatus,
      familyType: familyType ?? this.familyType,
      interests: interests ?? this.interests,
      partnerAgeMin: partnerAgeMin ?? this.partnerAgeMin,
      partnerAgeMax: partnerAgeMax ?? this.partnerAgeMax,
      partnerSect: partnerSect ?? this.partnerSect,
      partnerDeenLevel: partnerDeenLevel ?? this.partnerDeenLevel,
      partnerEducationMinRank:
          partnerEducationMinRank ?? this.partnerEducationMinRank,
      heightCm: heightCm ?? this.heightCm,
      complexion: complexion ?? this.complexion,
      motherTongue: motherTongue ?? this.motherTongue,
      smokingHabit: smokingHabit ?? this.smokingHabit,
      vapingHabit: vapingHabit ?? this.vapingHabit,
      hookahHabit: hookahHabit ?? this.hookahHabit,
      isGuardianProfile: isGuardianProfile ?? this.isGuardianProfile,
      community: community ?? this.community,
      dietType: dietType ?? this.dietType,
      livingExpectation: livingExpectation ?? this.livingExpectation,
      quranMemorization: quranMemorization ?? this.quranMemorization,
      religiousEducation: religiousEducation ?? this.religiousEducation,
      marriageTimeline: marriageTimeline ?? this.marriageTimeline,
      willingToRelocate: willingToRelocate ?? this.willingToRelocate,
      gender: gender ?? this.gender,
      hasChildren: hasChildren ?? this.hasChildren,
      lastActiveAt: lastActiveAt ?? this.lastActiveAt,
      countryCode: countryCode ?? this.countryCode,
      lastName: lastName ?? this.lastName,
      incomeBracket: incomeBracket ?? this.incomeBracket,
      familyOriginCity: familyOriginCity ?? this.familyOriginCity,
      blurhash: blurhash ?? this.blurhash,
    );
  }

  /// Human-readable last-active label
  String get lastActiveLabel {
    final t = lastActiveAt;
    if (t == null) return '';
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 5) return 'Online now';
    if (diff.inMinutes < 60) return 'Active ${diff.inMinutes}m ago';
    if (diff.inHours < 24) return 'Active ${diff.inHours}h ago';
    if (diff.inDays < 7) return 'Active ${diff.inDays}d ago';
    return 'Active ${diff.inDays ~/ 7}w ago';
  }
}

/// Static list of 8 mock profiles for the Discovery Feed demo.
const List<MockProfile> kMockProfiles = [
  MockProfile(
    firstName: 'Fatima',
    lastNameInitial: 'A',
    age: 27,
    cityName: 'Dubai',
    sect: 'Sunni',
    deenLevel: 'practicing',
    isVerified: true,
    isPhotoPrivate: false,
    photoCount: 4,
    occupation: 'Product Designer',
    education: 'Bachelor\'s Degree',
    bio:
        'Seeking a partner who values quiet evenings, meaningful conversation, and the beauty of gratitude. I believe in building something lasting.',
    languages: ['English', 'Arabic', 'Urdu'],
    maritalStatus: 'Never Married',
    familyType: 'Nuclear',
    interests: ['Reading', 'Travel', 'Calligraphy', 'Cooking'],
    partnerAgeMin: 28,
    partnerAgeMax: 35,
    heightCm: 163,
    complexion: 'Medium',
    motherTongue: 'Arabic',
    smokingHabit: 'Never',
    community: 'Syed',
    dietType: 'zabiha_strict',
    livingExpectation: 'open_to_discussion',
    quranMemorization: 'partial',
    religiousEducation: 'islamic_uni',
    marriageTimeline: '6_months',
    willingToRelocate: 'open_to_discussion',
    gender: 'female',
    countryCode: 'AE',
    lastName: 'Al-Sayegh',
    incomeBracket: '₹12–25 Lakh/year',
    familyOriginCity: 'Hyderabad',
    blurhash: 'L6PZ|C5800_w.W_x9F_R.g9f%M%M',
  ),
  MockProfile(
    firstName: 'Zainab',
    lastNameInitial: 'H',
    age: 24,
    cityName: 'London',
    sect: 'Sunni',
    deenLevel: 'moderate',
    isVerified: true,
    isPhotoPrivate: true,
    photoCount: 3,
    occupation: 'Medical Student',
    education: 'Master\'s Degree',
    bio:
        'Medicine by day, good coffee and long walks by evening. Looking for someone patient, kind, and not afraid of a little ambition.',
    languages: ['English', 'Arabic'],
    maritalStatus: 'Never Married',
    familyType: 'Joint',
    interests: ['Medicine', 'Photography', 'Travel', 'Poetry'],
    partnerAgeMin: 26,
    partnerAgeMax: 33,
    heightCm: 158,
    complexion: 'Fair',
    motherTongue: 'Urdu',
    smokingHabit: 'Never',
    community: 'Qureshi',
    dietType: 'halal_only',
    livingExpectation: 'separate',
    quranMemorization: 'some_surahs',
    religiousEducation: 'self_taught',
    marriageTimeline: '1_year',
    willingToRelocate: 'no',
    gender: 'female',
    countryCode: 'GB',
    lastName: 'Hashmi',
    incomeBracket: '£35–60k/year',
    familyOriginCity: 'Karachi',
    blurhash: 'LEHV6nWB2yk8pyo0adR*.7kCMdnj',
  ),
  MockProfile(
    firstName: 'Mariam',
    lastNameInitial: 'K',
    age: 29,
    cityName: 'Toronto',
    sect: 'Sunni',
    deenLevel: 'practicing',
    isVerified: false,
    isPhotoPrivate: false,
    photoCount: 2,
    occupation: 'Engineer',
    education: 'Bachelor\'s Degree',
    bio:
        'Faith first, family always. I love hiking, cooking traditional recipes, and Friday evening gatherings. Ready for the next chapter inshAllah.',
    languages: ['English', 'French', 'Arabic'],
    maritalStatus: 'Never Married',
    familyType: 'Nuclear',
    interests: ['Hiking', 'Cooking', 'Technology', 'Reading'],
    partnerAgeMin: 30,
    partnerAgeMax: 37,
    heightCm: 165,
    complexion: 'Olive',
    motherTongue: 'English',
    smokingHabit: 'Never',
    community: 'South Asian',
    dietType: 'halal_only',
    livingExpectation: 'open_to_discussion',
    quranMemorization: 'some_surahs',
    religiousEducation: 'self_taught',
    marriageTimeline: 'asap',
    willingToRelocate: 'yes',
    gender: 'female',
    countryCode: 'CA',
    lastName: 'Khan',
    incomeBracket: 'CAD 65–110k/year',
    familyOriginCity: 'Lahore',
    blurhash: 'LGF5?1Yk^6#M%-5eia^w#M%-5eia',
  ),
  MockProfile(
    firstName: 'Nadia',
    lastNameInitial: 'R',
    age: 26,
    cityName: 'Kuala Lumpur',
    sect: 'Sunni',
    deenLevel: 'moderate',
    isVerified: true,
    isPhotoPrivate: false,
    photoCount: 5,
    occupation: 'Architect',
    education: 'Master\'s Degree',
    bio:
        'Architecture taught me to see beauty in structure and patience in process. Looking for someone who brings both warmth and depth.',
    languages: ['Malay', 'English', 'Mandarin'],
    maritalStatus: 'Never Married',
    familyType: 'Extended',
    interests: ['Architecture', 'Art', 'Cooking', 'Languages'],
    partnerAgeMin: 27,
    partnerAgeMax: 34,
    heightCm: 160,
    complexion: 'Medium',
    motherTongue: 'Malay',
    smokingHabit: 'Never',
    community: 'Malay',
    dietType: 'halal_only',
    livingExpectation: 'with_inlaws',
    quranMemorization: 'none',
    religiousEducation: 'madrasa',
    marriageTimeline: '1_year',
    willingToRelocate: 'open_to_discussion',
    gender: 'female',
    countryCode: 'MY',
    lastName: 'Razak',
    incomeBracket: 'MYR 60–120k/year',
    familyOriginCity: 'Penang',
    blurhash: 'LKN]~^%2_N_3_N%M_N_3_N%M_N_3',
  ),
  MockProfile(
    firstName: 'Sara',
    lastNameInitial: 'M',
    age: 31,
    cityName: 'Istanbul',
    sect: 'Sunni',
    deenLevel: 'practicing',
    isVerified: true,
    isPhotoPrivate: true,
    photoCount: 3,
    occupation: 'Educator',
    education: 'Master\'s Degree',
    bio:
        'Teaching is my calling. I believe every encounter is a lesson — in patience, in grace, in how to love well. Ready to build a calm, loving home.',
    languages: ['Turkish', 'English', 'Arabic'],
    maritalStatus: 'Never Married',
    familyType: 'Nuclear',
    interests: ['Education', 'Reading', 'Calligraphy', 'Travel'],
    partnerAgeMin: 30,
    partnerAgeMax: 38,
    heightCm: 167,
    complexion: 'Fair',
    motherTongue: 'Turkish',
    smokingHabit: 'Never',
    community: 'Turkish',
    dietType: 'zabiha_strict',
    livingExpectation: 'separate',
    quranMemorization: 'hafiz',
    religiousEducation: 'alim_course',
    marriageTimeline: '6_months',
    willingToRelocate: 'no',
    gender: 'female',
    countryCode: 'TR',
    lastName: 'Mustafa',
    incomeBracket: '₺600k–1.2M/year',
    familyOriginCity: 'Ankara',
    blurhash: 'LPD87F5?_N_3_N%M_N_3_N%M_N_3',
  ),
  MockProfile(
    firstName: 'Amira',
    lastNameInitial: 'S',
    age: 23,
    cityName: 'Cairo',
    sect: 'Sunni',
    deenLevel: 'practicing',
    isVerified: false,
    isPhotoPrivate: false,
    photoCount: 4,
    occupation: 'Graphic Designer',
    education: 'Bachelor\'s Degree',
    bio:
        'I design things for a living and try to see the world as something worth designing carefully. A creative partner would be a dream.',
    languages: ['Arabic', 'English', 'French'],
    maritalStatus: 'Never Married',
    familyType: 'Joint',
    interests: ['Design', 'Photography', 'Music', 'Travel'],
    partnerAgeMin: 24,
    partnerAgeMax: 30,
    heightCm: 155,
    complexion: 'Medium',
    motherTongue: 'Arabic',
    smokingHabit: 'Never',
    community: 'Egyptian Arab',
    dietType: 'halal_only',
    livingExpectation: 'open_to_discussion',
    quranMemorization: 'some_surahs',
    religiousEducation: 'self_taught',
    marriageTimeline: '2_plus_years',
    willingToRelocate: 'yes',
    gender: 'female',
    countryCode: 'EG',
    lastName: 'Soliman',
    incomeBracket: 'EGP 150–350k/year',
    familyOriginCity: 'Alexandria',
    blurhash: 'LUDG~v%2_N_3_N%M_N_3_N%M_N_3',
  ),
  MockProfile(
    firstName: 'Hana',
    lastNameInitial: 'B',
    age: 28,
    cityName: 'Paris',
    sect: 'Sunni',
    deenLevel: 'moderate',
    isVerified: true,
    isPhotoPrivate: false,
    photoCount: 2,
    occupation: 'Finance Analyst',
    education: 'Master\'s Degree',
    bio:
        'Paris taught me that elegance is a mindset, not a city. I\'m grounded in faith, driven by purpose, and looking for a partner who respects both.',
    languages: ['French', 'Arabic', 'English'],
    maritalStatus: 'Never Married',
    familyType: 'Nuclear',
    interests: ['Finance', 'Cooking', 'Reading', 'Yoga'],
    partnerAgeMin: 29,
    partnerAgeMax: 36,
    heightCm: 170,
    complexion: 'Olive',
    motherTongue: 'Arabic',
    smokingHabit: 'Never',
    community: 'Moroccan',
    dietType: 'zabiha_strict',
    livingExpectation: 'separate',
    quranMemorization: 'partial',
    religiousEducation: 'islamic_uni',
    marriageTimeline: 'asap',
    willingToRelocate: 'open_to_discussion',
    gender: 'female',
    countryCode: 'FR',
    lastName: 'Bennani',
    incomeBracket: '€40–70k/year',
    familyOriginCity: 'Casablanca',
    blurhash: 'LFD87F5?_N_3_N%M_N_3_N%M_N_3',
  ),
  MockProfile(
    firstName: 'Layla',
    lastNameInitial: 'Q',
    age: 25,
    cityName: 'New York',
    sect: 'Sunni',
    deenLevel: 'practicing',
    isVerified: true,
    isPhotoPrivate: true,
    photoCount: 6,
    occupation: 'Lawyer',
    education: 'Law Degree',
    bio:
        'I argue for a living but I\'m learning to listen more. Faith keeps me grounded; ambition keeps me moving. Looking for someone who understands both.',
    languages: ['English', 'Arabic'],
    maritalStatus: 'Never Married',
    familyType: 'Nuclear',
    interests: ['Law', 'Running', 'Travel', 'Cooking'],
    partnerAgeMin: 27,
    partnerAgeMax: 35,
    heightCm: 162,
    complexion: 'Fair',
    motherTongue: 'English',
    smokingHabit: 'Never',
    community: 'Arab',
    dietType: 'halal_only',
    livingExpectation: 'open_to_discussion',
    quranMemorization: 'some_surahs',
    religiousEducation: 'madrasa',
    marriageTimeline: '1_year',
    willingToRelocate: 'yes',
    gender: 'female',
    countryCode: 'US',
    lastName: 'Qabbani',
    incomeBracket: '\$100–200k/year',
    familyOriginCity: 'Beirut',
    blurhash: 'LOD87F5?_N_3_N%M_N_3_N%M_N_3',
  ),
];
