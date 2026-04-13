// lib/core/cubits/onboarding/onboarding_state.dart
// ============================================================
// NOOR — Onboarding Cubit States
// ============================================================

import 'package:equatable/equatable.dart';
import '../../models/onboarding_data.dart';

abstract class OnboardingState extends Equatable {
  const OnboardingState();

  @override
  List<Object?> get props => [];
}

/// Initial state before the cubit is loaded.
class OnboardingInitial extends OnboardingState {
  const OnboardingInitial();
}

/// An async save is in progress (e.g. uploading to Supabase).
class OnboardingLoading extends OnboardingState {
  const OnboardingLoading({required this.step, required this.data});

  final int step;
  final OnboardingData data;

  @override
  List<Object?> get props => [step, data];
}

/// Active onboarding step with accumulated data.
class OnboardingActive extends OnboardingState {
  const OnboardingActive({
    required this.step,
    required this.data,
  });

  final int step;
  final OnboardingData data;

  @override
  List<Object?> get props => [step, data];
}

/// Step was saved successfully — router may now advance the screen.
class OnboardingSaved extends OnboardingState {
  const OnboardingSaved({required this.step, required this.data});

  final int step;
  final OnboardingData data;

  @override
  List<Object?> get props => [step, data];
}

/// Onboarding is fully complete (step == 14).
class OnboardingComplete extends OnboardingState {
  const OnboardingComplete();
}

/// A non-fatal validation error to display inline (e.g. under-18).
class OnboardingError extends OnboardingState {
  const OnboardingError({
    required this.step,
    required this.data,
    required this.message,
  });

  final int step;
  final OnboardingData data;
  final String message;

  @override
  List<Object?> get props => [step, data, message];
}
