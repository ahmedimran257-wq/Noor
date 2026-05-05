// lib/features/onboarding/screens/islamic_marriage_details_screen.dart
// ============================================================
// NOOR — Islamic Marriage Details Screen
// Collects: quranMemorization, religiousEducation,
//           marriageTimeline, willingToRelocate,
//           + gender-specific: niqab/mahr/work (female),
//             mahr budget/religious leadership (male)
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
  String? _willingToRelocate;

  // Female-specific
  String? _niqabPreference;
  String? _mahrExpectation;
  bool?   _willingToWorkAfterMarriage;

  // Male-specific
  String? _mahrBudget;
  String? _religiousLeadership;

  bool get _isFemale =>
      context.read<OnboardingCubit>().currentData.gender == Gender.female;

  bool get _canProceed =>
      _marriageTimeline != null && _willingToRelocate != null;

  void _advance() {
    final data = context.read<OnboardingCubit>().currentData.copyWith(
      quranMemorization:         _quranMemorization,
      religiousEducation:        _religiousEducation,
      marriageTimeline:          _marriageTimeline,
      willingToRelocate:         _willingToRelocate,
      niqabPreference:           _isFemale ? _niqabPreference : null,
      mahrExpectation:           _isFemale ? _mahrExpectation : null,
      willingToWorkAfterMarriage: _isFemale ? _willingToWorkAfterMarriage : null,
      mahrBudget:                !_isFemale ? _mahrBudget : null,
      religiousLeadership:       !_isFemale ? _religiousLeadership : null,
    );
    context.read<OnboardingCubit>().saveAndAdvance(data);
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<OnboardingCubit, OnboardingState>(
      builder: (context, state) {
        final isLoading = state is OnboardingLoading;
        return OnboardingScaffold(
          step:         state is OnboardingActive ? state.step : 3,
          totalSteps:   12,
          ctaLabel:     'Continue',
          onCta:        _advance,
          isCtaEnabled: _canProceed,
          isCtaLoading: isLoading,
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppDimensions.space32),
              const StepHeader(
                title:    'Marriage & Deen',
                subtitle: 'Help us understand your journey and readiness.',
              ),
              const SizedBox(height: AppDimensions.space28),

              // ── Quran Memorization ────────────────────────────
              _buildSection('QURAN MEMORIZATION', null),
              _buildChipRow(_quranMemorization, {
                'none':       'None',
                'some_surahs': 'Some Surahs',
                'partial':    'Partial Hifz',
                'hafiz':      'Hafiz / Hafiza',
              }, (v) => setState(() => _quranMemorization = v)),

              const SizedBox(height: AppDimensions.space24),

              // ── Religious Education ───────────────────────────
              _buildSection('RELIGIOUS EDUCATION', null),
              _buildChipRow(_religiousEducation, {
                'self_taught':  'Self-Taught',
                'madrasa':      'Madrasa',
                'islamic_uni':  'Islamic University',
                'alim_course':  'Alim Course',
                'none':         'None',
              }, (v) => setState(() => _religiousEducation = v)),

              const SizedBox(height: AppDimensions.space24),

              // ── Marriage Timeline ─────────────────────────────
              _buildSection('MARRIAGE TIMELINE', 'When are you looking to get married?'),
              _buildChipRow(_marriageTimeline, {
                'asap':          'As soon as possible',
                '6_months':      'Within 6 months',
                '1_year':        'Within a year',
                '2_plus_years':  '2+ years',
                'not_sure':      'Not sure yet',
              }, (v) => setState(() => _marriageTimeline = v)),

              const SizedBox(height: AppDimensions.space24),

              // ── Willing to Relocate ───────────────────────────
              _buildSection('WILLING TO RELOCATE', null),
              _buildChipRow(_willingToRelocate, {
                'yes':               'Yes',
                'no':                'No',
                'open_to_discussion': 'Open to discussion',
              }, (v) => setState(() => _willingToRelocate = v)),

              const SizedBox(height: AppDimensions.space24),

              // ── Gender-specific sections ──────────────────────
              if (_isFemale) ..._buildFemaleFields(),
              if (!_isFemale) ..._buildMaleFields(),

              const SizedBox(height: AppDimensions.space40),
            ],
          ),
        );
      },
    );
  }

  // ── Female-specific ─────────────────────────────────────────

  List<Widget> _buildFemaleFields() => [
    _buildSection('NIQAB', null),
    _buildChipRow(_niqabPreference, {
      'wears_niqab':       'I wear niqab',
      'open_to_niqab':     'Open to wearing',
      'no_niqab':          'I don\'t wear niqab',
      'prefer_not_to_say': 'Prefer not to say',
    }, (v) => setState(() => _niqabPreference = v)),
    const SizedBox(height: AppDimensions.space24),

    _buildSection('MAHR EXPECTATION', 'What is your expectation for mahr?'),
    _buildChipRow(_mahrExpectation, {
      'no_preference': 'No preference',
      'modest':        'Modest',
      'moderate':      'Moderate',
      'high':          'Generous',
      'to_discuss':    'To discuss',
    }, (v) => setState(() => _mahrExpectation = v)),
    const SizedBox(height: AppDimensions.space24),

    _buildSection('WORK AFTER MARRIAGE', 'Would you like to work after marriage?'),
    _buildChipRow(
      _willingToWorkAfterMarriage == null
          ? null
          : _willingToWorkAfterMarriage! ? 'yes' : 'no',
      {
        'yes': 'Yes, I plan to work',
        'no':  'No, I prefer not to',
      },
      (v) => setState(() => _willingToWorkAfterMarriage = v == 'yes'),
    ),
    const SizedBox(height: AppDimensions.space24),
  ];

  // ── Male-specific ───────────────────────────────────────────

  List<Widget> _buildMaleFields() => [
    _buildSection('MAHR BUDGET', 'What mahr range are you prepared to offer?'),
    _buildChipRow(_mahrBudget, {
      'modest':    'Modest',
      'moderate':  'Moderate',
      'generous':  'Generous',
      'to_discuss': 'To discuss',
    }, (v) => setState(() => _mahrBudget = v)),
    const SizedBox(height: AppDimensions.space24),

    _buildSection('RELIGIOUS LEADERSHIP', 'Can you lead prayer at home?'),
    _buildChipRow(_religiousLeadership, {
      'leads_prayer':      'Yes, regularly',
      'learning':          'Learning',
      'not_yet':           'Not yet',
      'prefer_not_to_say': 'Prefer not to say',
    }, (v) => setState(() => _religiousLeadership = v)),
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
