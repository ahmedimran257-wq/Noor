// lib/features/onboarding/widgets/onboarding_progress_bar.dart
// ============================================================
// NOOR — Onboarding Progress Bar
// Thin 12-segment bar shown on steps 0–9 (the form steps).
// Filled segments animate in Champagne Gold.
// ============================================================

import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';

class OnboardingProgressBar extends StatelessWidget {
  const OnboardingProgressBar({
    super.key,
    required this.currentStep,
    this.totalSteps = 10,
  });

  /// 0-indexed step within the onboarding form (steps 0–9).
  final int currentStep;
  final int totalSteps;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(totalSteps, (index) {
        final isFilled = index <= currentStep;
        return Expanded(
          child: AnimatedContainer(
            duration: AppDimensions.durationTransition,
            curve: Curves.easeOutCubic,
            height: 3,
            margin: EdgeInsetsDirectional.only(
              end: index < totalSteps - 1 ? 4 : 0,
            ),
            decoration: BoxDecoration(
              color: isFilled
                  ? AppColors.champagneGold
                  : AppColors.progressBarBase,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      }),
    );
  }
}
