// lib/features/onboarding/screens/profile_for_whom_screen.dart
// ============================================================
// NOOR — Profile For Whom Screen (Onboarding Step 0)
// Four selectable cards: Myself / Son or Daughter / Sibling / Ward.
// Auto-advances 300ms after selection.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/cubits/onboarding/onboarding_cubit.dart';
import '../../../core/cubits/onboarding/onboarding_state.dart';
import '../../../core/models/onboarding_data.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../widgets/step_header.dart';

class ProfileForWhomScreen extends StatefulWidget {
  const ProfileForWhomScreen({super.key});

  @override
  State<ProfileForWhomScreen> createState() => _ProfileForWhomScreenState();
}

class _ProfileForWhomScreenState extends State<ProfileForWhomScreen> {
  String? _selectedValue; // 'self','parent','sibling','guardian'

  // TODO (backend): persist profileCreatorRelation to Supabase profiles table.
  void _select(String value) async {
    setState(() => _selectedValue = value);
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    final cubit   = context.read<OnboardingCubit>();
    final current = cubit.currentData;
    cubit.saveAndAdvance(current.copyWith(
      profileFor: value == 'self'
          ? ProfileFor.myself
          : ProfileFor.guardian,
      profileCreatorRelation: value,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<OnboardingCubit, OnboardingState>(
      listener: (context, state) {
        // Navigation handled by GoRouter redirect on AuthCubit step update
      },
      child: Scaffold(
        backgroundColor: AppColors.obsidianNight,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.space24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: AppDimensions.space32),
                const StepHeader(
                  title:    'Who is this profile for?',
                  subtitle: 'You can update this later from settings.',
                ),
                const SizedBox(height: AppDimensions.space32),

                _SelectionCard(
                  icon:       Icons.person_outline_rounded,
                  title:      'Myself',
                  subtitle:   'I am looking for a spouse',
                  isSelected: _selectedValue == 'self',
                  onTap:      () => _select('self'),
                ),
                const SizedBox(height: AppDimensions.space16),

                _SelectionCard(
                  icon:       Icons.family_restroom_rounded,
                  title:      'My son or daughter',
                  subtitle:   'I am a parent creating this profile',
                  isSelected: _selectedValue == 'parent',
                  onTap:      () => _select('parent'),
                ),
                const SizedBox(height: AppDimensions.space16),

                _SelectionCard(
                  icon:       Icons.people_outline_rounded,
                  title:      'My brother or sister',
                  subtitle:   'I am helping my sibling find a match',
                  isSelected: _selectedValue == 'sibling',
                  onTap:      () => _select('sibling'),
                ),
                const SizedBox(height: AppDimensions.space16),

                _SelectionCard(
                  icon:       Icons.shield_outlined,
                  title:      'My ward',
                  subtitle:   'I am a guardian managing this profile',
                  isSelected: _selectedValue == 'guardian',
                  onTap:      () => _select('guardian'),
                ),

                const Spacer(),

                // Subtle note
                Center(
                  child: Text(
                    'Select one to continue',
                    style: AppTypography.caption,
                  ),
                ),
                const SizedBox(height: AppDimensions.space24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Selection Card ────────────────────────────────────────────

class _SelectionCard extends StatelessWidget {
  const _SelectionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final String   title;
  final String   subtitle;
  final bool     isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppDimensions.durationTransition,
        curve:    Curves.easeOutCubic,
        padding:  const EdgeInsets.all(AppDimensions.space20),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.champagneGold.withValues(alpha: 0.08)
              : AppColors.surfaceGlass,
          borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
          border: Border.all(
            color: isSelected
                ? AppColors.champagneGold
                : AppColors.cardBorder,
            width: isSelected
                ? AppDimensions.borderFocus
                : AppDimensions.borderThin,
          ),
        ),
        child: Row(
          children: [
            Container(
              width:  56,
              height: 56,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.champagneGold.withValues(alpha: 0.15)
                    : AppColors.surfaceGlassHover,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                icon,
                color: isSelected
                    ? AppColors.champagneGold
                    : AppColors.slateMist,
                size: AppDimensions.iconSizeLarge,
              ),
            ),
            const SizedBox(width: AppDimensions.space16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.bodyMedium.copyWith(
                      color: isSelected
                          ? AppColors.champagneGold
                          : AppColors.pearlWhite,
                    ),
                  ),
                  const SizedBox(height: AppDimensions.space4),
                  Text(subtitle, style: AppTypography.caption),
                ],
              ),
            ),
            AnimatedOpacity(
              opacity:  isSelected ? 1.0 : 0.0,
              duration: AppDimensions.durationTransition,
              child: Container(
                width:  24,
                height: 24,
                decoration: BoxDecoration(
                  color:  AppColors.champagneGold,
                  shape:  BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: AppColors.obsidianNight,
                  size:  16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
