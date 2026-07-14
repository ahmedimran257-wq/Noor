import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/cubits/onboarding/onboarding_cubit.dart';
import '../../../core/cubits/onboarding/onboarding_state.dart';
import '../../../core/models/onboarding_data.dart';
import '../../../core/onboarding/onboarding_flow.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/buttons/silarah_pressable.dart';
import '../../../core/widgets/buttons/silarah_primary_button.dart';
import '../../../core/widgets/buttons/silarah_secondary_button.dart';
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
    this.showProgressHeader = true,
    this.headerTitle,
  });

  final int? step;
  final Widget body;
  final String ctaLabel;
  final VoidCallback? onCta;
  final bool isCtaEnabled;
  final bool isCtaLoading;
  final String? skipLabel;
  final VoidCallback? onSkip;
  final int? totalSteps;
  final VoidCallback? onBack;
  final VoidCallback? onCtaDisabledTap;
  final bool showProgressHeader;
  final String? headerTitle;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<OnboardingCubit>();
    final state = context.watch<OnboardingCubit>().state;
    final resolvedStep = step ?? cubit.currentStep;
    final isGuardian = cubit.currentData.profileFor == ProfileFor.guardian;
    final resolvedTotal = totalSteps ?? OnboardingFlow.completeAt(isGuardian);
    final saveError =
        state is OnboardingError && state.step == resolvedStep ? state : null;

    return Scaffold(
      backgroundColor: AppColors.obsidianNight,
      body: SafeArea(
        child: Stack(
          children: [
            const Positioned.fill(child: _OnboardingBackdrop()),
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.space24,
                    vertical: AppDimensions.space16,
                  ),
                  child: Row(
                    children: [
                      _BackButton(
                        onBack: onBack ??
                            () => context.read<OnboardingCubit>().goBack(),
                      ),
                      const SizedBox(width: AppDimensions.space16),
                      if (showProgressHeader)
                        Expanded(
                          child: OnboardingProgressBar(
                            currentStep: resolvedStep,
                            totalSteps: resolvedTotal,
                          ),
                        )
                      else
                        Expanded(
                          child: Text(
                            headerTitle ?? '',
                            textAlign: TextAlign.center,
                            style: AppTypography.bodyMedium.copyWith(
                              color: AppColors.pearlWhite,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimensions.space24,
                    ),
                    child: _RevealOnStep(
                      step: resolvedStep,
                      child: body,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppDimensions.space24,
                    AppDimensions.space16,
                    AppDimensions.space24,
                    AppDimensions.space32,
                  ),
                  child: _RevealOnStep(
                    step: resolvedStep,
                    delay: const Duration(milliseconds: 70),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (saveError != null) ...[
                          _SaveErrorNotice(message: saveError.message),
                          const SizedBox(height: AppDimensions.space12),
                        ],
                        if (!isCtaEnabled && onCtaDisabledTap != null)
                          GestureDetector(
                            onTap: () {
                              FocusManager.instance.primaryFocus?.unfocus();
                              onCtaDisabledTap!();
                            },
                            behavior: HitTestBehavior.opaque,
                            child: IgnorePointer(
                              child: SilarahPrimaryButton(
                                label: ctaLabel,
                                onTap: null,
                                isLoading: isCtaLoading,
                              ),
                            ),
                          )
                        else
                          SilarahPrimaryButton(
                            label: ctaLabel,
                            onTap: isCtaEnabled && onCta != null
                                ? () {
                                    FocusManager.instance.primaryFocus
                                        ?.unfocus();
                                    onCta!();
                                  }
                                : null,
                            isLoading: isCtaLoading,
                          ),
                        if (skipLabel != null && onSkip != null) ...[
                          const SizedBox(height: AppDimensions.space12),
                          SilarahPressable(
                            onTap: () {
                              FocusManager.instance.primaryFocus?.unfocus();
                              onSkip!();
                            },
                            haptic: false,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: AppDimensions.space8,
                                horizontal: AppDimensions.space12,
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
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SaveErrorNotice extends StatelessWidget {
  const _SaveErrorNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<OnboardingCubit>();
    final isLoading =
        context.watch<OnboardingCubit>().state is OnboardingLoading;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDimensions.space14),
      decoration: BoxDecoration(
        color: AppColors.softCoral.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
        border: Border.all(
          color: AppColors.softCoral.withValues(alpha: 0.55),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: AppColors.softCoral,
                size: AppDimensions.iconSizeMedium,
              ),
              const SizedBox(width: AppDimensions.space8),
              Expanded(
                child: Text(
                  message,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.pearlWhite,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.space10),
          SilarahSecondaryButton(
            label: 'Retry',
            icon: Icons.refresh_rounded,
            isLoading: isLoading,
            onTap: () {
              FocusManager.instance.primaryFocus?.unfocus();
              cubit.retryFailedSave();
            },
          ),
        ],
      ),
    );
  }
}

class _OnboardingBackdrop extends StatelessWidget {
  const _OnboardingBackdrop();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.midnightPlum.withValues(alpha: 0.64),
            AppColors.obsidianNight,
            AppColors.inkTeal.withValues(alpha: 0.26),
          ],
          stops: const [0, 0.54, 1],
        ),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0.18, -0.62),
            radius: 1.25,
            colors: [
              AppColors.champagneGold.withValues(alpha: 0.13),
              AppColors.navyCharcoal.withValues(alpha: 0.18),
              Colors.transparent,
            ],
            stops: const [0, 0.36, 1],
          ),
        ),
      ),
    );
  }
}

class _RevealOnStep extends StatelessWidget {
  const _RevealOnStep({
    required this.step,
    required this.child,
    this.delay = Duration.zero,
  });

  final int step;
  final Widget child;
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      key: ValueKey('${step}_${delay.inMilliseconds}'),
      tween: Tween(begin: 0, end: 1),
      duration: AppDimensions.durationReveal + delay,
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        final progress = delay == Duration.zero
            ? value
            : ((value - 0.18) / 0.82).clamp(0.0, 1.0).toDouble();
        return Opacity(
          opacity: progress,
          child: Transform.translate(
            offset: Offset(0, 14 * (1 - progress)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({this.onBack});
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return SilarahPressable(
      onTap: onBack == null
          ? null
          : () {
              FocusManager.instance.primaryFocus?.unfocus();
              onBack!();
            },
      haptic: false,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.surfaceGlassHover,
              AppColors.surfaceGlass.withValues(alpha: 0.28),
            ],
          ),
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.cardBorder),
          boxShadow: [
            BoxShadow(
              color: AppColors.obsidianNight.withValues(alpha: 0.35),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Icon(
          Directionality.of(context) == TextDirection.rtl
              ? Icons.arrow_forward_ios_rounded
              : Icons.arrow_back_ios_new_rounded,
          color: AppColors.pearlWhite,
          size: 16,
        ),
      ),
    );
  }
}
