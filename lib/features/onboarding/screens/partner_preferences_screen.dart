// lib/features/onboarding/screens/partner_preferences_screen.dart
// ============================================================
// NOOR — Partner Preferences Screen (Onboarding Step 7)
// Age range slider, location preference, sect/deen/education prefs,
// openness toggles.
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

const _kLocationPrefLabels = {
  LocationPreference.sameCity:     'Same city',
  LocationPreference.sameCountry:  'Same country',
  LocationPreference.openToAbroad: 'Open to abroad',
  LocationPreference.diaspora:     'Diaspora mode',
};

class PartnerPreferencesScreen extends StatefulWidget {
  const PartnerPreferencesScreen({super.key});

  @override
  State<PartnerPreferencesScreen> createState() =>
      _PartnerPreferencesScreenState();
}

class _PartnerPreferencesScreenState extends State<PartnerPreferencesScreen> {
  double _ageMin = 22;
  double _ageMax = 32;
  LocationPreference  _location         = LocationPreference.sameCountry;
  String?             _prefSect;
  String?             _prefDeen;
  int?                _minEduRank;
  bool                _openToDivorced   = false;
  bool                _openToWidowed    = false;
  bool                _openToChildren   = false;

  static const _sectOptions = [
    'Any', 'Sunni', 'Shia', 'Same as mine',
  ];
  static const _deenOptions = [
    'Any', 'Practicing', 'Moderate', 'Cultural Muslim',
  ];
  static const _eduRanks = [
    (rank: 1, label: 'Any'),
    (rank: 2, label: 'Secondary +'),
    (rank: 4, label: 'Diploma +'),
    (rank: 5, label: 'Bachelor\'s +'),
    (rank: 6, label: 'Master\'s +'),
    (rank: 7, label: 'PhD only'),
  ];

  void _advance() {
    final data = context.read<OnboardingCubit>().currentData.copyWith(
      preferredAgeMin:    _ageMin.round(),
      preferredAgeMax:    _ageMax.round(),
      locationPreference: _location,
      preferredSect:      _prefSect,
      preferredDeenLevel: _prefDeen,
      minEducationRank:   _minEduRank,
      openToDivorced:     _openToDivorced,
      openToWidowed:      _openToWidowed,
      openToWithChildren: _openToChildren,
    );
    context.read<OnboardingCubit>().saveAndAdvance(data);
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<OnboardingCubit, OnboardingState>(
      builder: (context, state) {
        final isLoading = state is OnboardingLoading;
        return OnboardingScaffold(
          step:         7,
          ctaLabel:     'Continue',
          onCta:        _advance,
          isCtaEnabled: true,
          isCtaLoading: isLoading,
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppDimensions.space32),
              const StepHeader(
                title:    'Partner preferences',
                subtitle: 'These are preferences, not hard filters.',
              ),
              const SizedBox(height: AppDimensions.space32),

              // Age range
              _Label('AGE RANGE'),
              const SizedBox(height: AppDimensions.space8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${_ageMin.round()} – ${_ageMax.round()} years',
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.champagneGold,
                    ),
                  ),
                  Text('18 – 60', style: AppTypography.caption),
                ],
              ),
              const SizedBox(height: AppDimensions.space8),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight:            3,
                  activeTrackColor:       AppColors.champagneGold,
                  inactiveTrackColor:     AppColors.progressBarBase,
                  thumbColor:             AppColors.champagneGold,
                  overlayColor:           AppColors.goldGlow,
                  valueIndicatorColor:    AppColors.champagneGold,
                  valueIndicatorTextStyle: AppTypography.caption.copyWith(
                    color: AppColors.obsidianNight,
                  ),
                ),
                child: RangeSlider(
                  values: RangeValues(_ageMin, _ageMax),
                  min:    18,
                  max:    60,
                  divisions: 42,
                  labels: RangeLabels(
                    _ageMin.round().toString(),
                    _ageMax.round().toString(),
                  ),
                  onChanged: (v) {
                    if (v.end - v.start < 3) return; // minimum 3yr gap
                    setState(() {
                      _ageMin = v.start;
                      _ageMax = v.end;
                    });
                  },
                ),
              ),

              const SizedBox(height: AppDimensions.space24),

              // Location preference
              _Label('LOCATION'),
              const SizedBox(height: AppDimensions.space12),
              Wrap(
                spacing: AppDimensions.space8,
                runSpacing: AppDimensions.space8,
                children: LocationPreference.values.map((pref) {
                  final isSel = _location == pref;
                  return GestureDetector(
                    onTap: () => setState(() => _location = pref),
                    child: _PrefChip(
                      label:      _kLocationPrefLabels[pref]!,
                      isSelected: isSel,
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: AppDimensions.space24),

              // Sect preference
              _Label('SECT PREFERENCE'),
              const SizedBox(height: AppDimensions.space12),
              Wrap(
                spacing: AppDimensions.space8,
                runSpacing: AppDimensions.space8,
                children: _sectOptions.map((s) => GestureDetector(
                  onTap: () => setState(() => _prefSect = s),
                  child: _PrefChip(
                    label:      s,
                    isSelected: _prefSect == s,
                  ),
                )).toList(),
              ),

              const SizedBox(height: AppDimensions.space24),

              // Deen preference
              _Label('DEEN LEVEL PREFERENCE'),
              const SizedBox(height: AppDimensions.space12),
              Wrap(
                spacing: AppDimensions.space8,
                runSpacing: AppDimensions.space8,
                children: _deenOptions.map((d) => GestureDetector(
                  onTap: () => setState(() => _prefDeen = d),
                  child: _PrefChip(
                    label:      d,
                    isSelected: _prefDeen == d,
                  ),
                )).toList(),
              ),

              const SizedBox(height: AppDimensions.space24),

              // Min education
              _Label('MINIMUM EDUCATION'),
              const SizedBox(height: AppDimensions.space12),
              Wrap(
                spacing: AppDimensions.space8,
                runSpacing: AppDimensions.space8,
                children: _eduRanks.map((e) => GestureDetector(
                  onTap: () => setState(() => _minEduRank = e.rank),
                  child: _PrefChip(
                    label:      e.label,
                    isSelected: _minEduRank == e.rank,
                  ),
                )).toList(),
              ),

              const SizedBox(height: AppDimensions.space24),

              // Openness toggles
              _Label('OPENNESS'),
              const SizedBox(height: AppDimensions.space12),
              _OpenTile(
                label:     'Open to someone previously divorced',
                value:     _openToDivorced,
                onChanged: (v) => setState(() => _openToDivorced = v),
              ),
              const SizedBox(height: AppDimensions.space8),
              _OpenTile(
                label:     'Open to someone previously widowed',
                value:     _openToWidowed,
                onChanged: (v) => setState(() => _openToWidowed = v),
              ),
              const SizedBox(height: AppDimensions.space8),
              _OpenTile(
                label:     'Open to someone with children',
                value:     _openToChildren,
                onChanged: (v) => setState(() => _openToChildren = v),
              ),

              const SizedBox(height: AppDimensions.space32),
            ],
          ),
        );
      },
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) =>
      Text(text, style: AppTypography.sectionLabel);
}

class _PrefChip extends StatelessWidget {
  const _PrefChip({required this.label, required this.isSelected});
  final String label;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
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
      child: Text(label, style: AppTypography.chipLabel.copyWith(
        color: isSelected ? AppColors.champagneGold : AppColors.pearlWhite,
      )),
    );
  }
}

class _OpenTile extends StatelessWidget {
  const _OpenTile({
    required this.label,
    required this.value,
    required this.onChanged,
  });
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.space16,
          vertical:   AppDimensions.space14,
        ),
        decoration: BoxDecoration(
          color:        AppColors.surfaceGlass,
          borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
          border:       Border.all(color: AppColors.cardBorder),
        ),
        child: Row(
          children: [
            Expanded(child: Text(label, style: AppTypography.body)),
            AnimatedContainer(
              duration: AppDimensions.durationTransition,
              width:  48,
              height: 28,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: value ? AppColors.champagneGold : AppColors.surfaceGlassHover,
                borderRadius: BorderRadius.circular(14),
              ),
              child: AnimatedAlign(
                duration: AppDimensions.durationTransition,
                alignment: value
                    ? AlignmentDirectional.centerEnd
                    : AlignmentDirectional.centerStart,
                child: Container(
                  width: 22, height: 22,
                  decoration: BoxDecoration(
                    color: value ? AppColors.obsidianNight : AppColors.slateMist,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

