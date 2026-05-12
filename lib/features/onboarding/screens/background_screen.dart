// lib/features/onboarding/screens/background_screen.dart
// ============================================================
// NOOR — Background & Education Screen (Onboarding Step 3)
// Education level (7 ranks), field of study, profession,
// employment status, income bracket (optional).
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/cubits/onboarding/onboarding_cubit.dart';
import '../../../core/cubits/onboarding/onboarding_state.dart';
import '../../../core/models/onboarding_data.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/inputs/noor_text_field.dart';
import '../widgets/onboarding_scaffold.dart';
import '../widgets/step_header.dart';

// ── Education rank data ───────────────────────────────────────
class _EduLevel {
  const _EduLevel(this.rank, this.label);
  final int rank;
  final String label;
}

const _kEduLevels = <_EduLevel>[
  _EduLevel(1, 'Below Secondary'),
  _EduLevel(2, 'Secondary / O-Level'),
  _EduLevel(3, 'Higher Secondary / A-Level'),
  _EduLevel(4, 'Diploma / Associate'),
  _EduLevel(5, 'Bachelor\'s Degree'),
  _EduLevel(6, 'Master\'s Degree'),
  _EduLevel(7, 'Doctorate / PhD'),
];

const _kEmploymentOptions = [
  (value: EmploymentStatus.employed,      label: 'Employed'),
  (value: EmploymentStatus.selfEmployed,  label: 'Self-employed'),
  (value: EmploymentStatus.student,       label: 'Student'),
  (value: EmploymentStatus.notWorking,    label: 'Not working'),
];

// ── Income brackets (merged from income_screen) ───────────────
class _IncomeBracket {
  const _IncomeBracket(this.id, this.label);
  final String id;
  final String label;
}

const _kIncomeBrackets = <_IncomeBracket>[
  _IncomeBracket('in_1', '< \u20B93 Lakh/year'),
  _IncomeBracket('in_2', '\u20B93 \u2013 6 Lakh/year'),
  _IncomeBracket('in_3', '\u20B96 \u2013 12 Lakh/year'),
  _IncomeBracket('in_4', '\u20B912 \u2013 25 Lakh/year'),
  _IncomeBracket('in_5', '> \u20B925 Lakh/year'),
];

const _kVisibilityOptions = [
  (id: 'hidden',      label: 'Keep private'),
  (id: 'bracket',     label: 'Show bracket to everyone'),
  (id: 'after_match', label: 'Show only after mutual interest'),
];

class BackgroundScreen extends StatefulWidget {
  const BackgroundScreen({super.key});

  @override
  State<BackgroundScreen> createState() => _BackgroundScreenState();
}

class _BackgroundScreenState extends State<BackgroundScreen> {
  _EduLevel?       _education;
  final _studyCtrl      = TextEditingController();
  final _professionCtrl = TextEditingController();
  EmploymentStatus? _employment;
  _IncomeBracket? _incomeBracket;
  String _incomeVisibility = 'bracket';
  bool _showIncome = false;

  bool get _canProceed =>
      _education != null && _employment != null;

  @override
  void dispose() {
    _studyCtrl.dispose();
    _professionCtrl.dispose();
    super.dispose();
  }

  void _advance() {
    final data = context.read<OnboardingCubit>().currentData.copyWith(
      educationRank:   _education?.rank,
      educationLabel:  _education?.label,
      fieldOfStudy:    _studyCtrl.text.trim().isNotEmpty
                           ? _studyCtrl.text.trim()
                           : null,
      profession:      _professionCtrl.text.trim().isNotEmpty
                           ? _professionCtrl.text.trim()
                           : null,
      employmentStatus: _employment,
      incomeBracketId:    _incomeBracket?.id,
      incomeBracketLabel: _incomeBracket?.label,
      incomeVisibility:   _incomeVisibility,
    );
    context.read<OnboardingCubit>().saveAndAdvance(data);
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<OnboardingCubit, OnboardingState>(
      builder: (context, state) {
        final isLoading = state is OnboardingLoading;
        return OnboardingScaffold(
          step:         4,
          ctaLabel:     'Continue',
          onCta:        _advance,
          isCtaEnabled: _canProceed,
          isCtaLoading: isLoading,
          skipLabel:    'I\'ll do this later',
          onSkip:       () => context.read<OnboardingCubit>().skipStep(),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppDimensions.space32),
              const StepHeader(
                title:    'Your background',
                subtitle: 'Helps find professionally compatible matches.',
              ),
              const SizedBox(height: AppDimensions.space32),

              // Education level
              Text('EDUCATION LEVEL', style: AppTypography.sectionLabel),
              const SizedBox(height: AppDimensions.space12),
              ..._kEduLevels.map((edu) => Padding(
                padding: const EdgeInsets.only(bottom: AppDimensions.space8),
                child: _EduTile(
                  edu:        edu,
                  isSelected: _education?.rank == edu.rank,
                  onTap:      () => setState(() => _education = edu),
                ),
              )),

              const SizedBox(height: AppDimensions.space20),

              // Field of study
              NoorTextField(
                controller:         _studyCtrl,
                label:              'Field of study  (Optional)',
                prefixIcon:         Icons.school_outlined,
                textCapitalization: TextCapitalization.sentences,
                textInputAction:    TextInputAction.next,
              ),

              const SizedBox(height: AppDimensions.space16),

              // Profession
              NoorTextField(
                controller:         _professionCtrl,
                label:              'Profession  (Optional)',
                prefixIcon:         Icons.work_outline_rounded,
                textCapitalization: TextCapitalization.words,
                textInputAction:    TextInputAction.done,
              ),

              const SizedBox(height: AppDimensions.space20),

              // Employment status
              Text('EMPLOYMENT STATUS', style: AppTypography.sectionLabel),
              const SizedBox(height: AppDimensions.space12),
              Wrap(
                spacing:    AppDimensions.space8,
                runSpacing: AppDimensions.space8,
                children: _kEmploymentOptions.map((opt) {
                  final isSel = _employment == opt.value;
                  return GestureDetector(
                    onTap: () => setState(() => _employment = opt.value),
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
                          color: isSel
                              ? AppColors.champagneGold
                              : AppColors.cardBorder,
                          width: isSel
                              ? AppDimensions.borderFocus
                              : AppDimensions.borderThin,
                        ),
                      ),
                      child: Text(
                        opt.label,
                        style: AppTypography.chipLabel.copyWith(
                          color: isSel
                              ? AppColors.champagneGold
                              : AppColors.pearlWhite,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: AppDimensions.space28),

              // ── INCOME (Optional, collapsible) ───────────────
              GestureDetector(
                onTap: () => setState(() => _showIncome = !_showIncome),
                child: Container(
                  padding: const EdgeInsets.all(AppDimensions.space16),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceGlass,
                    borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
                    border: Border.all(color: AppColors.cardBorder),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.account_balance_wallet_outlined,
                          color: AppColors.slateMist, size: 20),
                      const SizedBox(width: AppDimensions.space12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('INCOME RANGE  (Optional)',
                                style: AppTypography.sectionLabel),
                            const SizedBox(height: 2),
                            Text('Many people skip this — it\'s entirely optional.',
                                style: AppTypography.caption),
                          ],
                        ),
                      ),
                      Icon(
                        _showIncome
                            ? Icons.expand_less_rounded
                            : Icons.expand_more_rounded,
                        color: AppColors.slateMist,
                      ),
                    ],
                  ),
                ),
              ),

              if (_showIncome) ...[
                const SizedBox(height: AppDimensions.space16),
                Text('INCOME BRACKET (INR)', style: AppTypography.sectionLabel),
                const SizedBox(height: AppDimensions.space12),
                ..._kIncomeBrackets.map((b) => Padding(
                  padding: const EdgeInsets.only(bottom: AppDimensions.space8),
                  child: GestureDetector(
                    onTap: () => setState(() =>
                        _incomeBracket = _incomeBracket?.id == b.id ? null : b),
                    child: AnimatedContainer(
                      duration: AppDimensions.durationTransition,
                      padding: const EdgeInsets.all(AppDimensions.space16),
                      decoration: BoxDecoration(
                        color: _incomeBracket?.id == b.id
                            ? AppColors.champagneGold.withValues(alpha: 0.08)
                            : AppColors.surfaceGlass,
                        borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
                        border: Border.all(
                          color: _incomeBracket?.id == b.id
                              ? AppColors.champagneGold
                              : AppColors.cardBorder,
                          width: _incomeBracket?.id == b.id
                              ? AppDimensions.borderFocus
                              : AppDimensions.borderThin,
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(b.label, style: AppTypography.body),
                          ),
                          if (_incomeBracket?.id == b.id)
                            const Icon(Icons.check_rounded,
                                color: AppColors.champagneGold, size: 20),
                        ],
                      ),
                    ),
                  ),
                )),
                const SizedBox(height: AppDimensions.space16),
                Text('WHO CAN SEE THIS?', style: AppTypography.sectionLabel),
                const SizedBox(height: AppDimensions.space12),
                ..._kVisibilityOptions.map((opt) => Padding(
                  padding: const EdgeInsets.only(bottom: AppDimensions.space8),
                  child: GestureDetector(
                    onTap: () => setState(() => _incomeVisibility = opt.id),
                    child: AnimatedContainer(
                      duration: AppDimensions.durationTransition,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppDimensions.space16,
                        vertical:   AppDimensions.space12,
                      ),
                      decoration: BoxDecoration(
                        color: _incomeVisibility == opt.id
                            ? AppColors.surfaceGlassHover
                            : AppColors.surfaceGlass,
                        borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
                        border: Border.all(
                          color: _incomeVisibility == opt.id
                              ? AppColors.champagneGold
                              : AppColors.cardBorder,
                          width: _incomeVisibility == opt.id
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
                              color: _incomeVisibility == opt.id
                                  ? AppColors.champagneGold
                                  : AppColors.transparent,
                              border: Border.all(
                                color: _incomeVisibility == opt.id
                                    ? AppColors.champagneGold
                                    : AppColors.slateMist,
                              ),
                            ),
                            child: _incomeVisibility == opt.id
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
              ],

              const SizedBox(height: AppDimensions.space32),
            ],
          ),
        );
      },
    );
  }
}

// ── Education tile ────────────────────────────────────────────

class _EduTile extends StatelessWidget {
  const _EduTile({
    required this.edu,
    required this.isSelected,
    required this.onTap,
  });
  final _EduLevel edu;
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
          vertical:   AppDimensions.space14,
        ),
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
            Container(
              width: 28, height: 28,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.champagneGold
                    : AppColors.surfaceGlassHover,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '${edu.rank}',
                  style: TextStyle(
                    fontSize:   12,
                    fontWeight: FontWeight.w700,
                    color: isSelected
                        ? AppColors.obsidianNight
                        : AppColors.slateMist,
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppDimensions.space12),
            Text(
              edu.label,
              style: AppTypography.body.copyWith(
                color: isSelected ? AppColors.champagneGold : AppColors.pearlWhite,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
