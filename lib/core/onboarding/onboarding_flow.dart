import '../models/onboarding_data.dart';

/// The versioned onboarding layout. Keep step numbers in one place so the
/// router, persistence layer, and legacy migration cannot drift apart.
abstract final class OnboardingFlow {
  static const int version = 3;

  /// Fast-start onboarding asks only for the essentials needed to enter feed:
  /// profile owner, location, identity, Islamic basics, and first photo/privacy.
  /// Deeper compatibility fields are completed later from Edit Profile.
  static const int selfCompleteAt = 5;
  static const int guardianCompleteAt = 5;

  static int completeAt(bool isGuardianPath) =>
      isGuardianPath ? guardianCompleteAt : selfCompleteAt;

  static int quickLocationStep(bool isGuardianPath) => 1;

  static bool hasValidLocation(OnboardingData data) =>
      data.countryCode?.trim().isNotEmpty == true &&
      data.cityName?.trim().isNotEmpty == true &&
      data.lat != null &&
      data.lng != null;

  /// Mirrors the database migration for rows created by the legacy flow.
  static int migrateLegacyStep({
    required int legacyStep,
    required bool isGuardianPath,
    required bool wasComplete,
    required bool hasValidLocation,
  }) {
    if (wasComplete) return completeAt(isGuardianPath);
    if (!hasValidLocation) return quickLocationStep(isGuardianPath);
    return legacyStep >= completeAt(isGuardianPath)
        ? completeAt(isGuardianPath)
        : legacyStep.clamp(0, completeAt(isGuardianPath) - 1);
  }
}
