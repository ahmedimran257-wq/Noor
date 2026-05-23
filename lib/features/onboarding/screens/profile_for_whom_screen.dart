// lib/features/onboarding/screens/profile_for_whom_screen.dart
// ============================================================
// NOOR — Profile For Whom Screen (Onboarding Step 0)
// Two primary options: Myself / Guardian.
// Selecting Guardian expands to show relationship sub-options:
//   Son, Daughter, Brother, Sister.
// Auto-advances 300ms after final selection.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

class _ProfileForWhomScreenState extends State<ProfileForWhomScreen>
    with SingleTickerProviderStateMixin {
  String? _selectedCategory;   // 'self' or 'guardian'
  String? _selectedRelation;   // 'son','daughter','brother','sister'

  late final AnimationController _expandCtrl;
  late final Animation<double> _expandAnim;

  @override
  void initState() {
    super.initState();
    _expandCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _expandAnim = CurvedAnimation(
      parent: _expandCtrl,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _expandCtrl.dispose();
    super.dispose();
  }

  void _selectSelf() async {
    HapticFeedback.lightImpact();
    setState(() {
      _selectedCategory = 'self';
      _selectedRelation = null;
    });
    _expandCtrl.reverse();

    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    final cubit   = context.read<OnboardingCubit>();
    final current = cubit.currentData;
    cubit.saveAndAdvance(current.copyWith(
      profileFor: ProfileFor.myself,
      profileCreatorRelation: 'self',
    ));
  }

  void _selectGuardian() {
    HapticFeedback.lightImpact();
    setState(() {
      _selectedCategory = 'guardian';
      _selectedRelation = null;
    });
    _expandCtrl.forward();
  }

  void _selectRelation(String relation) async {
    HapticFeedback.mediumImpact();
    setState(() => _selectedRelation = relation);

    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    final cubit   = context.read<OnboardingCubit>();
    final current = cubit.currentData;
    cubit.saveAndAdvance(current.copyWith(
      profileFor: ProfileFor.guardian,
      profileCreatorRelation: relation,
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

                // ── Option 1: Myself ─────────────────────────
                _SelectionCard(
                  icon:       Icons.person_outline_rounded,
                  title:      'Myself',
                  subtitle:   'I am looking for a spouse',
                  isSelected: _selectedCategory == 'self',
                  onTap:      _selectSelf,
                ),
                const SizedBox(height: AppDimensions.space16),

                // ── Option 2: Guardian ───────────────────────
                _SelectionCard(
                  icon:       Icons.shield_outlined,
                  title:      'Guardian',
                  subtitle:   'I am creating this profile for someone',
                  isSelected: _selectedCategory == 'guardian',
                  onTap:      _selectGuardian,
                  showChevron: true,
                  isExpanded: _selectedCategory == 'guardian',
                ),

                // ── Guardian sub-options (animated expand) ───
                SizeTransition(
                  sizeFactor: _expandAnim,
                  axisAlignment: -1.0,
                  child: Padding(
                    padding: const EdgeInsets.only(
                      top: AppDimensions.space12,
                      left: AppDimensions.space8,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(
                            left: AppDimensions.space12,
                            bottom: AppDimensions.space10,
                          ),
                          child: Text(
                            'I am creating this for my…',
                            style: AppTypography.caption.copyWith(
                              color: AppColors.champagneGold,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: _RelationChip(
                                icon: Icons.boy_rounded,
                                label: 'Son',
                                isSelected: _selectedRelation == 'son',
                                onTap: () => _selectRelation('son'),
                              ),
                            ),
                            const SizedBox(width: AppDimensions.space10),
                            Expanded(
                              child: _RelationChip(
                                icon: Icons.girl_rounded,
                                label: 'Daughter',
                                isSelected: _selectedRelation == 'daughter',
                                onTap: () => _selectRelation('daughter'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppDimensions.space10),
                        Row(
                          children: [
                            Expanded(
                              child: _RelationChip(
                                icon: Icons.person_outline_rounded,
                                label: 'Brother',
                                isSelected: _selectedRelation == 'brother',
                                onTap: () => _selectRelation('brother'),
                              ),
                            ),
                            const SizedBox(width: AppDimensions.space10),
                            Expanded(
                              child: _RelationChip(
                                icon: Icons.person_outline_rounded,
                                label: 'Sister',
                                isSelected: _selectedRelation == 'sister',
                                onTap: () => _selectRelation('sister'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const Spacer(),

                // Subtle note
                Center(
                  child: Text(
                    _selectedCategory == 'guardian' && _selectedRelation == null
                        ? 'Select a relationship to continue'
                        : 'Select one to continue',
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

// ── Selection Card (primary option) ───────────────────────────

class _SelectionCard extends StatelessWidget {
  const _SelectionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
    this.showChevron = false,
    this.isExpanded = false,
  });

  final IconData icon;
  final String   title;
  final String   subtitle;
  final bool     isSelected;
  final VoidCallback onTap;
  final bool     showChevron;
  final bool     isExpanded;

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
            if (showChevron)
              AnimatedRotation(
                turns: isExpanded ? 0.25 : 0.0,
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                child: Icon(
                  Icons.chevron_right_rounded,
                  color: isSelected
                      ? AppColors.champagneGold
                      : AppColors.slateMist,
                  size: 22,
                ),
              )
            else
              AnimatedOpacity(
                opacity:  isSelected ? 1.0 : 0.0,
                duration: AppDimensions.durationTransition,
                child: Container(
                  width:  24,
                  height: 24,
                  decoration: const BoxDecoration(
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

// ── Relation Chip (guardian sub-option) ───────────────────────

class _RelationChip extends StatelessWidget {
  const _RelationChip({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final String   label;
  final bool     isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.space16,
          vertical: AppDimensions.space14,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.champagneGold.withValues(alpha: 0.12)
              : AppColors.surfaceGlass,
          borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
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
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected
                  ? AppColors.champagneGold
                  : AppColors.slateMist,
              size: 20,
            ),
            const SizedBox(width: AppDimensions.space8),
            Text(
              label,
              style: AppTypography.bodyMedium.copyWith(
                color: isSelected
                    ? AppColors.champagneGold
                    : AppColors.pearlWhite,
                fontSize: 14,
              ),
            ),
            if (isSelected) ...[
              const SizedBox(width: AppDimensions.space8),
              Container(
                width:  18,
                height: 18,
                decoration: const BoxDecoration(
                  color: AppColors.champagneGold,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: AppColors.obsidianNight,
                  size:  12,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
