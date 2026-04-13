// lib/core/cubits/onboarding/onboarding_cubit.dart
// ============================================================
// NOOR — Onboarding Cubit
// Manages the 14-step onboarding flow.
// Each step: locally validates → emits OnboardingLoading →
//            mock-saves → emits OnboardingSaved.
// The router listens and pushes the next screen.
// ============================================================

import 'package:flutter_bloc/flutter_bloc.dart';
import '../../models/onboarding_data.dart';
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
  /// In production: writes to Supabase profiles table before emitting saved.
  Future<void> saveAndAdvance(OnboardingData updatedData) async {
    final currentStep = _currentStep;
    emit(OnboardingLoading(step: currentStep, data: updatedData));

    // Mock: simulate Supabase write latency
    await Future.delayed(const Duration(milliseconds: 600));

    final nextStep = currentStep + 1;

    // Sync the step into AuthCubit so the router can redirect correctly
    _authCubit.updateOnboardingStep(nextStep);

    if (nextStep >= 14) {
      emit(const OnboardingComplete());
    } else {
      emit(OnboardingSaved(step: nextStep, data: updatedData));
    }
  }

  /// Moves back one step (local-only, no Supabase write needed).
  void goBack() {
    final current = state;
    if (current is OnboardingActive && current.step > 0) {
      emit(OnboardingActive(
        step: current.step - 1,
        data: current.data,
      ));
    } else if (current is OnboardingSaved && current.step > 1) {
      emit(OnboardingActive(
        step: current.step - 1,
        data: current.data,
      ));
    }
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
