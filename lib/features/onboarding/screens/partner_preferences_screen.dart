// lib/features/onboarding/screens/partner_preferences_screen.dart
// ============================================================
// NOOR — Partner Preferences Screen (Onboarding Step 7)
// Age range slider, location preference, sect/deen/education prefs,
// openness toggles, living arrangement preference (Phase 2).
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/cubits/onboarding/onboarding_cubit.dart';
import '../../../core/cubits/onboarding/onboarding_state.dart';
import '../../../core/models/onboarding_data.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../widgets/onboarding_scaffold.dart';
import '../widgets/step_header.dart';


// Living arrangement preference options (Phase 2)
const _kLivingPrefOptions = [
  (value: 'no_preference', label: 'No Preference'),
  (value: 'with_inlaws',   label: 'With Family'),
  (value: 'separate',      label: 'Separate Home'),
  (value: 'open_to_discussion', label: 'Open to Discussion'),
];

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
  String              _preferredLiving  = 'no_preference'; // Phase 2

  @override
  void initState() {
    super.initState();
    final data = context.read<OnboardingCubit>().currentData;
    _ageMin = data.preferredAgeMin?.toDouble() ?? 22;
    _ageMax = data.preferredAgeMax?.toDouble() ?? 32;
    _location = data.locationPreference ?? LocationPreference.sameCountry;
    _prefSect = data.preferredSect;
    _prefDeen = data.preferredDeenLevel;
    _minEduRank = data.minEducationRank;
    _openToDivorced = data.openToDivorced ?? false;
    _openToWidowed = data.openToWidowed ?? false;
    _openToChildren = data.openToWithChildren ?? false;
    _preferredLiving = data.preferredLivingExpectation ?? 'no_preference';
  }
  // _preferredMarriageTimeline removed — collected in Marriage & Deen Details screen

  static const _sectOptions = ['Any', 'Sunni', 'Shia', 'Same as mine'];
  static const _deenOptions = ['Any', 'Practicing', 'Moderate', 'Cultural Muslim'];
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
      preferredAgeMin:            _ageMin.round(),
      preferredAgeMax:            _ageMax.round(),
      locationPreference:         _location,
      preferredSect:              _prefSect,
      preferredDeenLevel:         _prefDeen,
      minEducationRank:           _minEduRank,
      openToDivorced:             _openToDivorced,
      openToWidowed:              _openToWidowed,
      openToWithChildren:         _openToChildren,
      preferredLivingExpectation: _preferredLiving,
    );
    context.read<OnboardingCubit>().saveAndAdvance(data);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final obData = context.read<OnboardingCubit>().currentData;
    final isGuardian = obData.isGuardianMode;
    final relation = obData.profileCreatorRelation ?? 'ward';

    // Helper to get localized relationship string
    String getRelationString() {
      switch (relation) {
        case 'son':
          return l10n.onboarding_profileForWhom_relation_son.toLowerCase();
        case 'daughter':
          return l10n.onboarding_profileForWhom_relation_daughter.toLowerCase();
        case 'brother':
          return l10n.onboarding_profileForWhom_relation_brother.toLowerCase();
        case 'sister':
          return l10n.onboarding_profileForWhom_relation_sister.toLowerCase();
        default:
          return l10n.onboarding_profileForWhom_ward.toLowerCase();
      }
    }

    String getPrefLocationLabel(LocationPreference pref) {
      switch (pref) {
        case LocationPreference.sameCity:
          return l10n.preferences_location_same_city;
        case LocationPreference.sameCountry:
          return l10n.preferences_location_same_country;
        case LocationPreference.openToAbroad:
          return l10n.preferences_location_abroad;
        case LocationPreference.diaspora:
          return l10n.preferences_location_diaspora;
      }
    }

    String getSectLabel(String s) {
      switch (s) {
        case 'Any':
          return l10n.preferences_sect_any;
        case 'Sunni':
          return l10n.preferences_sect_sunni;
        case 'Shia':
          return l10n.preferences_sect_shia;
        case 'Same as mine':
          return l10n.preferences_sect_same;
        default:
          return s;
      }
    }

    String getDeenLabel(String d) {
      switch (d) {
        case 'Any':
          return l10n.preferences_deen_any;
        case 'Practicing':
          return l10n.preferences_deen_practicing;
        case 'Moderate':
          return l10n.preferences_deen_moderate;
        case 'Cultural Muslim':
          return l10n.preferences_deen_cultural;
        default:
          return d;
      }
    }

    String getEduLabel(int rank) {
      switch (rank) {
        case 1:
          return l10n.preferences_edu_any;
        case 2:
          return l10n.preferences_edu_secondary;
        case 4:
          return l10n.preferences_edu_diploma;
        case 5:
          return l10n.preferences_edu_bachelors;
        case 6:
          return l10n.preferences_edu_masters;
        case 7:
          return l10n.preferences_edu_phd;
        default:
          return '';
      }
    }

    String getPrefLivingLabel(String value) {
      switch (value) {
        case 'no_preference':
          return l10n.preferences_living_no_pref;
        case 'with_inlaws':
          return l10n.preferences_living_family;
        case 'separate':
          return l10n.preferences_living_separate;
        case 'open_to_discussion':
          return l10n.preferences_living_discussion;
        default:
          return value;
      }
    }

    return BlocBuilder<OnboardingCubit, OnboardingState>(
      builder: (context, state) {
        final isLoading = state is OnboardingLoading;
        return OnboardingScaffold(
          ctaLabel: l10n.legal_button_continue, onCta: _advance,
          isCtaEnabled: true, isCtaLoading: isLoading,
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppDimensions.space32),
              StepHeader(
                title:    l10n.preferences_title,
                subtitle: isGuardian
                    ? l10n.preferences_subtitle_guardian(getRelationString())
                    : l10n.preferences_subtitle_self,
              ),
              const SizedBox(height: AppDimensions.space32),

              // Age range
              _Label(l10n.preferences_label_age),
              const SizedBox(height: AppDimensions.space8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(l10n.preferences_label_age_range(_ageMin.round().toString(), _ageMax.round().toString()),
                      style: AppTypography.bodyMedium.copyWith(color: AppColors.champagneGold)),
                  Text(l10n.preferences_label_age_bounds, style: AppTypography.caption),
                ],
              ),
              const SizedBox(height: AppDimensions.space8),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 3,
                  activeTrackColor: AppColors.champagneGold,
                  inactiveTrackColor: AppColors.progressBarBase,
                  thumbColor: AppColors.champagneGold,
                  overlayColor: AppColors.goldGlow,
                  valueIndicatorColor: AppColors.champagneGold,
                  valueIndicatorTextStyle: AppTypography.caption.copyWith(color: AppColors.obsidianNight),
                ),
                child: RangeSlider(
                  values: RangeValues(_ageMin, _ageMax),
                  min: 18, max: 60, divisions: 42,
                  labels: RangeLabels(_ageMin.round().toString(), _ageMax.round().toString()),
                  onChanged: (v) {
                    if (v.end - v.start < 3) return;
                    setState(() { _ageMin = v.start; _ageMax = v.end; });
                  },
                ),
              ),

              const SizedBox(height: AppDimensions.space24),

              // Location preference
              _Label(l10n.preferences_label_location),
              const SizedBox(height: AppDimensions.space12),
              Wrap(
                spacing: AppDimensions.space8, runSpacing: AppDimensions.space8,
                children: LocationPreference.values.map((pref) {
                  final isSel = _location == pref;
                  return GestureDetector(
                    onTap: () => setState(() => _location = pref),
                    child: _PrefChip(label: getPrefLocationLabel(pref), isSelected: isSel),
                  );
                }).toList(),
              ),

              const SizedBox(height: AppDimensions.space24),

              // Sect preference
              _Label(l10n.preferences_label_sect),
              const SizedBox(height: AppDimensions.space12),
              Wrap(
                spacing: AppDimensions.space8, runSpacing: AppDimensions.space8,
                children: _sectOptions.map((s) => GestureDetector(
                  onTap: () => setState(() => _prefSect = s),
                  child: _PrefChip(label: getSectLabel(s), isSelected: _prefSect == s),
                )).toList(),
              ),

              const SizedBox(height: AppDimensions.space24),

              // Deen preference
              _Label(l10n.preferences_label_deen),
              const SizedBox(height: AppDimensions.space12),
              Wrap(
                spacing: AppDimensions.space8, runSpacing: AppDimensions.space8,
                children: _deenOptions.map((d) => GestureDetector(
                  onTap: () => setState(() => _prefDeen = d),
                  child: _PrefChip(label: getDeenLabel(d), isSelected: _prefDeen == d),
                )).toList(),
              ),

              const SizedBox(height: AppDimensions.space24),

              // Min education
              _Label(l10n.preferences_label_edu),
              const SizedBox(height: AppDimensions.space12),
              Wrap(
                spacing: AppDimensions.space8, runSpacing: AppDimensions.space8,
                children: _eduRanks.map((e) => GestureDetector(
                  onTap: () => setState(() => _minEduRank = e.rank),
                  child: _PrefChip(label: getEduLabel(e.rank), isSelected: _minEduRank == e.rank),
                )).toList(),
              ),

              const SizedBox(height: AppDimensions.space24),

              // Openness toggles
              _Label(l10n.preferences_label_openness),
              const SizedBox(height: AppDimensions.space12),
              _OpenTile(
                label: l10n.preferences_open_divorced,
                value: _openToDivorced,
                onChanged: (v) => setState(() => _openToDivorced = v),
              ),
              const SizedBox(height: AppDimensions.space8),
              _OpenTile(
                label: l10n.preferences_open_widowed,
                value: _openToWidowed,
                onChanged: (v) => setState(() => _openToWidowed = v),
              ),
              const SizedBox(height: AppDimensions.space8),
              _OpenTile(
                label: l10n.preferences_open_children,
                value: _openToChildren,
                onChanged: (v) => setState(() => _openToChildren = v),
              ),

              // ── LIVING ARRANGEMENT PREFERENCE (Phase 2) ────
              const SizedBox(height: AppDimensions.space24),
              _Label(l10n.preferences_label_living),
              const SizedBox(height: AppDimensions.space12),
              Wrap(
                spacing: AppDimensions.space8, runSpacing: AppDimensions.space8,
                children: _kLivingPrefOptions.map((opt) => GestureDetector(
                  onTap: () => setState(() => _preferredLiving = opt.value),
                  child: _PrefChip(label: getPrefLivingLabel(opt.value), isSelected: _preferredLiving == opt.value),
                )).toList(),
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
  Widget build(BuildContext context) => Text(text, style: AppTypography.sectionLabel);
}

class _PrefChip extends StatelessWidget {
  const _PrefChip({required this.label, required this.isSelected});
  final String label;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
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
    );
  }
}

class _OpenTile extends StatelessWidget {
  const _OpenTile({required this.label, required this.value, required this.onChanged});
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppDimensions.space16, vertical: AppDimensions.space14),
        decoration: BoxDecoration(
          color: AppColors.surfaceGlass,
          borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Row(children: [
          Expanded(child: Text(label, style: AppTypography.body)),
          AnimatedContainer(
            duration: AppDimensions.durationTransition,
            width: 48, height: 28, padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: value ? AppColors.champagneGold : AppColors.surfaceGlassHover,
              borderRadius: BorderRadius.circular(14),
            ),
            child: AnimatedAlign(
              duration: AppDimensions.durationTransition,
              alignment: value ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
              child: Container(
                width: 22, height: 22,
                decoration: BoxDecoration(
                  color: value ? AppColors.obsidianNight : AppColors.slateMist,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
