// lib/features/onboarding/screens/family_screen.dart
// ============================================================
// NOOR — Family Background Screen (Onboarding Step 5)
// Family type, sibling count, parents status, marital history.
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

const _kParentsStatuses = [
  'Together', 'Separated', 'Divorced',
  'Father deceased', 'Mother deceased', 'Both deceased',
];

class FamilyScreen extends StatefulWidget {
  const FamilyScreen({super.key});

  @override
  State<FamilyScreen> createState() => _FamilyScreenState();
}

class _FamilyScreenState extends State<FamilyScreen> {
  FamilyType?    _familyType;
  int            _siblings       = 0;
  bool?          _isEldest;
  String?        _parentsStatus;
  MaritalStatus  _marital        = MaritalStatus.neverMarried;
  bool?          _hasChildren;
  int            _childrenCount  = 0;

  bool get _canProceed =>
      _familyType != null && _parentsStatus != null;

  void _advance() {
    final data = context.read<OnboardingCubit>().currentData.copyWith(
      familyType:    _familyType,
      siblingCount:  _siblings,
      isEldestChild: _isEldest,
      parentsStatus: _parentsStatus,
      maritalStatus: _marital,
      hasChildren:   _hasChildren,
      childrenCount: _hasChildren == true ? _childrenCount : 0,
    );
    context.read<OnboardingCubit>().saveAndAdvance(data);
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<OnboardingCubit, OnboardingState>(
      builder: (context, state) {
        final isLoading = state is OnboardingLoading;
        return OnboardingScaffold(
          step:         5,
          ctaLabel:     'Continue',
          onCta:        _advance,
          isCtaEnabled: _canProceed,
          isCtaLoading: isLoading,
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppDimensions.space32),
              const StepHeader(
                title:    'Family background',
                subtitle: 'Family compatibility is central to lasting marriages.',
              ),
              const SizedBox(height: AppDimensions.space32),

              // Family type
              _Label('FAMILY TYPE'),
              const SizedBox(height: AppDimensions.space12),
              Row(children: [
                _FamilyTypeCard(
                  icon:       Icons.home_outlined,
                  label:      'Nuclear',
                  isSelected: _familyType == FamilyType.nuclear,
                  onTap:      () => setState(() => _familyType = FamilyType.nuclear),
                ),
                const SizedBox(width: AppDimensions.space8),
                _FamilyTypeCard(
                  icon:       Icons.people_outline_rounded,
                  label:      'Joint',
                  isSelected: _familyType == FamilyType.joint,
                  onTap:      () => setState(() => _familyType = FamilyType.joint),
                ),
                const SizedBox(width: AppDimensions.space8),
                _FamilyTypeCard(
                  icon:       Icons.groups_outlined,
                  label:      'Extended',
                  isSelected: _familyType == FamilyType.extended,
                  onTap:      () => setState(() => _familyType = FamilyType.extended),
                ),
              ]),

              const SizedBox(height: AppDimensions.space24),

              // Siblings
              _Label('NUMBER OF SIBLINGS'),
              const SizedBox(height: AppDimensions.space12),
              _Stepper(
                value:     _siblings,
                min:       0,
                max:       15,
                onChanged: (v) => setState(() => _siblings = v),
              ),

              const SizedBox(height: AppDimensions.space20),

              // Eldest child
              _Label('ARE YOU THE ELDEST CHILD?'),
              const SizedBox(height: AppDimensions.space8),
              _InlinePills(
                options: const ['Yes', 'No'],
                selected: _isEldest == null ? null
                    : (_isEldest! ? 'Yes' : 'No'),
                onSelected: (v) => setState(() => _isEldest = v == 'Yes'),
              ),

              const SizedBox(height: AppDimensions.space20),

              // Parents status
              _Label('PARENTS\' MARITAL STATUS'),
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
                        horizontal: AppDimensions.space14,
                        vertical:   AppDimensions.space8,
                      ),
                      decoration: BoxDecoration(
                        color: isSel
                            ? AppColors.champagneGold.withValues(alpha: 0.1)
                            : AppColors.surfaceGlass,
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
              _Label('PREVIOUSLY MARRIED?'),
              const SizedBox(height: AppDimensions.space8),
              _InlinePills(
                options: const ['No', 'Divorced', 'Widowed'],
                selected: _marital == MaritalStatus.neverMarried ? 'No'
                    : _marital == MaritalStatus.divorced ? 'Divorced' : 'Widowed',
                onSelected: (v) => setState(() {
                  _marital      = v == 'No' ? MaritalStatus.neverMarried
                                : v == 'Divorced' ? MaritalStatus.divorced
                                : MaritalStatus.widowed;
                  _hasChildren  = null;
                  _childrenCount = 0;
                }),
              ),

              // Children (if previously married)
              if (_marital != MaritalStatus.neverMarried) ...[
                const SizedBox(height: AppDimensions.space20),
                _Label('DO YOU HAVE CHILDREN?'),
                const SizedBox(height: AppDimensions.space8),
                _InlinePills(
                  options: const ['Yes', 'No'],
                  selected: _hasChildren == null ? null
                      : (_hasChildren! ? 'Yes' : 'No'),
                  onSelected: (v) => setState(() {
                    _hasChildren = v == 'Yes';
                  }),
                ),
                if (_hasChildren == true) ...[
                  const SizedBox(height: AppDimensions.space16),
                  _Label('HOW MANY?'),
                  const SizedBox(height: AppDimensions.space8),
                  _Stepper(
                    value:     _childrenCount,
                    min:       1,
                    max:       10,
                    onChanged: (v) => setState(() => _childrenCount = v),
                  ),
                ],
              ],

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

class _FamilyTypeCard extends StatelessWidget {
  const _FamilyTypeCard({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });
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
            color: isSelected
                ? AppColors.champagneGold.withValues(alpha: 0.08)
                : AppColors.surfaceGlass,
            borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
            border: Border.all(
              color: isSelected ? AppColors.champagneGold : AppColors.cardBorder,
              width: isSelected ? AppDimensions.borderFocus : AppDimensions.borderThin,
            ),
          ),
          child: Column(
            children: [
              Icon(icon,
                  color: isSelected ? AppColors.champagneGold : AppColors.slateMist,
                  size: AppDimensions.iconSizeLarge),
              const SizedBox(height: AppDimensions.space6),
              Text(label, style: AppTypography.caption.copyWith(
                color: isSelected ? AppColors.champagneGold : AppColors.pearlWhite,
              )),
            ],
          ),
        ),
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color:        AppColors.surfaceGlass,
        borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
        border:       Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          _StepperBtn(
            icon:    Icons.remove_rounded,
            onTap:   value > min ? () => onChanged(value - 1) : null,
          ),
          Expanded(
            child: Center(
              child: Text('$value', style: AppTypography.userName.copyWith(
                fontSize: 20,
              )),
            ),
          ),
          _StepperBtn(
            icon:    Icons.add_rounded,
            onTap:   value < max ? () => onChanged(value + 1) : null,
          ),
        ],
      ),
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
      child: Container(
        width: 52, height: 52,
        child: Icon(
          icon,
          color: onTap != null ? AppColors.champagneGold : AppColors.slateMist,
          size: AppDimensions.iconSizeLarge,
        ),
      ),
    );
  }
}

class _InlinePills extends StatelessWidget {
  const _InlinePills({
    required this.options,
    required this.selected,
    required this.onSelected,
  });
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
            child: Text(o, style: AppTypography.chipLabel.copyWith(
              color: isSel ? AppColors.champagneGold : AppColors.pearlWhite,
            )),
          ),
        );
      }).toList(),
    );
  }
}


