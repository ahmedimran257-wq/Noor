// lib/features/onboarding/screens/provider_readiness_screen.dart
// ============================================================
// NOOR — Provider Readiness Screen (Male-Only)
// Collects: canProvideHousing, canProvideMaintenance, debtStatus
//
// Blueprint (Part 4):
//   "A man who is unable to provide financially should be
//    honest about that — the platform does not gatekeep, but
//    it encourages transparency."
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/cubits/onboarding/onboarding_cubit.dart';
import '../../../core/cubits/onboarding/onboarding_state.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../widgets/onboarding_scaffold.dart';
import '../widgets/step_header.dart';

class ProviderReadinessScreen extends StatefulWidget {
  const ProviderReadinessScreen({super.key});

  @override
  State<ProviderReadinessScreen> createState() =>
      _ProviderReadinessScreenState();
}

class _ProviderReadinessScreenState extends State<ProviderReadinessScreen> {
  bool?   _canProvideHousing;
  bool?   _canProvideMaintenance;
  String? _debtStatus;

  bool get _canProceed =>
      _canProvideHousing != null &&
      _canProvideMaintenance != null &&
      _debtStatus != null;

  void _advance() {
    final data = context.read<OnboardingCubit>().currentData.copyWith(
      canProvideHousing:     _canProvideHousing,
      canProvideMaintenance: _canProvideMaintenance,
      debtStatus:            _debtStatus,
    );
    context.read<OnboardingCubit>().saveAndAdvance(data);
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<OnboardingCubit, OnboardingState>(
      builder: (context, state) {
        final isLoading = state is OnboardingLoading;
        return OnboardingScaffold(
          step:         state is OnboardingActive ? state.step : 6,
          totalSteps:   13,
          ctaLabel:     'Continue',
          onCta:        _advance,
          isCtaEnabled: _canProceed,
          isCtaLoading: isLoading,
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppDimensions.space32),

              const StepHeader(
                title:    'Provider readiness',
                subtitle: 'Transparency builds trust. All answers are private.',
              ),
              const SizedBox(height: AppDimensions.space8),

              // Islamic context banner
              Container(
                padding: const EdgeInsets.all(AppDimensions.space16),
                decoration: BoxDecoration(
                  color: AppColors.champagneGold.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
                  border: Border.all(color: AppColors.goldBorder),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.auto_awesome_outlined,
                        color: AppColors.champagneGold, size: 18),
                    const SizedBox(width: AppDimensions.space12),
                    Expanded(
                      child: Text(
                        '"The best of you are the best to your wives." — Prophet Muhammad ﷺ\n\n'
                        'Being honest about your readiness helps build a strong foundation.',
                        style: AppTypography.caption.copyWith(height: 1.6),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppDimensions.space28),

              // ── Can Provide Housing ───────────────────────────
              Text('HOUSING', style: AppTypography.sectionLabel),
              const SizedBox(height: AppDimensions.space4),
              Text(
                'Can you provide a separate living space?',
                style: AppTypography.caption,
              ),
              const SizedBox(height: AppDimensions.space12),
              _buildYesNo(_canProvideHousing, (v) =>
                  setState(() => _canProvideHousing = v)),

              const SizedBox(height: AppDimensions.space24),

              // ── Can Provide Maintenance ───────────────────────
              Text('FINANCIAL MAINTENANCE', style: AppTypography.sectionLabel),
              const SizedBox(height: AppDimensions.space4),
              Text(
                'Are you able to provide for a spouse financially?',
                style: AppTypography.caption,
              ),
              const SizedBox(height: AppDimensions.space12),
              _buildYesNo(_canProvideMaintenance, (v) =>
                  setState(() => _canProvideMaintenance = v)),

              const SizedBox(height: AppDimensions.space24),

              // ── Debt Status ───────────────────────────────────
              Text('DEBT STATUS', style: AppTypography.sectionLabel),
              const SizedBox(height: AppDimensions.space4),
              Text(
                'Your current financial obligations.',
                style: AppTypography.caption,
              ),
              const SizedBox(height: AppDimensions.space12),
              _buildChipRow(_debtStatus, {
                'no_debt':          'No debt',
                'manageable':       'Manageable debt',
                'significant':      'Significant debt',
                'prefer_not_to_say': 'Prefer not to say',
              }, (v) => setState(() => _debtStatus = v)),

              const SizedBox(height: AppDimensions.space24),

              // Privacy notice
              Container(
                padding: const EdgeInsets.all(AppDimensions.space16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceGlass,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.lock_outline_rounded,
                        color: AppColors.slateMist, size: 16),
                    const SizedBox(width: AppDimensions.space10),
                    Expanded(
                      child: Text(
                        'These details are not shown on your public profile. '
                        'They are shared privately during the acceptance stage.',
                        style: AppTypography.caption.copyWith(height: 1.6),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppDimensions.space40),
            ],
          ),
        );
      },
    );
  }

  Widget _buildYesNo(bool? selected, ValueChanged<bool> onChanged) {
    return Row(
      children: [
        Expanded(child: _buildOption(
          label: 'Yes',
          isActive: selected == true,
          onTap: () => onChanged(true),
        )),
        const SizedBox(width: AppDimensions.space12),
        Expanded(child: _buildOption(
          label: 'No',
          isActive: selected == false,
          onTap: () => onChanged(false),
        )),
      ],
    );
  }

  Widget _buildOption({
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppDimensions.durationTransition,
        padding: const EdgeInsets.symmetric(vertical: AppDimensions.space14),
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.champagneGold.withValues(alpha: 0.12)
              : AppColors.surfaceGlass,
          borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
          border: Border.all(
            color: isActive ? AppColors.champagneGold : AppColors.cardBorder,
            width: isActive ? AppDimensions.borderFocus : AppDimensions.borderThin,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: AppTypography.bodyMedium.copyWith(
              color: isActive ? AppColors.champagneGold : AppColors.pearlWhite,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChipRow(
    String? selected,
    Map<String, String> options,
    ValueChanged<String> onSelected,
  ) {
    return Wrap(
      spacing:    AppDimensions.space8,
      runSpacing: AppDimensions.space8,
      children: options.entries.map((e) {
        final isActive = selected == e.key;
        return GestureDetector(
          onTap: () => onSelected(e.key),
          child: AnimatedContainer(
            duration: AppDimensions.durationTransition,
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.space16,
              vertical:   AppDimensions.space10,
            ),
            decoration: BoxDecoration(
              color: isActive
                  ? AppColors.champagneGold.withValues(alpha: 0.12)
                  : AppColors.surfaceGlass,
              borderRadius: BorderRadius.circular(AppDimensions.radiusChip),
              border: Border.all(
                color: isActive ? AppColors.champagneGold : AppColors.cardBorder,
                width: isActive ? AppDimensions.borderFocus : AppDimensions.borderThin,
              ),
            ),
            child: Text(
              e.value,
              style: AppTypography.chipLabel.copyWith(
                color: isActive ? AppColors.champagneGold : AppColors.pearlWhite,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
