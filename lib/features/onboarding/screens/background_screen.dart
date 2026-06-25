// lib/features/onboarding/screens/background_screen.dart
// ============================================================
// MITHAQ — Background & Education Screen (Onboarding Step 3)
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
import '../../../core/widgets/inputs/mithaq_text_field.dart';
import '../../../core/utils/validation_snackbar.dart';
import '../../../core/data/country_income_brackets.dart';
import '../../../l10n/generated/app_localizations.dart';
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
  IncomeBracketData? _incomeBracket;
  String _incomeVisibility = 'bracket';
  bool _showIncome = false;
  List<IncomeBracketData> _incomeBrackets = [];
  bool _incomeHidden = false;

  @override
  void initState() {
    super.initState();
    final data = context.read<OnboardingCubit>().currentData;
    if (data.educationRank != null) {
      _education = _kEduLevels.firstWhere(
        (edu) => edu.rank == data.educationRank,
        orElse: () => _kEduLevels.first,
      );
    }
    _studyCtrl.text = data.fieldOfStudy ?? '';
    _professionCtrl.text = data.profession ?? '';
    _employment = data.employmentStatus;

    final countryCode = data.countryCode;
    final brackets = bracketsFor(countryCode);
    _incomeHidden = brackets == null;
    _incomeBrackets = brackets ?? [];

    if (data.incomeBracketId != null && !_incomeHidden) {
      _incomeBracket = _incomeBrackets.firstWhere(
        (inc) => inc.id == data.incomeBracketId,
        orElse: () => _incomeBrackets.first,
      );
    }
    _incomeVisibility = data.incomeVisibility ?? 'bracket';
    _showIncome = data.incomeBracketId != null && !_incomeHidden;
  }

  bool get _canProceed =>
      _education != null && _employment != null;

  void _showValidation() {
    final l10n = AppLocalizations.of(context);
    final missing = <String>[];
    if (_education == null) missing.add(l10n.background_label_eduLevel);
    if (_employment == null) missing.add(l10n.background_label_employment);
    showValidationSnackbar(context, missing);
  }

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

    String getEmploymentLabel(EmploymentStatus value) {
      switch (value) {
        case EmploymentStatus.employed:
          return l10n.background_emp_employed;
        case EmploymentStatus.selfEmployed:
          return l10n.background_emp_self_employed;
        case EmploymentStatus.student:
          return l10n.background_emp_student;
        case EmploymentStatus.notWorking:
          return l10n.background_emp_not_working;
      }
    }

    String getVisibilityLabel(String id) {
      switch (id) {
        case 'hidden':
          return l10n.background_vis_private;
        case 'bracket':
          return l10n.background_vis_everyone;
        case 'after_match':
          return l10n.background_vis_mutual;
        default:
          return '';
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
                title:    isGuardian ? l10n.background_edu_title_guardian : l10n.background_edu_title_self,
                subtitle: isGuardian
                    ? l10n.background_edu_subtitle_guardian(getRelationString())
                    : l10n.background_edu_subtitle_self,
              ),
              const SizedBox(height: AppDimensions.space32),

              // Education level
              Text(l10n.background_label_eduLevel, style: AppTypography.sectionLabel),
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
              MithaqTextField(
                controller:         _studyCtrl,
                label:              l10n.background_label_study,
                prefixIcon:         Icons.school_outlined,
                textCapitalization: TextCapitalization.sentences,
                textInputAction:    TextInputAction.next,
              ),

              const SizedBox(height: AppDimensions.space16),

              // Profession
              MithaqTextField(
                controller:         _professionCtrl,
                label:              l10n.background_label_profession,
                prefixIcon:         Icons.work_outline_rounded,
                textCapitalization: TextCapitalization.words,
                textInputAction:    TextInputAction.done,
              ),

              const SizedBox(height: AppDimensions.space20),

              // Employment status
              Text(l10n.background_label_employment, style: AppTypography.sectionLabel),
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
                        getEmploymentLabel(opt.value),
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
              if (!_incomeHidden) ...[
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
                              Text(l10n.background_label_income_range,
                                  style: AppTypography.sectionLabel),
                              const SizedBox(height: 2),
                              Text(l10n.background_income_subtitle,
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
                  Text(
                    l10n.background_label_income_bracket(currencyFor(context.read<OnboardingCubit>().currentData.countryCode)),
                    style: AppTypography.sectionLabel,
                  ),
                  const SizedBox(height: AppDimensions.space12),
                  ..._incomeBrackets.map((b) => Padding(
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
                Text(l10n.background_label_who_see, style: AppTypography.sectionLabel),
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
                          Text(getVisibilityLabel(opt.id), style: AppTypography.body),
                        ],
                      ),
                    ),
                  ),
                )),
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
    final l10n = AppLocalizations.of(context);
    String localizedLabel = '';
    switch (edu.rank) {
      case 1:
        localizedLabel = l10n.background_edu_below_secondary;
        break;
      case 2:
        localizedLabel = l10n.background_edu_secondary;
        break;
      case 3:
        localizedLabel = l10n.background_edu_higher_secondary;
        break;
      case 4:
        localizedLabel = l10n.background_edu_diploma;
        break;
      case 5:
        localizedLabel = l10n.background_edu_bachelors;
        break;
      case 6:
        localizedLabel = l10n.background_edu_masters;
        break;
      case 7:
        localizedLabel = l10n.background_edu_doctorate;
        break;
      default:
        localizedLabel = edu.label;
    }

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
              localizedLabel,
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
