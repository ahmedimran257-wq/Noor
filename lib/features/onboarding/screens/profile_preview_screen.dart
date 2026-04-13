// lib/features/onboarding/screens/profile_preview_screen.dart
// ============================================================
// NOOR — Profile Preview Screen (Onboarding Step 9)
// Read-only rendering of the full profile as others will see it.
// Tappable "Edit" labels navigate back to specific steps.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/cubits/onboarding/onboarding_cubit.dart';
import '../../../core/cubits/onboarding/onboarding_state.dart';
import '../../../core/models/onboarding_data.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/buttons/noor_primary_button.dart';

class ProfilePreviewScreen extends StatelessWidget {
  const ProfilePreviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<OnboardingCubit, OnboardingState>(
      builder: (context, state) {
        final cubit    = context.read<OnboardingCubit>();
        final data     = cubit.currentData;
        final isLoading = state is OnboardingLoading;

        return Scaffold(
          backgroundColor: AppColors.obsidianNight,
          body: SafeArea(
            child: Column(
              children: [
                // ── Header ─────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppDimensions.space24,
                    AppDimensions.space20,
                    AppDimensions.space24,
                    0,
                  ),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => cubit.goBack(),
                        child: Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(
                            color:  AppColors.surfaceGlass,
                            shape:  BoxShape.circle,
                            border: Border.all(color: AppColors.cardBorder),
                          ),
                          child: Icon(
                            Directionality.of(context) == TextDirection.rtl
                                ? Icons.arrow_forward_ios_rounded
                                : Icons.arrow_back_ios_new_rounded,
                            color: AppColors.pearlWhite,
                            size:  16,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text('Preview', style: AppTypography.wordmark.copyWith(
                        fontSize: 18,
                      )),
                      const Spacer(),
                      const SizedBox(width: 40),
                    ],
                  ),
                ),

                // ── Scrollable profile ─────────────────────
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimensions.space24,
                      vertical:   AppDimensions.space24,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Photo card mock
                        _PhotoPreviewCard(data: data),
                        const SizedBox(height: AppDimensions.space24),

                        // Sections
                        _PreviewSection(
                          title:   'Basic Info',
                          editStep: 1,
                          rows: [
                            _PreviewRow('Name',   data.displayName.isNotEmpty ? data.displayName : '—'),
                            _PreviewRow('Age',    data.age?.toString() ?? '—'),
                            _PreviewRow('City',   data.cityName ?? '—'),
                            _PreviewRow('Gender', data.gender == Gender.male ? 'Male' : 'Female'),
                          ],
                        ),
                        const SizedBox(height: AppDimensions.space16),

                        _PreviewSection(
                          title:   'Faith',
                          editStep: 2,
                          rows: [
                            _PreviewRow('Sect',       _sectLabel(data.sect)),
                            _PreviewRow('Deen Level', _deenLabel(data.deenLevel)),
                            _PreviewRow('Prays 5x',   data.praysFiveDaily == null ? '—'
                                : (data.praysFiveDaily! ? 'Yes' : 'No')),
                            if (data.gender == Gender.female)
                              _PreviewRow('Hijab', data.hijabStyle ?? '—'),
                          ],
                        ),
                        const SizedBox(height: AppDimensions.space16),

                        _PreviewSection(
                          title:   'Background',
                          editStep: 3,
                          rows: [
                            _PreviewRow('Education', data.educationLabel ?? '—'),
                            _PreviewRow('Profession', data.profession ?? '—'),
                          ],
                        ),
                        const SizedBox(height: AppDimensions.space16),

                        _PreviewSection(
                          title:   'Family',
                          editStep: 5,
                          rows: [
                            _PreviewRow('Family type', _familyLabel(data.familyType)),
                            _PreviewRow('Siblings', data.siblingCount?.toString() ?? '—'),
                            _PreviewRow('Marital', _maritalLabel(data.maritalStatus)),
                          ],
                        ),
                        const SizedBox(height: AppDimensions.space16),

                        if (data.bio != null && data.bio!.isNotEmpty) ...[
                          _SectionHeader(title: 'Bio', editStep: 6, context: context),
                          const SizedBox(height: AppDimensions.space8),
                          Text(data.bio!, style: AppTypography.bio),
                          const SizedBox(height: AppDimensions.space16),
                        ],

                        if (data.interests != null && data.interests!.isNotEmpty) ...[
                          Text('INTERESTS', style: AppTypography.sectionLabel),
                          const SizedBox(height: AppDimensions.space8),
                          Wrap(
                            spacing:    AppDimensions.space6,
                            runSpacing: AppDimensions.space6,
                            children: data.interests!.map((tag) =>
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppDimensions.space12,
                                  vertical:   AppDimensions.space6,
                                ),
                                decoration: BoxDecoration(
                                  color:        AppColors.surfaceGlass,
                                  borderRadius: BorderRadius.circular(AppDimensions.radiusChip),
                                  border:       Border.all(color: AppColors.cardBorder),
                                ),
                                child: Text(tag, style: AppTypography.chipLabel),
                              ),
                            ).toList(),
                          ),
                          const SizedBox(height: AppDimensions.space24),
                        ],

                        // Notice
                        Container(
                          padding: const EdgeInsets.all(AppDimensions.space16),
                          decoration: BoxDecoration(
                            color:        AppColors.surfaceGlass,
                            borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
                            border:       Border.all(color: AppColors.cardBorder),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.visibility_outlined,
                                  color: AppColors.slateMist, size: 18),
                              const SizedBox(width: AppDimensions.space12),
                              Expanded(
                                child: Text(
                                  'This is exactly how others will see your profile.',
                                  style: AppTypography.caption,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppDimensions.space32),
                      ],
                    ),
                  ),
                ),

                // ── CTA ────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppDimensions.space24,
                    AppDimensions.space16,
                    AppDimensions.space24,
                    AppDimensions.space32,
                  ),
                  child: NoorPrimaryButton(
                    label:     'Submit Profile',
                    isLoading: isLoading,
                    onTap:     isLoading ? null : () => cubit.saveAndAdvance(data),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _sectLabel(Sect? s) {
    switch (s) {
      case Sect.sunni:          return 'Sunni';
      case Sect.shia:           return 'Shia';
      case Sect.preferNotToSay: return 'Prefer not to say';
      case Sect.other:          return 'Other';
      case null:                return '—';
    }
  }

  String _deenLabel(DeenLevel? d) {
    switch (d) {
      case DeenLevel.practicing: return 'Practicing';
      case DeenLevel.moderate:   return 'Moderate';
      case DeenLevel.cultural:   return 'Cultural Muslim';
      case null:                 return '—';
    }
  }

  String _familyLabel(FamilyType? f) {
    switch (f) {
      case FamilyType.nuclear:  return 'Nuclear';
      case FamilyType.joint:    return 'Joint';
      case FamilyType.extended: return 'Extended';
      case null:                return '—';
    }
  }

  String _maritalLabel(MaritalStatus? m) {
    switch (m) {
      case MaritalStatus.neverMarried: return 'Never married';
      case MaritalStatus.divorced:     return 'Divorced';
      case MaritalStatus.widowed:      return 'Widowed';
      case null:                       return '—';
    }
  }
}

// ── Sub-widgets ───────────────────────────────────────────────

class _PhotoPreviewCard extends StatelessWidget {
  const _PhotoPreviewCard({required this.data});
  final OnboardingData data;

  @override
  Widget build(BuildContext context) {
    final hasPhoto = data.photoLocalPaths?.isNotEmpty == true;
    return AspectRatio(
      aspectRatio: 3 / 4,
      child: Container(
        decoration: BoxDecoration(
          color:        AppColors.surfaceGlass,
          borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
          border:       Border.all(color: AppColors.cardBorder),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end:   Alignment.bottomCenter,
            colors: [Color(0xFF1A1A2F), Color(0xFF0A0A0F)],
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Center(
              child: Icon(
                hasPhoto ? Icons.check_circle_outline : Icons.person_outline_rounded,
                color: hasPhoto ? AppColors.verifiedTeal : AppColors.slateMist,
                size:  80,
              ),
            ),
            Positioned(
              left: 20, right: 20, bottom: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    data.displayName.isNotEmpty ? data.displayName : 'Your Name',
                    style: AppTypography.userName,
                  ),
                  if (data.age != null && data.cityName != null)
                    Text(
                      '${data.age} · ${data.cityName}',
                      style: AppTypography.cardLocation,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.editStep,
    required this.context,
  });
  final String title;
  final int editStep;
  final BuildContext context;

  @override
  Widget build(BuildContext _) {
    return Row(
      children: [
        Text(title.toUpperCase(), style: AppTypography.sectionLabel),
        const Spacer(),
        GestureDetector(
          onTap: () {
            // In production: navigate back to editStep
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Navigate to step $editStep'),
                backgroundColor: AppColors.surfaceGlassHover,
                duration: const Duration(seconds: 1),
              ),
            );
          },
          child: Text(
            'Edit',
            style: AppTypography.caption.copyWith(
              color: AppColors.champagneGold,
            ),
          ),
        ),
      ],
    );
  }
}

class _PreviewSection extends StatelessWidget {
  const _PreviewSection({
    required this.title,
    required this.editStep,
    required this.rows,
  });
  final String title;
  final int editStep;
  final List<_PreviewRow> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color:        AppColors.surfaceGlass,
        borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
        border:       Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        children: [
          // Section header
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppDimensions.space16,
              AppDimensions.space12,
              AppDimensions.space16,
              AppDimensions.space12,
            ),
            child: Row(
              children: [
                Text(title.toUpperCase(), style: AppTypography.sectionLabel),
                const Spacer(),
                GestureDetector(
                  onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Edit $title'),
                      backgroundColor: AppColors.surfaceGlassHover,
                      duration: const Duration(seconds: 1),
                    ),
                  ),
                  child: Text(
                    'Edit',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.champagneGold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            height: 1,
            color: AppColors.divider,
          ),

          // Rows
          ...rows.map((row) => Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.space16,
              vertical:   AppDimensions.space12,
            ),
            child: Row(
              children: [
                Text(row.label, style: AppTypography.bodyMuted),
                const Spacer(),
                Text(row.value, style: AppTypography.bodyMedium),
              ],
            ),
          )),
        ],
      ),
    );
  }
}

class _PreviewRow {
  const _PreviewRow(this.label, this.value);
  final String label;
  final String value;
}
