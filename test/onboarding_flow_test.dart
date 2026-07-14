import 'package:flutter_test/flutter_test.dart';
import 'package:silarah/core/onboarding/onboarding_flow.dart';

void main() {
  group('OnboardingFlow legacy migration', () {
    test('keeps an incomplete self profile within the five-step fast path', () {
      expect(
        OnboardingFlow.migrateLegacyStep(
          legacyStep: 4,
          isGuardianPath: false,
          wasComplete: false,
          hasValidLocation: true,
        ),
        4,
      );
    });

    test('sends guardian profiles to the shared quick location step', () {
      expect(
        OnboardingFlow.migrateLegacyStep(
          legacyStep: 1,
          isGuardianPath: true,
          wasComplete: false,
          hasValidLocation: true,
        ),
        1,
      );
    });

    test('forces only profiles without valid location to quick location', () {
      expect(
        OnboardingFlow.migrateLegacyStep(
          legacyStep: 8,
          isGuardianPath: false,
          wasComplete: false,
          hasValidLocation: false,
        ),
        OnboardingFlow.quickLocationStep(false),
      );
    });

    test('retains complete legacy profiles as complete', () {
      expect(
        OnboardingFlow.migrateLegacyStep(
          legacyStep: 11,
          isGuardianPath: false,
          wasComplete: true,
          hasValidLocation: false,
        ),
        OnboardingFlow.selfCompleteAt,
      );
      expect(
        OnboardingFlow.migrateLegacyStep(
          legacyStep: 12,
          isGuardianPath: true,
          wasComplete: true,
          hasValidLocation: false,
        ),
        OnboardingFlow.guardianCompleteAt,
      );
    });

    test('treats old later-step profiles as complete in fast-start v3', () {
      expect(
        OnboardingFlow.migrateLegacyStep(
          legacyStep: 8,
          isGuardianPath: false,
          wasComplete: false,
          hasValidLocation: true,
        ),
        OnboardingFlow.selfCompleteAt,
      );
    });
  });
}
