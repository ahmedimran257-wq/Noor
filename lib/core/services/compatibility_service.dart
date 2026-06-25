import '../mock/mock_profiles.dart';
import '../models/onboarding_data.dart';

class CompatibilityResult {
  const CompatibilityResult({required this.matched, required this.total});

  final int matched;
  final int total;

  double get fraction => total == 0 ? 0 : matched / total;
}

/// Compares the viewer's real profile fields with the candidate's stated
/// partner preferences. Candidate traits are never treated as preferences.
CompatibilityResult calculateCompatibility({
  required OnboardingData viewer,
  required MockProfile candidate,
  DateTime? today,
}) {
  final checks = <bool>[];

  if (candidate.partnerAgeMin != null && candidate.partnerAgeMax != null) {
    final dob = viewer.dateOfBirth;
    checks.add(dob != null &&
        _ageOn(dob, today ?? DateTime.now()) >= candidate.partnerAgeMin! &&
        _ageOn(dob, today ?? DateTime.now()) <= candidate.partnerAgeMax!);
  }

  final sectPreference = _normalize(candidate.partnerSect);
  if (!_isUnrestricted(sectPreference)) {
    final viewerSect = _normalize(viewer.sect?.name);
    final expectedSect = sectPreference == 'sameasmine'
        ? _normalize(candidate.sect)
        : sectPreference;
    checks.add(viewerSect.isNotEmpty && viewerSect == expectedSect);
  }

  final deenPreference = _normalize(candidate.partnerDeenLevel);
  if (!_isUnrestricted(deenPreference)) {
    final viewerDeen = _normalizeDeen(viewer.deenLevel?.name);
    final expectedDeen = deenPreference == 'sameasmine'
        ? _normalizeDeen(candidate.deenLevel)
        : _normalizeDeen(deenPreference);
    checks.add(viewerDeen.isNotEmpty && viewerDeen == expectedDeen);
  }

  final minimumEducation = candidate.partnerEducationMinRank;
  if (minimumEducation != null && minimumEducation > 1) {
    checks.add(viewer.educationRank != null &&
        viewer.educationRank! >= minimumEducation);
  }

  return CompatibilityResult(
    matched: checks.where((check) => check).length,
    total: checks.length,
  );
}

int _ageOn(DateTime dateOfBirth, DateTime today) {
  var age = today.year - dateOfBirth.year;
  final birthdayPassed = today.month > dateOfBirth.month ||
      (today.month == dateOfBirth.month && today.day >= dateOfBirth.day);
  if (!birthdayPassed) age--;
  return age;
}

String _normalize(String? value) =>
    (value ?? '').toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

String _normalizeDeen(String? value) {
  final normalized = _normalize(value);
  return normalized == 'culturalmuslim' ? 'cultural' : normalized;
}

bool _isUnrestricted(String value) =>
    value.isEmpty || value == 'any' || value == 'nopreference';
