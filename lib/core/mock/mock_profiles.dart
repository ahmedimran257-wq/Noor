// lib/core/mock/mock_profiles.dart
// ============================================================
// NOOR — Mock Profile Data
// Used by the Discovery Feed for demo-without-backend.
// Each entry maps to the NoorProfileCard constructor params.
// ============================================================

class MockProfile {
  const MockProfile({
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
  });

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
    bio: 'Seeking a partner who values quiet evenings, meaningful conversation, and the beauty of gratitude. I believe in building something lasting.',
    languages: ['English', 'Arabic', 'Urdu'],
    maritalStatus: 'Never Married',
    familyType: 'Nuclear',
    interests: ['Reading', 'Travel', 'Calligraphy', 'Cooking'],
    partnerAgeMin: 28,
    partnerAgeMax: 35,
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
    bio: 'Medicine by day, good coffee and long walks by evening. Looking for someone patient, kind, and not afraid of a little ambition.',
    languages: ['English', 'Arabic'],
    maritalStatus: 'Never Married',
    familyType: 'Joint',
    interests: ['Medicine', 'Photography', 'Travel', 'Poetry'],
    partnerAgeMin: 26,
    partnerAgeMax: 33,
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
    bio: 'Faith first, family always. I love hiking, cooking traditional recipes, and Friday evening gatherings. Ready for the next chapter inshAllah.',
    languages: ['English', 'French', 'Arabic'],
    maritalStatus: 'Never Married',
    familyType: 'Nuclear',
    interests: ['Hiking', 'Cooking', 'Technology', 'Reading'],
    partnerAgeMin: 30,
    partnerAgeMax: 37,
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
    bio: 'Architecture taught me to see beauty in structure and patience in process. Looking for someone who brings both warmth and depth.',
    languages: ['Malay', 'English', 'Mandarin'],
    maritalStatus: 'Never Married',
    familyType: 'Extended',
    interests: ['Architecture', 'Art', 'Cooking', 'Languages'],
    partnerAgeMin: 27,
    partnerAgeMax: 34,
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
    bio: 'Teaching is my calling. I believe every encounter is a lesson — in patience, in grace, in how to love well. Ready to build a calm, loving home.',
    languages: ['Turkish', 'English', 'Arabic'],
    maritalStatus: 'Never Married',
    familyType: 'Nuclear',
    interests: ['Education', 'Reading', 'Calligraphy', 'Travel'],
    partnerAgeMin: 30,
    partnerAgeMax: 38,
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
    bio: 'I design things for a living and try to see the world as something worth designing carefully. A creative partner would be a dream.',
    languages: ['Arabic', 'English', 'French'],
    maritalStatus: 'Never Married',
    familyType: 'Joint',
    interests: ['Design', 'Photography', 'Music', 'Travel'],
    partnerAgeMin: 24,
    partnerAgeMax: 30,
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
    bio: 'Paris taught me that elegance is a mindset, not a city. I\'m grounded in faith, driven by purpose, and looking for a partner who respects both.',
    languages: ['French', 'Arabic', 'English'],
    maritalStatus: 'Never Married',
    familyType: 'Nuclear',
    interests: ['Finance', 'Cooking', 'Reading', 'Yoga'],
    partnerAgeMin: 29,
    partnerAgeMax: 36,
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
    bio: 'I argue for a living but I\'m learning to listen more. Faith keeps me grounded; ambition keeps me moving. Looking for someone who understands both.',
    languages: ['English', 'Arabic'],
    maritalStatus: 'Never Married',
    familyType: 'Nuclear',
    interests: ['Law', 'Running', 'Travel', 'Cooking'],
    partnerAgeMin: 27,
    partnerAgeMax: 35,
  ),
];
