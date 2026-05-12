// lib/features/onboarding/widgets/onboarding_progress_bar.dart
// ============================================================
// NOOR — Onboarding Progress Bar
// Thin segmented bar + "Step X of Y" counter.
// Filled segments animate in Champagne Gold.
// ============================================================

import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';

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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Step counter label
        Text(
          'Step ${(currentStep + 1).clamp(1, totalSteps)} of $totalSteps',
          style: AppTypography.caption.copyWith(
            fontSize: 10,
            color: AppColors.champagneGold,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        // Segmented bar
        Row(
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
        ),
      ],
    );
  }
}
