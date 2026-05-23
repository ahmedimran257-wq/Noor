// lib/core/cubits/onboarding/onboarding_cubit.dart
// ============================================================
// NOOR — Onboarding Cubit
// Manages the multi-step onboarding flow.
// Each step: locally validates → emits OnboardingLoading →
//            mock-saves → emits OnboardingSaved.
// The router listens and pushes the next screen.
//
// Completion thresholds:
//   Myself   → completeAt 11
//   Guardian → completeAt 12
// ============================================================

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../models/onboarding_data.dart';
import '../../services/profile_write_service.dart';
import '../auth/auth_cubit.dart';
import 'onboarding_state.dart';

class OnboardingCubit extends Cubit<OnboardingState> {
  OnboardingCubit({required AuthCubit authCubit})
      : _authCubit = authCubit,
        super(const OnboardingInitial());

  final AuthCubit _authCubit;

  // ── Initialization ────────────────────────────────────────

  /// Called after auth succeeds. Loads the saved step from backend.
  /// Mock: always starts at step 0.
  Future<void> initialize({int startStep = 0}) async {
    emit(OnboardingActive(step: startStep, data: const OnboardingData()));
  }

  // ── Step Advance ──────────────────────────────────────────

  /// Saves the partial data for the current step and advances to next.
  /// In production: writes to Supabase profiles table via ProfileWriteService.
  /// In mock mode: simulates a delay.
  Future<void> saveAndAdvance(OnboardingData updatedData) async {
    final currentStep = _currentStep;
    emit(OnboardingLoading(step: currentStep, data: updatedData));

    // Persist to Supabase (or mock delay if not configured)
    final isGuardianPath = updatedData.profileFor == ProfileFor.guardian;
    final success = await ProfileWriteService.saveStep(
      step: currentStep,
      data: updatedData,
      isGuardianPath: isGuardianPath,
    );

    if (!success) {
      debugPrint('OnboardingCubit: Failed to save step $currentStep, proceeding anyway');
    }

    final nextStep = currentStep + 1;

    // Sync the step into AuthCubit so the router can redirect correctly
    _authCubit.updateOnboardingStep(nextStep, isGuardianPath: isGuardianPath);

    // Also update the onboarding_step in the DB
    await ProfileWriteService.updateOnboardingStep(nextStep);

    // Completion thresholds:
    //   Myself   → 11 steps (0–10)
    //   Guardian → 12 steps (0–11)
    final completeAt = isGuardianPath ? 12 : 11;

    if (nextStep >= completeAt) {
      emit(const OnboardingComplete());
    } else {
      emit(OnboardingSaved(step: nextStep, data: updatedData));
    }
  }

  /// Moves back one step (local-only, no Supabase write needed).
  void goBack() {
    final current = state;
    int? newStep;
    OnboardingData? data;

    if (current is OnboardingActive && current.step > 0) {
      newStep = current.step - 1;
      data = current.data;
    } else if (current is OnboardingSaved && current.step > 0) {
      newStep = current.step - 1;
      data = current.data;
    } else if (current is OnboardingLoading && current.step > 0) {
      newStep = current.step - 1;
      data = current.data;
    }

    if (newStep != null && data != null) {
      // Update AuthCubit so the router redirect navigates to the previous screen
      _authCubit.updateOnboardingStep(newStep);
      emit(OnboardingActive(step: newStep, data: data));
    }
  }

  /// Updates the profile data in-place without advancing the step.
  /// Use this from EditProfileScreen so saving doesn't bump the onboarding flow.
  void updateProfile(OnboardingData data) {
    emit(OnboardingActive(step: _currentStep, data: data));
  }

  /// Called by screens after router pushes the next page to mark active again.
  void markActive(int step, OnboardingData data) {
    emit(OnboardingActive(step: step, data: data));
  }

  /// Skips a step (optional steps like income).
  Future<void> skipStep() async {
    final currentStep = _currentStep;
    final data = _currentData;
    emit(OnboardingLoading(step: currentStep, data: data));
    await Future.delayed(const Duration(milliseconds: 200));
    final nextStep = currentStep + 1;
    _authCubit.updateOnboardingStep(nextStep);
    emit(OnboardingSaved(step: nextStep, data: data));
  }

  // ── Helpers ───────────────────────────────────────────────

  int get _currentStep {
    final s = state;
    if (s is OnboardingActive)  return s.step;
    if (s is OnboardingLoading) return s.step;
    if (s is OnboardingSaved)   return s.step;
    if (s is OnboardingError)   return s.step;
    return 0;
  }

  OnboardingData get _currentData {
    final s = state;
    if (s is OnboardingActive)  return s.data;
    if (s is OnboardingLoading) return s.data;
    if (s is OnboardingSaved)   return s.data;
    if (s is OnboardingError)   return s.data;
    return const OnboardingData();
  }

  OnboardingData get currentData => _currentData;
  int get currentStep => _currentStep;
}
