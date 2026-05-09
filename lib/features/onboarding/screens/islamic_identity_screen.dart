// lib/features/onboarding/screens/islamic_identity_screen.dart
// ============================================================
// NOOR — Islamic Identity Screen (Onboarding Step 2)
// Phase 2: CopyEngine for guardian-aware copy.
// Phase 2: Lifestyle & Diet section added.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/cubits/onboarding/onboarding_cubit.dart';
import '../../../core/cubits/onboarding/onboarding_state.dart';
import '../../../core/models/onboarding_data.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/copy_engine.dart';
import '../widgets/onboarding_scaffold.dart';
import '../widgets/step_header.dart';

bool _mockShowSect    = true;
bool _mockShowSubSect = true;

class IslamicIdentityScreen extends StatefulWidget {
  const IslamicIdentityScreen({super.key});
  @override
  State<IslamicIdentityScreen> createState() => _IslamicIdentityScreenState();
}

class _IslamicIdentityScreenState extends State<IslamicIdentityScreen> {
  Sect?      _sect;
  String?    _subSect;
  DeenLevel? _deenLevel;
  bool?      _praysFive;
  String?    _hijab;
  bool?      _beard;
  String?    _religiousLeadership; // male-only
  String?    _dietType;
  String?    _smokingHabit;
  String?    _vapingHabit;
  String?    _hookahHabit;

  static const _subSects = [
    'Hanafi', 'Shafi\'i', 'Maliki', 'Hanbali',
    'Salafi', 'Ahle Hadith', 'Deobandi', 'Barelvi', 'Other',
  ];
  static const _hijabOptions = ['Always', 'Sometimes', 'No', 'Prefer not to say'];
  static const _deenTooltips = {
    'Practicing': 'Actively follows Islamic obligations: prayers, fasting, halal diet.',
    'Moderate':   'Identifies as Muslim and follows core practices but may not strictly observe all.',
    'Cultural':   'Muslim by identity and family heritage but less focused on religious practice.',
  };
  static const _habitOptions = ['Never', 'Occasionally', 'Frequently', 'Prefer not to say'];
  static const _dietOptions = [
    ('Strict Zabiha',       'zabiha_strict'),
    ('Halal only',          'halal_only'),
    ('Eats anything halal', 'eats_anything'),
    ('Vegetarian',          'vegetarian'),
    ('Vegan',               'vegan'),
  ];

  bool get _canProceed =>
      _deenLevel    != null && _praysFive != null &&
      _dietType     != null && _smokingHabit != null &&
      _vapingHabit  != null && _hookahHabit  != null;

  Gender? get _gender => context.read<OnboardingCubit>().currentData.gender;

  // TODO (backend): read from Supabase profiles.profileCreatorRelation.
  String get _relation =>
      context.read<OnboardingCubit>().currentData.profileCreatorRelation ?? 'self';

  void _advance() {
    final data = context.read<OnboardingCubit>().currentData.copyWith(
      sect: _sect, subSect: _subSect, deenLevel: _deenLevel,
      praysFiveDaily: _praysFive, hijabStyle: _hijab, hasBeard: _beard,
      religiousLeadership: _religiousLeadership,
      dietType: _dietType, smokingHabit: _smokingHabit,
      vapingHabit: _vapingHabit, hookahHabit: _hookahHabit,
    );
    context.read<OnboardingCubit>().saveAndAdvance(data);
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<OnboardingCubit, OnboardingState>(
      builder: (context, state) {
        final isLoading = state is OnboardingLoading;
        return OnboardingScaffold(
          step: 2, ctaLabel: 'Continue', onCta: _advance,
          isCtaEnabled: _canProceed, isCtaLoading: isLoading,
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppDimensions.space32),
              const StepHeader(title: 'Your faith', subtitle: 'This helps match you with someone compatible.'),
              const SizedBox(height: AppDimensions.space32),

              if (_mockShowSect) ...[
                _SectionTitle('SECT'),
                const SizedBox(height: AppDimensions.space12),
                _ChipGroup<Sect>(
                  options: [Sect.sunni, Sect.shia, Sect.preferNotToSay, Sect.other],
                  selected: _sect,
                  label: (s) {
                    switch (s) {
                      case Sect.sunni:          return 'Sunni';
                      case Sect.shia:           return 'Shia';
                      case Sect.preferNotToSay: return 'Prefer not to say';
                      case Sect.other:          return 'Other';
                    }
                  },
                  onSelected: (s) => setState(() { _sect = s; _subSect = null; }),
                ),
                const SizedBox(height: AppDimensions.space20),
                if (_sect == Sect.sunni && _mockShowSubSect) ...[
                  _SectionTitle('SCHOOL OF THOUGHT  (Optional)'),
                  const SizedBox(height: AppDimensions.space12),
                  Wrap(
                    spacing: AppDimensions.space8, runSpacing: AppDimensions.space8,
                    children: _subSects.map((s) => _SelectChip(
                      label: s, isSelected: _subSect == s,
                      onTap: () => setState(() => _subSect = _subSect == s ? null : s),
                    )).toList(),
                  ),
                  const SizedBox(height: AppDimensions.space20),
                ],
              ],

              _SectionTitle('DEEN LEVEL'),
              const SizedBox(height: AppDimensions.space12),
              Column(
                children: DeenLevel.values.map((d) {
                  final label = _deenLabel(d);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppDimensions.space8),
                    child: _DeenCard(
                      label: label, tooltip: _deenTooltips[label] ?? '',
                      isSelected: _deenLevel == d,
                      onTap: () => setState(() => _deenLevel = d),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: AppDimensions.space20),

              _SectionTitle(CopyEngine.prayerQuestion(_relation).toUpperCase()),
              const SizedBox(height: AppDimensions.space12),
              Row(children: [
                Expanded(child: _TogglePill(label: 'Yes', isSelected: _praysFive == true,  onTap: () => setState(() => _praysFive = true))),
                const SizedBox(width: AppDimensions.space12),
                Expanded(child: _TogglePill(label: 'No',  isSelected: _praysFive == false, onTap: () => setState(() => _praysFive = false))),
              ]),

              if (_gender == Gender.female) ...[
                const SizedBox(height: AppDimensions.space20),
                _SectionTitle(CopyEngine.hijabQuestion(_relation, 'female').toUpperCase()),
                const SizedBox(height: AppDimensions.space12),
                Wrap(
                  spacing: AppDimensions.space8, runSpacing: AppDimensions.space8,
                  children: _hijabOptions.map((o) => _SelectChip(
                    label: o, isSelected: _hijab == o,
                    onTap: () => setState(() => _hijab = _hijab == o ? null : o),
                  )).toList(),
                ),
              ],

              if (_gender == Gender.male) ...[
                const SizedBox(height: AppDimensions.space20),
                _SectionTitle(CopyEngine.beardQuestion(_relation).toUpperCase()),
                const SizedBox(height: AppDimensions.space12),
                Wrap(
                  spacing: AppDimensions.space8, runSpacing: AppDimensions.space8,
                  children: ['Yes', 'No', 'Prefer not to say'].map((o) => _SelectChip(
                    label: o,
                    isSelected: o == 'Prefer not to say' ? _beard == null && _praysFive != null : _beard == (o == 'Yes'),
                    onTap: () => setState(() {
                      if (o == 'Prefer not to say') { _beard = null; } else { _beard = o == 'Yes'; }
                    }),
                  )).toList(),
                ),
                const SizedBox(height: AppDimensions.space20),
                _SectionTitle('RELIGIOUS LEADERSHIP'),
                const SizedBox(height: AppDimensions.space4),
                Text('Can you lead congregational prayers?', style: AppTypography.caption),
                const SizedBox(height: AppDimensions.space12),
                Wrap(
                  spacing: AppDimensions.space8, runSpacing: AppDimensions.space8,
                  children: {
                    'leads_prayer': 'Leads Prayer',
                    'learning': 'Learning',
                    'not_yet': 'Not Yet',
                    'prefer_not_to_say': 'Prefer Not to Say',
                  }.entries.map((e) => _SelectChip(
                    label: e.value,
                    isSelected: _religiousLeadership == e.key,
                    onTap: () => setState(() => _religiousLeadership = e.key),
                  )).toList(),
                ),
              ],

              // ── LIFESTYLE & DIET ─────────────────────────
              const SizedBox(height: AppDimensions.space28),
              _SectionTitle('LIFESTYLE & DIET'),
              const SizedBox(height: AppDimensions.space6),
              Text('These are dealbreaker fields for many families. Please answer honestly.', style: AppTypography.caption),
              const SizedBox(height: AppDimensions.space16),

              _SectionTitle('DIET'),
              const SizedBox(height: AppDimensions.space12),
              Wrap(
                spacing: AppDimensions.space8, runSpacing: AppDimensions.space8,
                children: _dietOptions.map((opt) => _SelectChip(
                  label: opt.$1, isSelected: _dietType == opt.$2,
                  onTap: () => setState(() => _dietType = opt.$2),
                )).toList(),
              ),
              const SizedBox(height: AppDimensions.space20),

              _SectionTitle('SMOKING'),
              const SizedBox(height: AppDimensions.space12),
              Wrap(
                spacing: AppDimensions.space8, runSpacing: AppDimensions.space8,
                children: _habitOptions.map((o) => _SelectChip(
                  label: o, isSelected: _smokingHabit == o,
                  onTap: () => setState(() => _smokingHabit = o),
                )).toList(),
              ),
              const SizedBox(height: AppDimensions.space20),

              _SectionTitle('VAPING / E-CIGARETTES'),
              const SizedBox(height: AppDimensions.space12),
              Wrap(
                spacing: AppDimensions.space8, runSpacing: AppDimensions.space8,
                children: _habitOptions.map((o) => _SelectChip(
                  label: o, isSelected: _vapingHabit == o,
                  onTap: () => setState(() => _vapingHabit = o),
                )).toList(),
              ),
              const SizedBox(height: AppDimensions.space20),

              _SectionTitle('HOOKAH / SHISHA'),
              const SizedBox(height: AppDimensions.space12),
              Wrap(
                spacing: AppDimensions.space8, runSpacing: AppDimensions.space8,
                children: _habitOptions.map((o) => _SelectChip(
                  label: o, isSelected: _hookahHabit == o,
                  onTap: () => setState(() => _hookahHabit = o),
                )).toList(),
              ),

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
  Widget build(BuildContext context) => Text(text, style: AppTypography.sectionLabel);
}

class _ChipGroup<T> extends StatelessWidget {
  const _ChipGroup({required this.options, required this.selected, required this.label, required this.onSelected});
  final List<T> options;
  final T? selected;
  final String Function(T) label;
  final ValueChanged<T> onSelected;
  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppDimensions.space8, runSpacing: AppDimensions.space8,
      children: options.map((o) => _SelectChip(
        label: label(o), isSelected: selected == o, onTap: () => onSelected(o),
      )).toList(),
    );
  }
}

class _SelectChip extends StatelessWidget {
  const _SelectChip({required this.label, required this.isSelected, required this.onTap});
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppDimensions.durationTransition,
        padding: const EdgeInsets.symmetric(horizontal: AppDimensions.space16, vertical: AppDimensions.space10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.champagneGold.withValues(alpha: 0.12) : AppColors.surfaceGlass,
          borderRadius: BorderRadius.circular(AppDimensions.radiusChip),
          border: Border.all(
            color: isSelected ? AppColors.champagneGold : AppColors.cardBorder,
            width: isSelected ? AppDimensions.borderFocus : AppDimensions.borderThin,
          ),
        ),
        child: Text(label, style: AppTypography.chipLabel.copyWith(
          color: isSelected ? AppColors.champagneGold : AppColors.pearlWhite,
        )),
      ),
    );
  }
}

class _DeenCard extends StatelessWidget {
  const _DeenCard({required this.label, required this.tooltip, required this.isSelected, required this.onTap});
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
          color: isSelected ? AppColors.champagneGold.withValues(alpha: 0.08) : AppColors.surfaceGlass,
          borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
          border: Border.all(
            color: isSelected ? AppColors.champagneGold : AppColors.cardBorder,
            width: isSelected ? AppDimensions.borderFocus : AppDimensions.borderThin,
          ),
        ),
        child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: AppTypography.bodyMedium.copyWith(color: isSelected ? AppColors.champagneGold : AppColors.pearlWhite)),
            const SizedBox(height: AppDimensions.space4),
            Text(tooltip, style: AppTypography.caption),
          ])),
          if (isSelected) Container(
            width: 20, height: 20,
            decoration: const BoxDecoration(color: AppColors.champagneGold, shape: BoxShape.circle),
            child: const Icon(Icons.check_rounded, color: AppColors.obsidianNight, size: 14),
          ),
        ]),
      ),
    );
  }
}

class _TogglePill extends StatelessWidget {
  const _TogglePill({required this.label, required this.isSelected, required this.onTap});
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
          color: isSelected ? AppColors.champagneGold.withValues(alpha: 0.1) : AppColors.surfaceGlass,
          borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
          border: Border.all(
            color: isSelected ? AppColors.champagneGold : AppColors.cardBorder,
            width: isSelected ? AppDimensions.borderFocus : AppDimensions.borderThin,
          ),
        ),
        child: Center(child: Text(label, style: AppTypography.bodyMedium.copyWith(
          color: isSelected ? AppColors.champagneGold : AppColors.pearlWhite,
        ))),
      ),
    );
  }
}

// ── Expose _SelectChip and _TogglePill for reuse ─────────────
