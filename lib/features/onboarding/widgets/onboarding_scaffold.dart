// lib/features/onboarding/widgets/onboarding_scaffold.dart
// ============================================================
// NOOR — Onboarding Scaffold
// Shared shell used by form steps 0–9.
// Provides: SafeArea, progress bar, back button, scrollable body,
//           and a pinned bottom CTA + skip area.
// ============================================================

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/buttons/noor_primary_button.dart';
import 'onboarding_progress_bar.dart';

class OnboardingScaffold extends StatelessWidget {
  const OnboardingScaffold({
    super.key,
    required this.step,
    required this.body,
    required this.ctaLabel,
    required this.onCta,
    this.isCtaEnabled = true,
    this.isCtaLoading = false,
    this.skipLabel,
    this.onSkip,
    this.totalSteps = 10,
    this.onBack,
  });

  /// 0-indexed position in the form steps (used for progress bar).
  final int step;
  final Widget body;
  final String ctaLabel;
  final VoidCallback? onCta;
  final bool isCtaEnabled;
  final bool isCtaLoading;
  final String? skipLabel;
  final VoidCallback? onSkip;
  final int totalSteps;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.obsidianNight,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top bar: back + progress ──────────────────
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.space24,
                vertical:   AppDimensions.space16,
              ),
              child: Row(
                children: [
                  // Back button (RTL-aware)
                  _BackButton(onBack: onBack ?? () => context.pop()),
                  const SizedBox(width: AppDimensions.space16),
                  // Progress bar fills remaining width
                  Expanded(
                    child: OnboardingProgressBar(
                      currentStep: step,
                      totalSteps:  totalSteps,
                    ),
                  ),
                ],
              ),
            ),

            // ── Scrollable body ───────────────────────────
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.space24,
                ),
                child: body,
              ),
            ),

            // ── Bottom CTA ────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppDimensions.space24,
                AppDimensions.space16,
                AppDimensions.space24,
                AppDimensions.space32,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  NoorPrimaryButton(
                    label:     ctaLabel,
                    onTap:     isCtaEnabled ? onCta : null,
                    isLoading: isCtaLoading,
                  ),
                  if (skipLabel != null && onSkip != null) ...[
                    const SizedBox(height: AppDimensions.space12),
                    GestureDetector(
                      onTap: onSkip,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppDimensions.space8,
                        ),
                        child: Text(
                          skipLabel!,
                          style: AppTypography.buttonGhost.copyWith(
                            color: AppColors.slateMist,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({this.onBack});
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onBack,
      child: Container(
        width:  40,
        height: 40,
        decoration: BoxDecoration(
          color:  AppColors.surfaceGlass,
          shape:  BoxShape.circle,
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Icon(
          // Mirror for RTL
          Directionality.of(context) == TextDirection.rtl
              ? Icons.arrow_forward_ios_rounded
              : Icons.arrow_back_ios_new_rounded,
          color: AppColors.pearlWhite,
          size:  16,
        ),
      ),
    );
  }
}
