// lib/features/onboarding/screens/income_screen.dart
// ============================================================
// NOOR — Income Screen (Onboarding Step 4)
// Region-aware income brackets loaded from mock data.
// Visibility toggle + easy skip option.
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

// ── Mock income brackets ─────────────────────────────────────
class _IncomeBracket {
  const _IncomeBracket(this.id, this.label);
  final String id;
  final String label;
}

const _kIncomeBrackets = <_IncomeBracket>[
  _IncomeBracket('in_1', '< ₹3 Lakh/year'),
  _IncomeBracket('in_2', '₹3 – 6 Lakh/year'),
  _IncomeBracket('in_3', '₹6 – 12 Lakh/year'),
  _IncomeBracket('in_4', '₹12 – 25 Lakh/year'),
  _IncomeBracket('in_5', '> ₹25 Lakh/year'),
];

const _kVisibilityOptions = [
  (id: 'hidden',    label: 'Keep private'),
  (id: 'bracket',   label: 'Show bracket to everyone'),
  (id: 'after_match', label: 'Show only after mutual interest'),
];

class IncomeScreen extends StatefulWidget {
  const IncomeScreen({super.key});

  @override
  State<IncomeScreen> createState() => _IncomeScreenState();
}

class _IncomeScreenState extends State<IncomeScreen> {
  _IncomeBracket? _bracket;
  String _visibility = 'bracket';

  void _advance() {
    final data = context.read<OnboardingCubit>().currentData.copyWith(
      incomeBracketId:    _bracket?.id,
      incomeBracketLabel: _bracket?.label,
      incomeVisibility:   _visibility,
    );
    context.read<OnboardingCubit>().saveAndAdvance(data);
  }

  void _skip() => context.read<OnboardingCubit>().skipStep();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<OnboardingCubit, OnboardingState>(
      builder: (context, state) {
        final isLoading = state is OnboardingLoading;
        return OnboardingScaffold(
          step:         4,
          ctaLabel:     'Continue',
          onCta:        _advance,
          isCtaEnabled: true,
          isCtaLoading: isLoading,
          skipLabel:    'Skip for now',
          onSkip:       _skip,
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppDimensions.space32),
              const StepHeader(
                title:    'Income range',
                subtitle: 'This is entirely optional. Many people skip this.',
              ),
              const SizedBox(height: AppDimensions.space8),

              // Soft note
              Container(
                padding: const EdgeInsets.all(AppDimensions.space12),
                decoration: BoxDecoration(
                  color:        AppColors.goldGlow,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
                  border:       Border.all(color: AppColors.goldBorder),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded,
                        color: AppColors.champagneGold, size: 18),
                    const SizedBox(width: AppDimensions.space8),
                    Expanded(
                      child: Text(
                        'Income information helps find financially compatible matches. '
                        'You control who sees it.',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.champagneGold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppDimensions.space24),

              Text('INCOME BRACKET (INR)', style: AppTypography.sectionLabel),
              const SizedBox(height: AppDimensions.space12),

              ..._kIncomeBrackets.map((b) => Padding(
                padding: const EdgeInsets.only(bottom: AppDimensions.space8),
                child: GestureDetector(
                  onTap: () => setState(() =>
                      _bracket = _bracket?.id == b.id ? null : b),
                  child: AnimatedContainer(
                    duration: AppDimensions.durationTransition,
                    padding: const EdgeInsets.all(AppDimensions.space16),
                    decoration: BoxDecoration(
                      color: _bracket?.id == b.id
                          ? AppColors.champagneGold.withValues(alpha: 0.08)
                          : AppColors.surfaceGlass,
                      borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
                      border: Border.all(
                        color: _bracket?.id == b.id
                            ? AppColors.champagneGold
                            : AppColors.cardBorder,
                        width: _bracket?.id == b.id
                            ? AppDimensions.borderFocus
                            : AppDimensions.borderThin,
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(b.label, style: AppTypography.body),
                        ),
                        if (_bracket?.id == b.id)
                          const Icon(Icons.check_rounded,
                              color: AppColors.champagneGold, size: 20),
                      ],
                    ),
                  ),
                ),
              )),

              const SizedBox(height: AppDimensions.space24),

              Text('WHO CAN SEE THIS?', style: AppTypography.sectionLabel),
              const SizedBox(height: AppDimensions.space12),

              ..._kVisibilityOptions.map((opt) => Padding(
                padding: const EdgeInsets.only(bottom: AppDimensions.space8),
                child: GestureDetector(
                  onTap: () => setState(() => _visibility = opt.id),
                  child: AnimatedContainer(
                    duration: AppDimensions.durationTransition,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimensions.space16,
                      vertical:   AppDimensions.space12,
                    ),
                    decoration: BoxDecoration(
                      color: _visibility == opt.id
                          ? AppColors.surfaceGlassHover
                          : AppColors.surfaceGlass,
                      borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
                      border: Border.all(
                        color: _visibility == opt.id
                            ? AppColors.champagneGold
                            : AppColors.cardBorder,
                        width: _visibility == opt.id
                            ? AppDimensions.borderFocus
                            : AppDimensions.borderThin,
                      ),
                    ),
                    child: Row(
                      children: [
                        AnimatedContainer(
                          duration: AppDimensions.durationTransition,
                          width:  20, height: 20,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _visibility == opt.id
                                ? AppColors.champagneGold
                                : AppColors.transparent,
                            border: Border.all(
                              color: _visibility == opt.id
                                  ? AppColors.champagneGold
                                  : AppColors.slateMist,
                            ),
                          ),
                          child: _visibility == opt.id
                              ? const Icon(Icons.circle,
                                  size: 10, color: AppColors.obsidianNight)
                              : null,
                        ),
                        const SizedBox(width: AppDimensions.space12),
                        Text(opt.label, style: AppTypography.body),
                      ],
                    ),
                  ),
                ),
              )),

              const SizedBox(height: AppDimensions.space32),
            ],
          ),
        );
      },
    );
  }
}
