// lib/features/onboarding/widgets/onboarding_scaffold.dart
// ============================================================
// NOOR — Onboarding Scaffold
// Shared shell used by form steps 0–9.
// Provides: SafeArea, progress bar, back button, scrollable body,
//           and a pinned bottom CTA + skip area.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/cubits/onboarding/onboarding_cubit.dart';
import '../../../core/models/onboarding_data.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/buttons/noor_primary_button.dart';
import 'onboarding_progress_bar.dart';

class OnboardingScaffold extends StatelessWidget {
  const OnboardingScaffold({
    super.key,
    this.step,
    required this.body,
    required this.ctaLabel,
    required this.onCta,
    this.isCtaEnabled = true,
    this.isCtaLoading = false,
    this.skipLabel,
    this.onSkip,
    this.totalSteps,
    this.onBack,
    this.onCtaDisabledTap,
  });

  /// 0-indexed position in the form steps (used for progress bar).
  /// If null, reads from [OnboardingCubit.currentStep].
  final int? step;
  final Widget body;
  final String ctaLabel;
  final VoidCallback? onCta;
  final bool isCtaEnabled;
  final bool isCtaLoading;
  final String? skipLabel;
  final VoidCallback? onSkip;
  /// Total steps for progress bar. If null, computed from guardian/myself path:
  ///   Guardian → 12 steps (0–11), Myself → 11 steps (0–10).
  final int? totalSteps;
  final VoidCallback? onBack;
  /// Called when CTA is tapped while disabled — use to show validation feedback.
  final VoidCallback? onCtaDisabledTap;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<OnboardingCubit>();
    final resolvedStep = step ?? cubit.currentStep;
    final isGuardian = cubit.currentData.profileFor == ProfileFor.guardian;
    final resolvedTotal = totalSteps ?? (isGuardian ? 12 : 11);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.5),  // slightly above center
            radius: 1.2,
            colors: [
              Color(0xFF151522),  // Deep premium navy-charcoal core
              AppColors.obsidianNight,  // Deep midnight edges
            ],
          ),
        ),
        child: SafeArea(
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
                    _BackButton(onBack: onBack ?? () => context.read<OnboardingCubit>().goBack()),
                    const SizedBox(width: AppDimensions.space16),
                    // Progress bar fills remaining width
                    Expanded(
                      child: OnboardingProgressBar(
                        currentStep: resolvedStep,
                        totalSteps:  resolvedTotal,
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
                    // When disabled, IgnorePointer stops the button from
                    // absorbing the tap (NoorPressable uses opaque hit-testing).
                    // The overlay GestureDetector then catches it for validation.
                    if (!isCtaEnabled && onCtaDisabledTap != null)
                      GestureDetector(
                        onTap: onCtaDisabledTap,
                        behavior: HitTestBehavior.opaque,
                        child: IgnorePointer(
                          child: NoorPrimaryButton(
                            label:     ctaLabel,
                            onTap:     null,
                            isLoading: isCtaLoading,
                          ),
                        ),
                      )
                    else
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
