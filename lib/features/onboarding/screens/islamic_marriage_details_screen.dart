// lib/features/onboarding/screens/islamic_marriage_details_screen.dart
// ============================================================
// MITHAQ — Marriage & Deen Details Screen
// Collects: quranMemorization, religiousEducation,
//           marriageTimeline,
//           + gender-specific: niqab/mahr/work (female),
//             mahr budget + provider readiness (male)
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mithaq/l10n/generated/app_localizations.dart';

import '../../../core/cubits/onboarding/onboarding_cubit.dart';
import '../../../core/cubits/onboarding/onboarding_state.dart';
import '../../../core/models/onboarding_data.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/validation_snackbar.dart';
import '../widgets/onboarding_scaffold.dart';
import '../widgets/step_header.dart';

class IslamicMarriageDetailsScreen extends StatefulWidget {
  const IslamicMarriageDetailsScreen({super.key});

  @override
  State<IslamicMarriageDetailsScreen> createState() =>
      _IslamicMarriageDetailsScreenState();
}

class _IslamicMarriageDetailsScreenState
    extends State<IslamicMarriageDetailsScreen> {
  String? _quranMemorization;
  String? _religiousEducation;
  String? _marriageTimeline;

  // Female-specific
  String? _niqabPreference;
  String? _mahrExpectation;
  bool?   _willingToWorkAfterMarriage;

  // Male-specific
  String? _mahrBudget;
  bool?   _canProvideHousing;
  bool?   _canProvideMaintenance;
  String? _debtStatus;

  @override
  void initState() {
    super.initState();
    final data = context.read<OnboardingCubit>().currentData;
    _quranMemorization = data.quranMemorization;
    _religiousEducation = data.religiousEducation;
    _marriageTimeline = data.marriageTimeline;
    _niqabPreference = data.niqabPreference;
    _mahrExpectation = data.mahrExpectation;
    _willingToWorkAfterMarriage = data.willingToWorkAfterMarriage;
    _mahrBudget = data.mahrBudget;
    _canProvideHousing = data.canProvideHousing;
    _canProvideMaintenance = data.canProvideMaintenance;
    _debtStatus = data.debtStatus;
  }

  bool get _isFemale =>
      context.read<OnboardingCubit>().currentData.gender == Gender.female;

  bool get _canProceed =>
      _marriageTimeline != null;

  void _showValidation() {
    final missing = <String>[];
    if (_marriageTimeline == null) missing.add('Marriage timeline');
    showValidationSnackbar(context, missing);
  }

  void _advance() {
    final data = context.read<OnboardingCubit>().currentData.copyWith(
      quranMemorization:         _quranMemorization,
      religiousEducation:        _religiousEducation,
      marriageTimeline:          _marriageTimeline,
      niqabPreference:           _isFemale ? _niqabPreference : null,
      mahrExpectation:           _isFemale ? _mahrExpectation : null,
      willingToWorkAfterMarriage: _isFemale ? _willingToWorkAfterMarriage : null,
      mahrBudget:                !_isFemale ? _mahrBudget : null,
      canProvideHousing:         !_isFemale ? _canProvideHousing : null,
      canProvideMaintenance:     !_isFemale ? _canProvideMaintenance : null,
      debtStatus:                !_isFemale ? _debtStatus : null,
    );
    context.read<OnboardingCubit>().saveAndAdvance(data);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return BlocBuilder<OnboardingCubit, OnboardingState>(
      builder: (context, state) {
        final isLoading = state is OnboardingLoading;
        return OnboardingScaffold(
          ctaLabel:     l10n.legal_button_continue,
          onCta:        _advance,
          isCtaEnabled: _canProceed,
          isCtaLoading: isLoading,
          onCtaDisabledTap: _showValidation,
          skipLabel:    l10n.common_button_skip,
          onSkip:       () => context.read<OnboardingCubit>().skipStep(),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppDimensions.space32),
              StepHeader(
                title:    l10n.onboarding_marriageDeen_title,
                subtitle: l10n.onboarding_marriageDeen_subtitle,
              ),
              const SizedBox(height: AppDimensions.space28),

              // ── Quran Memorization ────────────────────────────
              _buildSection(l10n.onboarding_label_quranMemorization.toUpperCase(), null),
              _buildChipRow(_quranMemorization, {
                'none':       l10n.onboarding_quran_none,
                'some_surahs': l10n.onboarding_quran_some,
                'partial':    l10n.onboarding_quran_partial,
                'hafiz':      l10n.onboarding_quran_hafiz,
              }, (v) => setState(() => _quranMemorization = v)),

              const SizedBox(height: AppDimensions.space24),

              // ── Religious Education ───────────────────────────
              _buildSection(l10n.onboarding_label_religiousEducation.toUpperCase(), null),
              _buildChipRow(_religiousEducation, {
                'self_taught':  l10n.onboarding_religiousEdu_selfTaught,
                'madrasa':      l10n.onboarding_religiousEdu_madrasa,
                'islamic_uni':  l10n.onboarding_religiousEdu_islamicUni,
                'alim_course':  l10n.onboarding_religiousEdu_alim,
                'none':         l10n.onboarding_quran_none,
              }, (v) => setState(() => _religiousEducation = v)),

              const SizedBox(height: AppDimensions.space24),

              // ── Marriage Timeline ─────────────────────────────
              _buildSection(l10n.onboarding_label_marriageTimeline.toUpperCase(), l10n.onboarding_label_marriageTimelineQuestion),
              _buildChipRow(_marriageTimeline, {
                'asap':          l10n.onboarding_timeline_asap,
                '6_months':      l10n.onboarding_timeline_6months,
                '1_year':        l10n.onboarding_timeline_1year,
                '2_plus_years':  l10n.onboarding_timeline_2years,
                'not_sure':      l10n.onboarding_timeline_notSure,
              }, (v) => setState(() => _marriageTimeline = v)),

              const SizedBox(height: AppDimensions.space24),

              // ── Gender-specific sections ──────────────────────
              if (_isFemale) ..._buildFemaleFields(l10n),
              if (!_isFemale) ..._buildMaleFields(l10n),

              const SizedBox(height: AppDimensions.space40),
            ],
          ),
        );
      },
    );
  }

  // ── Female-specific ─────────────────────────────────────────

  List<Widget> _buildFemaleFields(AppLocalizations l10n) => [
    _buildSection(l10n.onboarding_label_niqab.toUpperCase(), null),
    _buildChipRow(_niqabPreference, {
      'wears_niqab':       l10n.onboarding_niqab_wear,
      'open_to_niqab':     l10n.onboarding_niqab_open,
      'no_niqab':          l10n.onboarding_niqab_dontWear,
      'prefer_not_to_say': l10n.onboarding_label_preferNotToSay,
    }, (v) => setState(() => _niqabPreference = v)),
    const SizedBox(height: AppDimensions.space24),

    _buildSection(l10n.onboarding_label_mahrExpectation.toUpperCase(), l10n.onboarding_label_mahrExpectationQuestion),
    _buildChipRow(_mahrExpectation, {
      'no_preference': l10n.onboarding_mahr_noPreference,
      'modest':        l10n.onboarding_mahr_modest,
      'moderate':      l10n.onboarding_mahr_moderate,
      'high':          l10n.onboarding_mahr_generous,
      'to_discuss':    l10n.onboarding_mahr_toDiscuss,
    }, (v) => setState(() => _mahrExpectation = v)),
    const SizedBox(height: AppDimensions.space24),

    _buildSection(l10n.onboarding_label_workAfterMarriage.toUpperCase(), l10n.onboarding_label_workAfterMarriageQuestion),
    _buildChipRow(
      _willingToWorkAfterMarriage == null
          ? null
          : _willingToWorkAfterMarriage! ? 'yes' : 'no',
      {
        'yes': l10n.onboarding_work_yes,
        'no':  l10n.onboarding_work_no,
      },
      (v) => setState(() => _willingToWorkAfterMarriage = v == 'yes'),
    ),
    const SizedBox(height: AppDimensions.space24),
  ];

  // ── Male-specific ───────────────────────────────────────────

  List<Widget> _buildMaleFields(AppLocalizations l10n) => [
    _buildSection(l10n.onboarding_label_mahrBudget.toUpperCase(), l10n.onboarding_label_mahrBudgetQuestion),
    _buildChipRow(_mahrBudget, {
      'modest':    l10n.onboarding_mahr_modest,
      'moderate':  l10n.onboarding_mahr_moderate,
      'generous':  l10n.onboarding_mahr_generous,
      'to_discuss': l10n.onboarding_mahr_toDiscuss,
    }, (v) => setState(() => _mahrBudget = v)),
    const SizedBox(height: AppDimensions.space24),

    _buildSection(l10n.onboarding_label_providerReadiness.toUpperCase(), null),
    Container(
      padding: const EdgeInsets.all(AppDimensions.space16),
      decoration: BoxDecoration(
        color: AppColors.champagneGold.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
        border: Border.all(color: AppColors.goldBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.auto_awesome_outlined,
              color: AppColors.champagneGold, size: 18),
          const SizedBox(width: AppDimensions.space12),
          Expanded(
            child: Text(
              l10n.onboarding_providerQuote,
              style: AppTypography.caption.copyWith(height: 1.6),
            ),
          ),
        ],
      ),
    ),
    const SizedBox(height: AppDimensions.space16),

    _buildSection(l10n.onboarding_label_housing.toUpperCase(), l10n.onboarding_label_housingQuestion),
    _buildChipRow(
      _canProvideHousing == null ? null : (_canProvideHousing! ? 'yes' : 'no'),
      {'yes': l10n.localeName == 'ar' ? 'نعم' : 'Yes', 'no': l10n.localeName == 'ar' ? 'لا' : 'No'},
      (v) => setState(() => _canProvideHousing = v == 'yes'),
    ),
    const SizedBox(height: AppDimensions.space16),

    _buildSection(l10n.onboarding_label_maintenance.toUpperCase(), l10n.onboarding_label_maintenanceQuestion),
    _buildChipRow(
      _canProvideMaintenance == null ? null : (_canProvideMaintenance! ? 'yes' : 'no'),
      {'yes': l10n.localeName == 'ar' ? 'نعم' : 'Yes', 'no': l10n.localeName == 'ar' ? 'لا' : 'No'},
      (v) => setState(() => _canProvideMaintenance = v == 'yes'),
    ),
    const SizedBox(height: AppDimensions.space16),

    _buildSection(l10n.onboarding_label_debtStatus.toUpperCase(), l10n.onboarding_label_debtStatusQuestion),
    _buildChipRow(_debtStatus, {
      'no_debt':          l10n.onboarding_debt_none,
      'manageable':       l10n.onboarding_debt_manageable,
      'significant':      l10n.onboarding_debt_significant,
      'prefer_not_to_say': l10n.onboarding_label_preferNotToSay,
    }, (v) => setState(() => _debtStatus = v)),
    const SizedBox(height: AppDimensions.space16),

    // Privacy notice
    Container(
      padding: const EdgeInsets.all(AppDimensions.space16),
      decoration: BoxDecoration(
        color: AppColors.surfaceGlass,
        borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lock_outline_rounded,
              color: AppColors.slateMist, size: 16),
          const SizedBox(width: AppDimensions.space10),
          Expanded(
            child: Text(
              l10n.onboarding_marriageDeen_privacyNotice,
              style: AppTypography.caption.copyWith(height: 1.6),
            ),
          ),
        ],
      ),
    ),
    const SizedBox(height: AppDimensions.space24),
  ];

  // ── Helpers ─────────────────────────────────────────────────

  Widget _buildSection(String label, String? subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTypography.sectionLabel),
        if (subtitle != null) ...[
          const SizedBox(height: AppDimensions.space4),
          Text(subtitle, style: AppTypography.caption),
        ],
        const SizedBox(height: AppDimensions.space12),
      ],
    );
  }

  Widget _buildChipRow(
    String? selected,
    Map<String, String> options,
    ValueChanged<String> onSelected,
  ) {
    return Wrap(
      spacing:    AppDimensions.space8,
      runSpacing: AppDimensions.space8,
      children: options.entries.map((e) {
        final isActive = selected == e.key;
        return GestureDetector(
          onTap: () => onSelected(e.key),
          child: AnimatedContainer(
            duration: AppDimensions.durationTransition,
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.space16,
              vertical:   AppDimensions.space10,
            ),
            decoration: BoxDecoration(
              color: isActive
                  ? AppColors.champagneGold.withValues(alpha: 0.12)
                  : AppColors.surfaceGlass,
              borderRadius: BorderRadius.circular(AppDimensions.radiusChip),
              border: Border.all(
                color: isActive ? AppColors.champagneGold : AppColors.cardBorder,
                width: isActive ? AppDimensions.borderFocus : AppDimensions.borderThin,
              ),
            ),
            child: Text(
              e.value,
              style: AppTypography.chipLabel.copyWith(
                color: isActive ? AppColors.champagneGold : AppColors.pearlWhite,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
