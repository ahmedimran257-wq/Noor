// lib/features/onboarding/screens/islamic_identity_screen.dart
// ============================================================
// NOOR — Islamic Identity Screen (Onboarding Step 2)
// Culturally adaptive: sect + sub-sect only shown where configured.
// Universal: deen level, prays 5x, hijab (women), beard (men).
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/cubits/onboarding/onboarding_cubit.dart';
import '../../../core/cubits/onboarding/onboarding_state.dart';
import '../../../core/models/onboarding_data.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../widgets/onboarding_scaffold.dart';
import '../widgets/step_header.dart';

// ── Mock country config (phase 4) ────────────────────────────
// In production this comes from Supabase based on countryCode.
bool _mockShowSect    = true;
bool _mockShowSubSect = true;

class IslamicIdentityScreen extends StatefulWidget {
  const IslamicIdentityScreen({super.key});

  @override
  State<IslamicIdentityScreen> createState() => _IslamicIdentityScreenState();
}

class _IslamicIdentityScreenState extends State<IslamicIdentityScreen> {
  Sect?       _sect;
  String?     _subSect;
  DeenLevel?  _deenLevel;
  bool?       _praysFive;
  String?     _hijab;  // women
  bool?       _beard;  // men

  static const _subSects = [
    'Hanafi', 'Shafi\'i', 'Maliki', 'Hanbali',
    'Salafi', 'Ahle Hadith', 'Deobandi', 'Barelvi', 'Other',
  ];
  static const _hijabOptions = [
    'Always', 'Sometimes', 'No', 'Prefer not to say',
  ];
  static const _deenTooltips = {
    'Practicing': 'Actively follows Islamic obligations: prayers, fasting, halal diet.',
    'Moderate':   'Identifies as Muslim and follows core practices but may not strictly observe all.',
    'Cultural':   'Muslim by identity and family heritage but less focused on religious practice.',
  };

  bool get _canProceed => _deenLevel != null && _praysFive != null;

  Gender? get _gender => context.read<OnboardingCubit>().currentData.gender;

  void _advance() {
    final data = context.read<OnboardingCubit>().currentData.copyWith(
      sect:          _sect,
      subSect:       _subSect,
      deenLevel:     _deenLevel,
      praysFiveDaily: _praysFive,
      hijabStyle:    _hijab,
      hasBrard:      _beard,
    );
    context.read<OnboardingCubit>().saveAndAdvance(data);
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<OnboardingCubit, OnboardingState>(
      builder: (context, state) {
        final isLoading = state is OnboardingLoading;
        return OnboardingScaffold(
          step:         2,
          ctaLabel:     'Continue',
          onCta:        _advance,
          isCtaEnabled: _canProceed,
          isCtaLoading: isLoading,
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppDimensions.space32),
              const StepHeader(
                title:    'Your faith',
                subtitle: 'This helps match you with someone compatible.',
              ),
              const SizedBox(height: AppDimensions.space32),

              // ── Sect (conditional) ──────────────────────
              if (_mockShowSect) ...[
                _SectionTitle('SECT'),
                const SizedBox(height: AppDimensions.space12),
                _ChipGroup<Sect>(
                  options:  [Sect.sunni, Sect.shia, Sect.preferNotToSay, Sect.other],
                  selected: _sect,
                  label:    (s) {
                    switch (s) {
                      case Sect.sunni:        return 'Sunni';
                      case Sect.shia:         return 'Shia';
                      case Sect.preferNotToSay: return 'Prefer not to say';
                      case Sect.other:        return 'Other';
                    }
                  },
                  onSelected: (s) => setState(() {
                    _sect    = s;
                    _subSect = null;
                  }),
                ),
                const SizedBox(height: AppDimensions.space20),

                // Sub-sect (conditional on Sunni + country config)
                if (_sect == Sect.sunni && _mockShowSubSect) ...[
                  _SectionTitle('SCHOOL OF THOUGHT  (Optional)'),
                  const SizedBox(height: AppDimensions.space12),
                  Wrap(
                    spacing: AppDimensions.space8,
                    runSpacing: AppDimensions.space8,
                    children: _subSects.map((s) => _SelectChip(
                      label:      s,
                      isSelected: _subSect == s,
                      onTap:      () => setState(() =>
                          _subSect = _subSect == s ? null : s),
                    )).toList(),
                  ),
                  const SizedBox(height: AppDimensions.space20),
                ],
              ],

              // ── Deen level ──────────────────────────────
              _SectionTitle('DEEN LEVEL'),
              const SizedBox(height: AppDimensions.space12),
              Column(
                children: DeenLevel.values.map((d) {
                  final label   = _deenLabel(d);
                  final tooltip = _deenTooltips[label] ?? '';
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppDimensions.space8),
                    child: _DeenCard(
                      label:      label,
                      tooltip:    tooltip,
                      isSelected: _deenLevel == d,
                      onTap:      () => setState(() => _deenLevel = d),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: AppDimensions.space20),

              // ── Prays 5x ────────────────────────────────
              _SectionTitle('DO YOU PRAY FIVE TIMES DAILY?'),
              const SizedBox(height: AppDimensions.space12),
              Row(
                children: [
                  Expanded(
                    child: _TogglePill(
                      label:      'Yes',
                      isSelected: _praysFive == true,
                      onTap:      () => setState(() => _praysFive = true),
                    ),
                  ),
                  const SizedBox(width: AppDimensions.space12),
                  Expanded(
                    child: _TogglePill(
                      label:      'No',
                      isSelected: _praysFive == false,
                      onTap:      () => setState(() => _praysFive = false),
                    ),
                  ),
                ],
              ),

              // ── Hijab (women only) ───────────────────────
              if (_gender == Gender.female) ...[
                const SizedBox(height: AppDimensions.space20),
                _SectionTitle('HIJAB'),
                const SizedBox(height: AppDimensions.space12),
                Wrap(
                  spacing: AppDimensions.space8,
                  runSpacing: AppDimensions.space8,
                  children: _hijabOptions.map((o) => _SelectChip(
                    label:      o,
                    isSelected: _hijab == o,
                    onTap:      () => setState(() =>
                        _hijab = _hijab == o ? null : o),
                  )).toList(),
                ),
              ],

              // ── Beard (men only) ──────────────────────────
              if (_gender == Gender.male) ...[
                const SizedBox(height: AppDimensions.space20),
                _SectionTitle('DO YOU HAVE A BEARD?'),
                const SizedBox(height: AppDimensions.space12),
                Wrap(
                  spacing: AppDimensions.space8,
                  runSpacing: AppDimensions.space8,
                  children: ['Yes', 'No', 'Prefer not to say'].map((o) => _SelectChip(
                    label:      o,
                    isSelected: _beard == (o == 'Yes'),
                    onTap: () => setState(() {
                      if (o == 'Prefer not to say') {
                        _beard = null;
                      } else {
                        _beard = o == 'Yes';
                      }
                    }),
                  )).toList(),
                ),
              ],

              const SizedBox(height: AppDimensions.space32),
            ],
          ),
        );
      },
    );
  }

  String _deenLabel(DeenLevel d) {
    switch (d) {
      case DeenLevel.practicing: return 'Practicing';
      case DeenLevel.moderate:   return 'Moderate';
      case DeenLevel.cultural:   return 'Cultural Muslim';
    }
  }
}

// ── Shared sub-widgets ────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) =>
      Text(text, style: AppTypography.sectionLabel);
}

class _ChipGroup<T> extends StatelessWidget {
  const _ChipGroup({
    required this.options,
    required this.selected,
    required this.label,
    required this.onSelected,
  });
  final List<T> options;
  final T? selected;
  final String Function(T) label;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppDimensions.space8,
      runSpacing: AppDimensions.space8,
      children: options.map((o) => _SelectChip(
        label:      label(o),
        isSelected: selected == o,
        onTap:      () => onSelected(o),
      )).toList(),
    );
  }
}

class _SelectChip extends StatelessWidget {
  const _SelectChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppDimensions.durationTransition,
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.space16,
          vertical:   AppDimensions.space10,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.champagneGold.withValues(alpha: 0.12)
              : AppColors.surfaceGlass,
          borderRadius: BorderRadius.circular(AppDimensions.radiusChip),
          border: Border.all(
            color: isSelected ? AppColors.champagneGold : AppColors.cardBorder,
            width: isSelected ? AppDimensions.borderFocus : AppDimensions.borderThin,
          ),
        ),
        child: Text(
          label,
          style: AppTypography.chipLabel.copyWith(
            color: isSelected ? AppColors.champagneGold : AppColors.pearlWhite,
          ),
        ),
      ),
    );
  }
}

class _DeenCard extends StatelessWidget {
  const _DeenCard({
    required this.label,
    required this.tooltip,
    required this.isSelected,
    required this.onTap,
  });
  final String label;
  final String tooltip;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppDimensions.durationTransition,
        padding: const EdgeInsets.all(AppDimensions.space16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.champagneGold.withValues(alpha: 0.08)
              : AppColors.surfaceGlass,
          borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
          border: Border.all(
            color: isSelected ? AppColors.champagneGold : AppColors.cardBorder,
            width: isSelected ? AppDimensions.borderFocus : AppDimensions.borderThin,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: AppTypography.bodyMedium.copyWith(
                    color: isSelected
                        ? AppColors.champagneGold
                        : AppColors.pearlWhite,
                  )),
                  const SizedBox(height: AppDimensions.space4),
                  Text(tooltip, style: AppTypography.caption),
                ],
              ),
            ),
            if (isSelected)
              Container(
                width: 20, height: 20,
                decoration: const BoxDecoration(
                  color: AppColors.champagneGold,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_rounded,
                    color: AppColors.obsidianNight, size: 14),
              ),
          ],
        ),
      ),
    );
  }
}

class _TogglePill extends StatelessWidget {
  const _TogglePill({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppDimensions.durationTransition,
        height: AppDimensions.buttonHeightSmall,
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.champagneGold.withValues(alpha: 0.1)
              : AppColors.surfaceGlass,
          borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
          border: Border.all(
            color: isSelected ? AppColors.champagneGold : AppColors.cardBorder,
            width: isSelected ? AppDimensions.borderFocus : AppDimensions.borderThin,
          ),
        ),
        child: Center(
          child: Text(label, style: AppTypography.bodyMedium.copyWith(
            color: isSelected ? AppColors.champagneGold : AppColors.pearlWhite,
          )),
        ),
      ),
    );
  }
}

// ── Expose _SelectChip and _TogglePill for reuse ─────────────
// These are used by other onboarding screens via export.
