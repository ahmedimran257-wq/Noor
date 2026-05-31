// lib/features/onboarding/screens/family_screen.dart
// ============================================================
// NOOR — Family Background Screen (Onboarding Step 5)
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
    final missing = <String>[];
    if (_familyType == null) missing.add('Family type');
    if (_parentsStatus == null) missing.add('Parents\' marital status');
    if (_livingExpectation == null) missing.add('Post-marriage living expectations');
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
    final obData = context.read<OnboardingCubit>().currentData;
    final isGuardian = obData.isGuardianMode;
    final relation = obData.profileCreatorRelation ?? 'ward';
    return BlocBuilder<OnboardingCubit, OnboardingState>(
      builder: (context, state) {
        final isLoading = state is OnboardingLoading;
        return OnboardingScaffold(
          ctaLabel:     'Continue',
          onCta:        _advance,
          isCtaEnabled: _canProceed,
          isCtaLoading: isLoading,
          onCtaDisabledTap: _showValidation,
          skipLabel:    'I\'ll do this later',
          onSkip:       () => context.read<OnboardingCubit>().skipStep(),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppDimensions.space32),
              StepHeader(
                title:    isGuardian ? 'Family background' : 'Family background',
                subtitle: isGuardian
                    ? 'Tell us about your $relation\'s family.'
                    : 'Family compatibility is central to lasting marriages.',
              ),
              const SizedBox(height: AppDimensions.space32),

              // Family type
              const _Label('FAMILY TYPE'),
              const SizedBox(height: AppDimensions.space12),
              Row(children: [
                _FamilyTypeCard(
                  icon: Icons.home_outlined, label: 'Nuclear',
                  isSelected: _familyType == FamilyType.nuclear,
                  onTap: () => setState(() => _familyType = FamilyType.nuclear),
                ),
                const SizedBox(width: AppDimensions.space8),
                _FamilyTypeCard(
                  icon: Icons.people_outline_rounded, label: 'Joint',
                  isSelected: _familyType == FamilyType.joint,
                  onTap: () => setState(() => _familyType = FamilyType.joint),
                ),
                const SizedBox(width: AppDimensions.space8),
                _FamilyTypeCard(
                  icon: Icons.groups_outlined, label: 'Extended',
                  isSelected: _familyType == FamilyType.extended,
                  onTap: () => setState(() => _familyType = FamilyType.extended),
                ),
              ]),

              const SizedBox(height: AppDimensions.space24),

              // Siblings
              const _Label('NUMBER OF SIBLINGS'),
              const SizedBox(height: AppDimensions.space12),
              _Stepper(value: _siblings, min: 0, max: 15, onChanged: (v) => setState(() => _siblings = v)),



              // Parents status
              const _Label('PARENTS\' MARITAL STATUS'),
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
                      child: Text(s, style: AppTypography.chipLabel.copyWith(
                        color: isSel ? AppColors.champagneGold : AppColors.pearlWhite,
                      )),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: AppDimensions.space24),

              // Previously married
              _Label(isGuardian ? 'PREVIOUSLY MARRIED?' : 'PREVIOUSLY MARRIED?'),
              const SizedBox(height: AppDimensions.space8),
              _InlinePills(
                options: const ['No', 'Divorced', 'Widowed'],
                selected: _marital == MaritalStatus.neverMarried ? 'No'
                    : _marital == MaritalStatus.divorced ? 'Divorced' : 'Widowed',
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
                _Label(isGuardian ? 'DO THEY HAVE CHILDREN?' : 'DO YOU HAVE CHILDREN?'),
                const SizedBox(height: AppDimensions.space8),
                _InlinePills(
                  options: const ['Yes', 'No'],
                  selected: _hasChildren == null ? null : (_hasChildren! ? 'Yes' : 'No'),
                  onSelected: (v) => setState(() { _hasChildren = v == 'Yes'; }),
                ),
                if (_hasChildren == true) ...[
                  const SizedBox(height: AppDimensions.space16),
                  const _Label('HOW MANY?'),
                  const SizedBox(height: AppDimensions.space8),
                  _Stepper(
                    value: _childrenCount, min: 1, max: 10,
                    onChanged: (v) => setState(() => _childrenCount = v),
                  ),
                ],
              ],

              // ── POST-MARRIAGE LIVING (Phase 2) ─────────────
              const SizedBox(height: AppDimensions.space28),
              const _Label('POST-MARRIAGE LIVING EXPECTATIONS'),
              const SizedBox(height: AppDimensions.space4),
              Text(
                isGuardian
                    ? 'Where does your $relation expect to live after marriage?'
                    : 'Where do you expect to live after marriage?',
                style: AppTypography.caption,
              ),
              const SizedBox(height: AppDimensions.space12),
              // TODO (backend): write livingExpectation to partner_preferences table.
              ..._kLivingOptions.map((opt) => Padding(
                padding: const EdgeInsets.only(bottom: AppDimensions.space8),
                child: _LivingCard(
                  title:      opt.title,
                  subtitle:   opt.subtitle,
                  value:      opt.value,
                  isSelected: _livingExpectation == opt.value,
                  onTap:      () => setState(() => _livingExpectation = opt.value),
                ),
              )),

              // ── WILLING TO RELOCATE (Phase 5.3) ────────────
              const SizedBox(height: AppDimensions.space28),
              const _Label('WILLING TO RELOCATE'),
              const SizedBox(height: AppDimensions.space4),
              Text(
                isGuardian
                    ? 'Would your $relation relocate for marriage?'
                    : 'Would you relocate for marriage?',
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
                        vertical: AppDimensions.space10,
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
                      child: Text(e.value, style: AppTypography.chipLabel.copyWith(
                        color: isSel ? AppColors.champagneGold : AppColors.pearlWhite,
                      )),
                    ),
                  );
                }).toList(),
              ),

              // ── POLYGAMY (Optional, gender-specific) ───────
              if (_gender == Gender.male) ...[
                const SizedBox(height: AppDimensions.space28),
                const _Label('POLYGAMY STATUS  (Optional)'),
                const SizedBox(height: AppDimensions.space4),
                Text(
                  isGuardian
                      ? 'Is your $relation currently married and looking for an additional spouse?'
                      : 'Are you currently married and looking for an additional spouse?',
                  style: AppTypography.caption,
                ),
                const SizedBox(height: AppDimensions.space12),
                _InlinePills(
                  options: const ['No, this is my first', 'Yes, currently married', 'Prefer not to say'],
                  selected: _polygamyStatus,
                  onSelected: (v) => setState(() => _polygamyStatus = v),
                ),
              ],
              if (_gender == Gender.female) ...[
                const SizedBox(height: AppDimensions.space28),
                const _Label('POLYGAMY ACCEPTANCE  (Optional)'),
                const SizedBox(height: AppDimensions.space4),
                Text(
                  isGuardian
                      ? 'Would your $relation consider being a co-wife?'
                      : 'Would you consider being a co-wife?',
                  style: AppTypography.caption,
                ),
                const SizedBox(height: AppDimensions.space12),
                _InlinePills(
                  options: const ['Yes', 'No', 'Open to discussion', 'Prefer not to say'],
                  selected: _polygamyAcceptance,
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
  const _InlinePills({required this.options, required this.selected, required this.onSelected});
  final List<String> options;
  final String? selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppDimensions.space8,
      children: options.map((o) {
        final isSel = selected == o;
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
            child: Text(o, style: AppTypography.chipLabel.copyWith(color: isSel ? AppColors.champagneGold : AppColors.pearlWhite)),
          ),
        );
      }).toList(),
    );
  }
}
