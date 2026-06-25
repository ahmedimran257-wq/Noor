// lib/core/cubits/onboarding/onboarding_cubit.dart
// ============================================================
// MITHAQ — Onboarding Cubit
// Manages the multi-step onboarding flow.
// Each step: locally validates → emits OnboardingLoading →
//            mock-saves → emits OnboardingSaved.
// The router listens and pushes the next screen.
//
// Completion thresholds:
//   Myself   → completeAt 11
//   Guardian → completeAt 12
// ============================================================

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/onboarding_data.dart';
import '../../onboarding/onboarding_flow.dart';
import '../../services/profile_write_service.dart';
import '../auth/auth_cubit.dart';
import '../auth/auth_state.dart';
import 'onboarding_state.dart';

class OnboardingCubit extends Cubit<OnboardingState> {
  OnboardingCubit({required AuthCubit authCubit})
      : _authCubit = authCubit,
        super(const OnboardingInitial());

  final AuthCubit _authCubit;

  static const String _kCacheKey = 'onboarding_data_cache';

  // ── Initialization ────────────────────────────────────────

  /// Called after auth succeeds. Loads the saved step from backend.
  /// Also restores saved data from Supabase/SharedPreferences to preserve state.
  Future<void> initialize({int startStep = 0}) async {
    OnboardingData data = const OnboardingData();

    // 1. Attempt to load from Supabase if real mode is enabled
    final dbData = await ProfileWriteService.loadProfile();
    if (dbData != null) {
      data = dbData;
      debugPrint('OnboardingCubit: Successfully restored data from Supabase.');
    } else {
      // 2. Fallback to SharedPreferences cache if DB is empty/unconfigured
      try {
        final prefs = await SharedPreferences.getInstance();
        final rawJson = prefs.getString(_kCacheKey);
        if (rawJson != null && rawJson.isNotEmpty) {
          final mapped = jsonDecode(rawJson) as Map<String, dynamic>;
          data = OnboardingData.fromJson(mapped);
          debugPrint(
              'OnboardingCubit: Successfully restored data from SharedPreferences cache.');
        }
      } catch (e) {
        debugPrint('OnboardingCubit: Error loading from SharedPreferences: $e');
      }
    }

    final authState = _authCubit.state;
    if (data.email == null && authState is AuthAuthenticated) {
      final email = authState.email;
      if (email != null && email.isNotEmpty) {
        data = data.copyWith(email: email);
      }
    }

    // Prefill countryCode from SharedPreferences if null
    if (data.countryCode == null) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final code = prefs.getString('user_country_code');
        if (code != null && code.isNotEmpty) {
          data = data.copyWith(countryCode: code.toUpperCase());
          debugPrint(
              'OnboardingCubit: Prefilled countryCode from user_country_code: $code');
        }
      } catch (_) {}
    }

    emit(OnboardingActive(step: startStep, data: data));
  }

  // ── Step Advance ──────────────────────────────────────────

  /// Saves the partial data for the current step and advances to next.
  /// In production: writes to Supabase profiles table via ProfileWriteService.
  /// In mock mode: simulates a delay.
  Future<void> saveAndAdvance(OnboardingData updatedData) async {
    final currentStep = _currentStep;
    emit(OnboardingLoading(step: currentStep, data: updatedData));

    // Persist to SharedPreferences cache immediately (offline fallback)
    await _persistLocalCache(updatedData);

    // Persist to Supabase (or mock delay if not configured)
    final isGuardianPath = updatedData.profileFor == ProfileFor.guardian;
    final success = await ProfileWriteService.saveStep(
      step: currentStep,
      data: updatedData,
      isGuardianPath: isGuardianPath,
    );

    if (!success) {
      debugPrint(
          'OnboardingCubit: Failed to save step $currentStep, proceeding anyway');
    }

    final nextStep = currentStep + 1;

    // Also update the onboarding_step in the DB
    await ProfileWriteService.updateOnboardingStep(nextStep);

    // Completion thresholds:
    //   Myself   → 11 steps (0–10)
    //   Guardian → 12 steps (0–11)
    final completeAt = OnboardingFlow.completeAt(isGuardianPath);

    if (nextStep >= completeAt) {
      await ProfileWriteService.markOnboardingComplete();
      _authCubit.updateOnboardingStep(
        nextStep,
        isGuardianPath: isGuardianPath,
        onboardingCompleted: true,
      );
      emit(const OnboardingComplete());
    } else {
      _authCubit.updateOnboardingStep(nextStep, isGuardianPath: isGuardianPath);
      emit(OnboardingSaved(step: nextStep, data: updatedData));
    }
  }

  /// Moves back one step (local-only, but writes to DB to preserve step).
  void goBack() async {
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
      final isGuardianPath = data.profileFor == ProfileFor.guardian;
      // Update AuthCubit so the router redirect navigates to the previous screen
      _authCubit.updateOnboardingStep(newStep, isGuardianPath: isGuardianPath);

      // Fixed Flaw 24: Persist the decremented step back to the DB
      await ProfileWriteService.updateOnboardingStep(newStep);

      emit(OnboardingActive(step: newStep, data: data));
    }
  }

  /// Updates the profile data in-place without advancing the step.
  /// Use this from EditProfileScreen so saving doesn't bump the onboarding flow.
  void updateProfile(OnboardingData data) async {
    emit(OnboardingActive(step: _currentStep, data: data));
    await _persistLocalCache(data);
    await ProfileWriteService.saveFullProfile(data);
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
    final isGuardianPath = data.profileFor == ProfileFor.guardian;

    // Fixed Flaw 7: Persist skipped step to the DB
    await ProfileWriteService.updateOnboardingStep(nextStep);

    // Completion thresholds:
    //   Myself   → 11 steps (0–10)
    //   Guardian → 12 steps (0–11)
    final completeAt = OnboardingFlow.completeAt(isGuardianPath);

    if (nextStep >= completeAt) {
      await ProfileWriteService.markOnboardingComplete();
      _authCubit.updateOnboardingStep(
        nextStep,
        isGuardianPath: isGuardianPath,
        onboardingCompleted: true,
      );
      // Fixed Flaw 7: Correctly emit OnboardingComplete() when skipping past threshold
      emit(const OnboardingComplete());
    } else {
      _authCubit.updateOnboardingStep(nextStep, isGuardianPath: isGuardianPath);
      emit(OnboardingSaved(step: nextStep, data: data));
    }
  }

  // ── Cache Persistence Helper ──────────────────────────────

  Future<void> _persistLocalCache(OnboardingData data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kCacheKey, jsonEncode(data.toJson()));
    } catch (e) {
      debugPrint(
          'OnboardingCubit: Failed to write SharedPreferences cache: $e');
    }
  }

  // ── Helpers ───────────────────────────────────────────────

  int get _currentStep {
    final s = state;
    if (s is OnboardingActive) return s.step;
    if (s is OnboardingLoading) return s.step;
    if (s is OnboardingSaved) return s.step;
    if (s is OnboardingError) return s.step;
    return 0;
  }

  OnboardingData get _currentData {
    final s = state;
    if (s is OnboardingActive) return s.data;
    if (s is OnboardingLoading) return s.data;
    if (s is OnboardingSaved) return s.data;
    if (s is OnboardingError) return s.data;
    return const OnboardingData();
  }

  OnboardingData get currentData => _currentData;
  int get currentStep => _currentStep;
}
