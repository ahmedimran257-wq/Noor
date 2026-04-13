// lib/features/onboarding/screens/background_screen.dart
// ============================================================
// NOOR — Background & Education Screen (Onboarding Step 3)
// Education level (7 ranks), field of study, profession, employment status.
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
    );
    context.read<OnboardingCubit>().saveAndAdvance(data);
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<OnboardingCubit, OnboardingState>(
      builder: (context, state) {
        final isLoading = state is OnboardingLoading;
        return OnboardingScaffold(
          step:         3,
          ctaLabel:     'Continue',
          onCta:        _advance,
          isCtaEnabled: _canProceed,
          isCtaLoading: isLoading,
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
