// lib/features/onboarding/screens/family_screen.dart
// ============================================================
// MITHAQ — Family Background Screen (Onboarding Step 5)
// Family type, sibling count, parents status, marital history.
// Phase 2: Post-marriage living expectations added.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/cubits/onboarding/onboarding_cubit.dart';
import '../../../core/cubits/onboarding/onboarding_state.dart';
import '../../../core/models/onboarding_data.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/validation_snackbar.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../widgets/onboarding_scaffold.dart';
import '../widgets/step_header.dart';

const _kParentsStatuses = [
  'Together', 'Separated', 'Divorced',
  'Father deceased', 'Mother deceased', 'Both deceased',
];

// Living expectation options
const _kLivingOptions = [
  (value: 'with_inlaws', title: 'With In-Laws',
   subtitle: 'I expect to live with my spouse\'s or my own family.'),
  (value: 'separate', title: 'Separate Home',
   subtitle: 'I prefer we have our own independent home.'),
  (value: 'open_to_discussion', title: 'Open to Discussion',
   subtitle: 'I am flexible and happy to discuss what works for both.'),
];

class FamilyScreen extends StatefulWidget {
  const FamilyScreen({super.key});
  @override
  State<FamilyScreen> createState() => _FamilyScreenState();
}

class _FamilyScreenState extends State<FamilyScreen> {
  FamilyType?    _familyType;
  int            _siblings      = 0;
  String?        _parentsStatus;
  MaritalStatus  _marital       = MaritalStatus.neverMarried;
  bool?          _hasChildren;
  int            _childrenCount = 0;
  String?        _livingExpectation; // Phase 2
  String?        _willingToRelocate; // Phase 5.3
  String?        _polygamyStatus;    // Phase 1 — male optional
  String?        _polygamyAcceptance; // Phase 1 — female optional

  @override
  void initState() {
    super.initState();
    final data = context.read<OnboardingCubit>().currentData;
    _familyType = data.familyType;
    _siblings = data.siblingCount ?? 0;
    _parentsStatus = data.parentsStatus;
    _marital = data.maritalStatus ?? MaritalStatus.neverMarried;
    _hasChildren = data.hasChildren;
    _childrenCount = data.childrenCount ?? 0;
    _livingExpectation = data.livingExpectation;
    _willingToRelocate = data.willingToRelocate;
    _polygamyStatus = data.polygamyStatus;
    _polygamyAcceptance = data.polygamyAcceptance;
  }

  Gender? get _gender =>
      context.read<OnboardingCubit>().currentData.gender;

  bool get _canProceed =>
      _familyType != null &&
      _parentsStatus != null &&
      _livingExpectation != null; // Phase 2: required

  void _showValidation() {
    final l10n = AppLocalizations.of(context);
    final missing = <String>[];
    if (_familyType == null) missing.add(l10n.family_label_type);
    if (_parentsStatus == null) missing.add(l10n.family_label_parents);
    if (_livingExpectation == null) missing.add(l10n.family_living_title);
    showValidationSnackbar(context, missing);
  }

  void _advance() {
    final data = context.read<OnboardingCubit>().currentData.copyWith(
      familyType:         _familyType,
      siblingCount:       _siblings,
      parentsStatus:      _parentsStatus,
      maritalStatus:      _marital,
      hasChildren:        _hasChildren,
      childrenCount:      _hasChildren == true ? _childrenCount : 0,
      livingExpectation:  _livingExpectation,
      willingToRelocate:  _willingToRelocate,
      polygamyStatus:     _gender == Gender.male ? _polygamyStatus : null,
      polygamyAcceptance: _gender == Gender.female ? _polygamyAcceptance : null,
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

    String getParentsStatusLabel(String status) {
      switch (status) {
        case 'Together':
          return l10n.family_parents_together;
        case 'Separated':
          return l10n.family_parents_separated;
        case 'Divorced':
          return l10n.family_parents_divorced;
        case 'Father deceased':
          return l10n.family_parents_father_deceased;
        case 'Mother deceased':
          return l10n.family_parents_mother_deceased;
        case 'Both deceased':
          return l10n.family_parents_both_deceased;
        default:
          return status;
      }
    }

    (String, String) getLivingLabels(String value) {
      switch (value) {
        case 'with_inlaws':
          return (l10n.onboarding_living_withInlaws, l10n.onboarding_living_withInlawsSub);
        case 'separate':
          return (l10n.onboarding_living_separate, l10n.onboarding_living_separateSub);
        case 'open_to_discussion':
          return (l10n.onboarding_living_openToDiscussion, l10n.onboarding_living_openToDiscussionSub);
        default:
          return ('', '');
      }
    }

    String getWillingToRelocateLabel(String key) {
      switch (key) {
        case 'yes':
          return l10n.family_relocate_yes;
        case 'no':
          return l10n.family_relocate_no;
        case 'open_to_discussion':
          return l10n.family_relocate_discussion;
        default:
          return key;
      }
    }

    return BlocBuilder<OnboardingCubit, OnboardingState>(
      builder: (context, state) {
        final isLoading = state is OnboardingLoading;
        return OnboardingScaffold(
          ctaLabel:     l10n.legal_button_continue,
          onCta:        _advance,
          isCtaEnabled: _canProceed,
          isCtaLoading: isLoading,
          onCtaDisabledTap: _showValidation,
          skipLabel:    l10n.about_button_later,
          onSkip:       () => context.read<OnboardingCubit>().skipStep(),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppDimensions.space32),
              StepHeader(
                title:    isGuardian ? l10n.family_title_guardian : l10n.family_title_self,
                subtitle: isGuardian
                    ? l10n.family_subtitle_guardian(getRelationString())
                    : l10n.family_subtitle_self,
              ),
              const SizedBox(height: AppDimensions.space32),

              // Family type
              _Label(l10n.family_label_type),
              const SizedBox(height: AppDimensions.space12),
              Row(children: [
                _FamilyTypeCard(
                  icon: Icons.home_outlined, label: l10n.family_type_nuclear,
                  isSelected: _familyType == FamilyType.nuclear,
                  onTap: () => setState(() => _familyType = FamilyType.nuclear),
                ),
                const SizedBox(width: AppDimensions.space8),
                _FamilyTypeCard(
                  icon: Icons.people_outline_rounded, label: l10n.family_type_joint,
                  isSelected: _familyType == FamilyType.joint,
                  onTap: () => setState(() => _familyType = FamilyType.joint),
                ),
                const SizedBox(width: AppDimensions.space8),
                _FamilyTypeCard(
                  icon: Icons.groups_outlined, label: l10n.family_type_extended,
                  isSelected: _familyType == FamilyType.extended,
                  onTap: () => setState(() => _familyType = FamilyType.extended),
                ),
              ]),

              const SizedBox(height: AppDimensions.space24),

              // Siblings
              _Label(l10n.family_label_siblings),
              const SizedBox(height: AppDimensions.space12),
              _Stepper(value: _siblings, min: 0, max: 15, onChanged: (v) => setState(() => _siblings = v)),

              const SizedBox(height: AppDimensions.space24),

              // Parents status
              _Label(l10n.family_label_parents),
              const SizedBox(height: AppDimensions.space12),
              Wrap(
                spacing: AppDimensions.space8,
                runSpacing: AppDimensions.space8,
                children: _kParentsStatuses.map((s) {
                  final isSel = _parentsStatus == s;
                  return GestureDetector(
                    onTap: () => setState(() => _parentsStatus = s),
                    child: AnimatedContainer(
                      duration: AppDimensions.durationTransition,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppDimensions.space14, vertical: AppDimensions.space8,
                      ),
                      decoration: BoxDecoration(
                        color: isSel ? AppColors.champagneGold.withValues(alpha: 0.1) : AppColors.surfaceGlass,
                        borderRadius: BorderRadius.circular(AppDimensions.radiusChip),
                        border: Border.all(
                          color: isSel ? AppColors.champagneGold : AppColors.cardBorder,
                          width: isSel ? AppDimensions.borderFocus : AppDimensions.borderThin,
                        ),
                      ),
                      child: Text(getParentsStatusLabel(s), style: AppTypography.chipLabel.copyWith(
                        color: isSel ? AppColors.champagneGold : AppColors.pearlWhite,
                      )),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: AppDimensions.space24),

              // Previously married
              _Label(l10n.family_label_prev_married),
              const SizedBox(height: AppDimensions.space8),
              _InlinePills(
                options: const ['No', 'Divorced', 'Widowed'],
                selected: _marital == MaritalStatus.neverMarried ? 'No'
                    : _marital == MaritalStatus.divorced ? 'Divorced' : 'Widowed',
                labelBuilder: (v) {
                  switch (v) {
                    case 'No': return l10n.family_prev_no;
                    case 'Divorced': return l10n.family_prev_divorced;
                    case 'Widowed': return l10n.family_prev_widowed;
                    default: return v;
                  }
                },
                onSelected: (v) => setState(() {
                  _marital       = v == 'No' ? MaritalStatus.neverMarried
                                 : v == 'Divorced' ? MaritalStatus.divorced
                                 : MaritalStatus.widowed;
                  _hasChildren   = null;
                  _childrenCount = 0;
                }),
              ),

              // Children (if previously married)
              if (_marital != MaritalStatus.neverMarried) ...[
                const SizedBox(height: AppDimensions.space20),
                _Label(isGuardian ? l10n.family_label_children_guardian : l10n.family_label_children_self),
                const SizedBox(height: AppDimensions.space8),
                _InlinePills(
                  options: const ['Yes', 'No'],
                  selected: _hasChildren == null ? null : (_hasChildren! ? 'Yes' : 'No'),
                  labelBuilder: (v) {
                    switch (v) {
                      case 'Yes': return l10n.family_children_yes;
                      case 'No': return l10n.family_children_no;
                      default: return v;
                    }
                  },
                  onSelected: (v) => setState(() { _hasChildren = v == 'Yes'; }),
                ),
                if (_hasChildren == true) ...[
                  const SizedBox(height: AppDimensions.space16),
                  _Label(l10n.family_label_how_many),
                  const SizedBox(height: AppDimensions.space8),
                  _Stepper(
                    value: _childrenCount, min: 1, max: 10,
                    onChanged: (v) => setState(() => _childrenCount = v),
                  ),
                ],
              ],

              // ── POST-MARRIAGE LIVING (Phase 2) ─────────────
              const SizedBox(height: AppDimensions.space28),
              _Label(l10n.family_living_title),
              const SizedBox(height: AppDimensions.space4),
              Text(
                isGuardian
                    ? l10n.family_relocate_subtitle_guardian(getRelationString())
                    : l10n.family_relocate_subtitle_self,
                style: AppTypography.caption,
              ),
              const SizedBox(height: AppDimensions.space12),
              ..._kLivingOptions.map((opt) {
                final labels = getLivingLabels(opt.value);
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppDimensions.space8),
                  child: _LivingCard(
                    title:      labels.$1,
                    subtitle:   labels.$2,
                    value:      opt.value,
                    isSelected: _livingExpectation == opt.value,
                    onTap:      () => setState(() => _livingExpectation = opt.value),
                  ),
                );
              }),

              // ── WILLING TO RELOCATE (Phase 5.3) ────────────
              const SizedBox(height: AppDimensions.space28),
              _Label(l10n.family_label_relocate),
              const SizedBox(height: AppDimensions.space4),
              Text(
                isGuardian
                    ? l10n.family_relocate_subtitle_guardian(getRelationString())
                    : l10n.family_relocate_subtitle_self,
                style: AppTypography.caption,
              ),
              const SizedBox(height: AppDimensions.space12),
              Wrap(
                spacing: AppDimensions.space8,
                runSpacing: AppDimensions.space8,
                children: {
                  'yes': 'Yes',
                  'no': 'No',
                  'open_to_discussion': 'Open to Discussion',
                }.entries.map((e) {
                  final isSel = _willingToRelocate == e.key;
                  return GestureDetector(
                    onTap: () => setState(() => _willingToRelocate = e.key),
                    child: AnimatedContainer(
                      duration: AppDimensions.durationTransition,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppDimensions.space16,
                        vertical:   AppDimensions.space10,
                      ),
                      decoration: BoxDecoration(
                        color: isSel
                            ? AppColors.champagneGold.withValues(alpha: 0.12)
                            : AppColors.surfaceGlass,
                        borderRadius: BorderRadius.circular(AppDimensions.radiusChip),
                        border: Border.all(
                          color: isSel ? AppColors.champagneGold : AppColors.cardBorder,
                          width: isSel ? AppDimensions.borderFocus : AppDimensions.borderThin,
                        ),
                      ),
                      child: Text(getWillingToRelocateLabel(e.key), style: AppTypography.chipLabel.copyWith(
                        color: isSel ? AppColors.champagneGold : AppColors.pearlWhite,
                      )),
                    ),
                  );
                }).toList(),
              ),

              // ── POLYGAMY (Optional, gender-specific) ───────
              if (_gender == Gender.male) ...[
                const SizedBox(height: AppDimensions.space28),
                _Label(l10n.family_label_polygamy_male_self),
                const SizedBox(height: AppDimensions.space4),
                Text(
                  isGuardian
                      ? l10n.family_polygamy_male_sub_guardian(getRelationString())
                      : l10n.family_polygamy_male_sub_self,
                  style: AppTypography.caption,
                ),
                const SizedBox(height: AppDimensions.space12),
                _InlinePills(
                  options: const ['No, this is my first', 'Yes, currently married', 'Prefer not to say'],
                  selected: _polygamyStatus,
                  labelBuilder: (v) {
                    switch (v) {
                      case 'No, this is my first': return l10n.family_polygamy_option_first;
                      case 'Yes, currently married': return l10n.family_polygamy_option_married;
                      case 'Prefer not to say': return l10n.family_polygamy_option_prefer_not;
                      default: return v;
                    }
                  },
                  onSelected: (v) => setState(() => _polygamyStatus = v),
                ),
              ],
              if (_gender == Gender.female) ...[
                const SizedBox(height: AppDimensions.space28),
                _Label(l10n.family_label_polygamy_female_self),
                const SizedBox(height: AppDimensions.space4),
                Text(
                  isGuardian
                      ? l10n.family_polygamy_female_sub_guardian(getRelationString())
                      : l10n.family_polygamy_female_sub_self,
                  style: AppTypography.caption,
                ),
                const SizedBox(height: AppDimensions.space12),
                _InlinePills(
                  options: const ['Yes', 'No', 'Open to discussion', 'Prefer not to say'],
                  selected: _polygamyAcceptance,
                  labelBuilder: (v) {
                    switch (v) {
                      case 'Yes': return l10n.family_polygamy_female_yes;
                      case 'No': return l10n.family_polygamy_female_no;
                      case 'Open to discussion': return l10n.family_polygamy_female_discussion;
                      case 'Prefer not to say': return l10n.family_polygamy_female_prefer_not;
                      default: return v;
                    }
                  },
                  onSelected: (v) => setState(() => _polygamyAcceptance = v),
                ),
              ],

              const SizedBox(height: AppDimensions.space32),
            ],
          ),
        );
      },
    );
  }
}

// ── Living expectation card ───────────────────────────────────

class _LivingCard extends StatelessWidget {
  const _LivingCard({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.isSelected,
    required this.onTap,
  });
  final String title;
  final String subtitle;
  final String value;
  final bool   isSelected;
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
        child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: AppTypography.bodyMedium.copyWith(
              color: isSelected ? AppColors.champagneGold : AppColors.pearlWhite,
            )),
            const SizedBox(height: AppDimensions.space4),
            Text(subtitle, style: AppTypography.caption),
          ])),
          if (isSelected)
            Container(
              width: 20, height: 20,
              decoration: const BoxDecoration(color: AppColors.champagneGold, shape: BoxShape.circle),
              child: const Icon(Icons.check_rounded, color: AppColors.obsidianNight, size: 14),
            ),
        ]),
      ),
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

class _FamilyTypeCard extends StatelessWidget {
  const _FamilyTypeCard({required this.icon, required this.label, required this.isSelected, required this.onTap});
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: AppDimensions.durationTransition,
          padding: const EdgeInsets.symmetric(vertical: AppDimensions.space16),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.champagneGold.withValues(alpha: 0.08) : AppColors.surfaceGlass,
            borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
            border: Border.all(
              color: isSelected ? AppColors.champagneGold : AppColors.cardBorder,
              width: isSelected ? AppDimensions.borderFocus : AppDimensions.borderThin,
            ),
          ),
          child: Column(children: [
            Icon(icon, color: isSelected ? AppColors.champagneGold : AppColors.slateMist, size: AppDimensions.iconSizeLarge),
            const SizedBox(height: AppDimensions.space6),
            Text(label, style: AppTypography.caption.copyWith(color: isSelected ? AppColors.champagneGold : AppColors.pearlWhite)),
          ]),
        ),
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({required this.value, required this.min, required this.max, required this.onChanged});
  final int value, min, max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      decoration: BoxDecoration(color: AppColors.surfaceGlass, borderRadius: BorderRadius.circular(AppDimensions.radiusButton), border: Border.all(color: AppColors.cardBorder)),
      child: Row(children: [
        _StepperBtn(icon: Icons.remove_rounded, onTap: value > min ? () => onChanged(value - 1) : null),
        Expanded(child: Center(child: Text('$value', style: AppTypography.userName.copyWith(fontSize: 20)))),
        _StepperBtn(icon: Icons.add_rounded, onTap: value < max ? () => onChanged(value + 1) : null),
      ]),
    );
  }
}

class _StepperBtn extends StatelessWidget {
  const _StepperBtn({required this.icon, this.onTap});
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(width: 52, height: 52, child: Icon(icon, color: onTap != null ? AppColors.champagneGold : AppColors.slateMist, size: AppDimensions.iconSizeLarge)),
    );
  }
}

class _InlinePills extends StatelessWidget {
  const _InlinePills({
    required this.options,
    required this.selected,
    required this.onSelected,
    this.labelBuilder,
  });
  final List<String> options;
  final String? selected;
  final ValueChanged<String> onSelected;
  final String Function(String)? labelBuilder;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppDimensions.space8,
      children: options.map((o) {
        final isSel = selected == o;
        final displayLabel = labelBuilder != null ? labelBuilder!(o) : o;
        return GestureDetector(
          onTap: () => onSelected(o),
          child: AnimatedContainer(
            duration: AppDimensions.durationTransition,
            padding: const EdgeInsets.symmetric(horizontal: AppDimensions.space16, vertical: AppDimensions.space10),
            decoration: BoxDecoration(
              color: isSel ? AppColors.champagneGold.withValues(alpha: 0.12) : AppColors.surfaceGlass,
              borderRadius: BorderRadius.circular(AppDimensions.radiusChip),
              border: Border.all(color: isSel ? AppColors.champagneGold : AppColors.cardBorder, width: isSel ? AppDimensions.borderFocus : AppDimensions.borderThin),
            ),
            child: Text(displayLabel, style: AppTypography.chipLabel.copyWith(color: isSel ? AppColors.champagneGold : AppColors.pearlWhite)),
          ),
        );
      }).toList(),
    );
  }
}
