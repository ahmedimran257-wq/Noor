// lib/features/onboarding/screens/guardian_details_screen.dart
// ============================================================
// NOOR — Guardian Details Screen (Onboarding Step 0.5)
//
// Shown when user selects "My son or daughter" in ProfileForWhomScreen.
// Collects:
//   1. Candidate gender (son / daughter)
//   2. Guardian's own phone number + country code
//   3. Relationship to candidate (Father / Mother / Brother / Sister / Other)
//
// Blueprint (Part 4):
//   "Guardian profiles are created by a wali or parent.
//    The profile is marked isGuardianMode=true.
//    The candidate's gender determines the subscription gate."
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/cubits/auth/auth_cubit.dart';
import '../../../core/cubits/onboarding/onboarding_cubit.dart';
import '../../../core/cubits/onboarding/onboarding_state.dart';
import '../../../core/models/onboarding_data.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../widgets/onboarding_scaffold.dart';
import '../widgets/step_header.dart';

// ── Country codes (shared, kept minimal here — full list in phone_verification)

class _CC {
  const _CC(this.flag, this.name, this.dialCode);
  final String flag;
  final String name;
  final String dialCode;
}

const _kCodes = <_CC>[
  _CC('🇮🇳', 'India',        '+91'),
  _CC('🇵🇰', 'Pakistan',     '+92'),
  _CC('🇧🇩', 'Bangladesh',   '+880'),
  _CC('🇸🇦', 'Saudi Arabia', '+966'),
  _CC('🇦🇪', 'UAE',          '+971'),
  _CC('🇬🇧', 'UK',           '+44'),
  _CC('🇺🇸', 'USA',          '+1'),
  _CC('🇨🇦', 'Canada',       '+1'),
  _CC('🇦🇺', 'Australia',    '+61'),
  _CC('🇲🇾', 'Malaysia',     '+60'),
  _CC('🇮🇩', 'Indonesia',    '+62'),
  _CC('🇳🇬', 'Nigeria',      '+234'),
  _CC('🇪🇬', 'Egypt',        '+20'),
  _CC('🇹🇷', 'Turkey',       '+90'),
  _CC('🇶🇦', 'Qatar',        '+974'),
  _CC('🇰🇼', 'Kuwait',       '+965'),
  _CC('🇴🇲', 'Oman',         '+968'),
  _CC('🇩🇪', 'Germany',      '+49'),
  _CC('🇫🇷', 'France',       '+33'),
  _CC('🇳🇱', 'Netherlands',  '+31'),
  _CC('🇸🇪', 'Sweden',       '+46'),
  _CC('🇳🇴', 'Norway',       '+47'),
  _CC('🇿🇦', 'South Africa', '+27'),
  _CC('🇰🇪', 'Kenya',        '+254'),
  _CC('🇵🇭', 'Philippines',  '+63'),
  _CC('🇸🇬', 'Singapore',    '+65'),
];

// ── Relationship options ──────────────────────────────────────

const _kRelationships = <String>[
  'Father', 'Mother', 'Brother', 'Sister', 'Other',
];

// ── Screen ────────────────────────────────────────────────────

class GuardianDetailsScreen extends StatefulWidget {
  const GuardianDetailsScreen({super.key});

  @override
  State<GuardianDetailsScreen> createState() => _GuardianDetailsScreenState();
}

class _GuardianDetailsScreenState extends State<GuardianDetailsScreen> {
  // Candidate's gender — required
  Gender? _candidateGender;

  // Guardian phone
  _CC     _selectedCode = _kCodes.first;          // India by default
  final   _phoneCtrl    = TextEditingController();

  // Relationship
  String? _relationship;

  bool get _canProceed =>
      _candidateGender != null &&
      _phoneCtrl.text.trim().length >= 7 &&
      _relationship != null;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    super.dispose();
  }

  void _showCodePicker() {
    showModalBottomSheet<void>(
      context:            context,
      backgroundColor:    const Color(0xFF12121A),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _CodePickerSheet(
        selected:   _selectedCode,
        onSelected: (c) {
          setState(() => _selectedCode = c);
          Navigator.pop(context);
        },
      ),
    );
  }

  void _advance() {
    final guardianPhone = '${_selectedCode.dialCode}${_phoneCtrl.text.trim()}';

    // Propagate candidate gender to AuthCubit so subscription gates
    // immediately use the correct gender (e.g. 'female' → messaging free).
    final gender = _candidateGender == Gender.female ? 'female' : 'male';
    context.read<AuthCubit>().setGender(gender);

    final updated = context.read<OnboardingCubit>().currentData.copyWith(
      gender:                  _candidateGender,
      isGuardianMode:          true,
      guardianPhone:           guardianPhone,
      guardianPhoneCountryCode: _selectedCode.dialCode,
      guardianRelationship:    _relationship,
    );
    context.read<OnboardingCubit>().saveAndAdvance(updated);
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<OnboardingCubit, OnboardingState>(
      builder: (context, state) {
        final isLoading = state is OnboardingLoading;
        return OnboardingScaffold(
          step:         1,       // visual slot in progress bar (0.5 → 1)
          totalSteps:   10,
          ctaLabel:     'Continue',
          onCta:        _advance,
          isCtaEnabled: _canProceed,
          isCtaLoading: isLoading,
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppDimensions.space32),

              // ── Info notice ─────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(AppDimensions.space16),
                decoration: BoxDecoration(
                  color:        AppColors.champagneGold.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
                  border:       Border.all(color: AppColors.goldBorder),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.volunteer_activism_outlined,
                        color: AppColors.champagneGold, size: 18),
                    const SizedBox(width: AppDimensions.space12),
                    Expanded(
                      child: Text(
                        'As a guardian you are entrusted with this journey. '
                        'All details will be shown as the candidate\'s profile.',
                        style: AppTypography.caption.copyWith(height: 1.6),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppDimensions.space28),

              const StepHeader(
                title:    'Guardian profile details',
                subtitle: 'Tell us about the person you\'re registering for.',
              ),
              const SizedBox(height: AppDimensions.space32),

              // ── Candidate gender ────────────────────────────────
              Text('PROFILE FOR A', style: AppTypography.sectionLabel),
              const SizedBox(height: AppDimensions.space12),
              Row(
                children: [
                  Expanded(
                    child: _GenderCard(
                      icon:       Icons.male_rounded,
                      label:      'Son',
                      subtitle:   'Creating a profile for your son',
                      isSelected: _candidateGender == Gender.male,
                      onTap:      () => setState(() => _candidateGender = Gender.male),
                    ),
                  ),
                  const SizedBox(width: AppDimensions.space12),
                  Expanded(
                    child: _GenderCard(
                      icon:       Icons.female_rounded,
                      label:      'Daughter',
                      subtitle:   'Creating a profile for your daughter',
                      isSelected: _candidateGender == Gender.female,
                      onTap:      () => setState(() => _candidateGender = Gender.female),
                    ),
                  ),
                ],
              ),

              // Messaging note for daughters (women message free)
              if (_candidateGender == Gender.female) ...[
                const SizedBox(height: AppDimensions.space12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.space14,
                    vertical:   AppDimensions.space10,
                  ),
                  decoration: BoxDecoration(
                    color:        AppColors.verifiedTeal.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(AppDimensions.radiusChip),
                    border:       Border.all(color: AppColors.verifiedTeal.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.favorite_rounded,
                          color: AppColors.verifiedTeal, size: 14),
                      const SizedBox(width: AppDimensions.space8),
                      Expanded(
                        child: Text(
                          'Women always message free on NOOR.',
                          style: AppTypography.caption.copyWith(
                              color: AppColors.verifiedTeal),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: AppDimensions.space28),

              // ── Guardian phone ──────────────────────────────────
              Text('YOUR PHONE NUMBER', style: AppTypography.sectionLabel),
              const SizedBox(height: AppDimensions.space8),
              Text(
                'We may contact you for candidate verification purposes.',
                style: AppTypography.caption,
              ),
              const SizedBox(height: AppDimensions.space12),

              // Country code row
              Row(
                children: [
                  // Code selector
                  GestureDetector(
                    onTap: _showCodePicker,
                    child: Container(
                      height:  AppDimensions.buttonHeight,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppDimensions.space12,
                      ),
                      decoration: BoxDecoration(
                        color:        AppColors.surfaceGlass,
                        borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
                        border:       Border.all(color: AppColors.cardBorder),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_selectedCode.flag,
                              style: const TextStyle(fontSize: 20)),
                          const SizedBox(width: AppDimensions.space8),
                          Text(_selectedCode.dialCode,
                              style: AppTypography.bodyMedium),
                          const SizedBox(width: AppDimensions.space4),
                          const Icon(Icons.expand_more_rounded,
                              color: AppColors.slateMist, size: 16),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: AppDimensions.space12),

                  // Phone number field
                  Expanded(
                    child: Container(
                      height: AppDimensions.buttonHeight,
                      decoration: BoxDecoration(
                        color:        AppColors.surfaceGlass,
                        borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
                        border:       Border.all(color: AppColors.cardBorder),
                      ),
                      child: TextField(
                        controller:   _phoneCtrl,
                        keyboardType: TextInputType.phone,
                        style:        AppTypography.inputText,
                        onChanged:    (_) => setState(() {}),
                        decoration: InputDecoration(
                          hintText:       'Phone number',
                          hintStyle:      AppTypography.inputText.copyWith(
                                            color: AppColors.slateMist),
                          border:         InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: AppDimensions.space16,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: AppDimensions.space28),

              // ── Relationship ────────────────────────────────────
              Text('YOUR RELATIONSHIP TO CANDIDATE',
                  style: AppTypography.sectionLabel),
              const SizedBox(height: AppDimensions.space12),
              Wrap(
                spacing:    AppDimensions.space8,
                runSpacing: AppDimensions.space8,
                children: _kRelationships
                    .map((r) => _RelChip(
                          label:      r,
                          isSelected: _relationship == r,
                          onTap: () =>
                              setState(() => _relationship = r),
                        ))
                    .toList(),
              ),

              const SizedBox(height: AppDimensions.space32),

              // ── Privacy note ────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(AppDimensions.space16),
                decoration: BoxDecoration(
                  color:        AppColors.surfaceGlass,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
                  border:       Border.all(color: AppColors.cardBorder),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.lock_outline_rounded,
                        color: AppColors.slateMist, size: 16),
                    const SizedBox(width: AppDimensions.space10),
                    Expanded(
                      child: Text(
                        'Your guardian phone number is not shown on the public profile. '
                        'It is only used for account verification.',
                        style: AppTypography.caption.copyWith(height: 1.6),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppDimensions.space40),
            ],
          ),
        );
      },
    );
  }
}

// ── Gender Card ───────────────────────────────────────────────

class _GenderCard extends StatelessWidget {
  const _GenderCard({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });
  final IconData icon;
  final String   label;
  final String   subtitle;
  final bool     isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppDimensions.durationTransition,
        padding:  const EdgeInsets.all(AppDimensions.space16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.champagneGold.withValues(alpha: 0.08)
              : AppColors.surfaceGlass,
          borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
          border: Border.all(
            color: isSelected ? AppColors.champagneGold : AppColors.cardBorder,
            width: isSelected ? AppDimensions.borderFocus : AppDimensions.borderThin,
          ),
        ),
        child: Column(
          children: [
            Container(
              width:  52,
              height: 52,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.champagneGold.withValues(alpha: 0.15)
                    : AppColors.surfaceGlassHover,
                shape: BoxShape.circle,
              ),
              child: Icon(icon,
                color: isSelected
                    ? AppColors.champagneGold
                    : AppColors.slateMist,
                size: 26),
            ),
            const SizedBox(height: AppDimensions.space10),
            Text(label,
                style: AppTypography.bodyMedium.copyWith(
                  color: isSelected
                      ? AppColors.champagneGold
                      : AppColors.pearlWhite,
                )),
            const SizedBox(height: AppDimensions.space4),
            Text(
              subtitle,
              style: AppTypography.caption,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Relationship chip ─────────────────────────────────────────

class _RelChip extends StatelessWidget {
  const _RelChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });
  final String label;
  final bool   isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppDimensions.durationTransition,
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.space16,
          vertical:   AppDimensions.space10,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.champagneGold.withValues(alpha: 0.12)
              : AppColors.surfaceGlass,
          borderRadius: BorderRadius.circular(AppDimensions.radiusChip),
          border: Border.all(
            color: isSelected ? AppColors.champagneGold : AppColors.cardBorder,
            width: isSelected ? AppDimensions.borderFocus : AppDimensions.borderThin,
          ),
        ),
        child: Text(label,
            style: AppTypography.chipLabel.copyWith(
              color: isSelected ? AppColors.champagneGold : AppColors.pearlWhite,
            )),
      ),
    );
  }
}

// ── Country Code Picker Sheet ─────────────────────────────────

class _CodePickerSheet extends StatefulWidget {
  const _CodePickerSheet({
    required this.selected,
    required this.onSelected,
  });
  final _CC selected;
  final ValueChanged<_CC> onSelected;

  @override
  State<_CodePickerSheet> createState() => _CodePickerSheetState();
}

class _CodePickerSheetState extends State<_CodePickerSheet> {
  final _searchCtrl = TextEditingController();
  List<_CC> _filtered = List.unmodifiable(_kCodes);

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearch(String q) {
    final lower = q.trim().toLowerCase();
    setState(() {
      _filtered = lower.isEmpty
          ? List.unmodifiable(_kCodes)
          : _kCodes
              .where((c) =>
                  c.name.toLowerCase().contains(lower) ||
                  c.dialCode.contains(lower))
              .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: AppDimensions.space16),
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color:        AppColors.slateMist.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: AppDimensions.space16),
            Text('Select country code', style: AppTypography.bodyMedium),
            const SizedBox(height: AppDimensions.space12),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.space16,
              ),
              child: TextField(
                controller:  _searchCtrl,
                onChanged:   _onSearch,
                style:       AppTypography.inputText,
                decoration: InputDecoration(
                  hintText:  'Search',
                  hintStyle: AppTypography.inputLabel,
                  prefixIcon: const Icon(Icons.search_rounded,
                      color: AppColors.slateMist, size: 20),
                  filled:         true,
                  fillColor:      AppColors.surfaceGlass,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.space12,
                    vertical:   AppDimensions.space10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
                    borderSide:   const BorderSide(color: AppColors.cardBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
                    borderSide:   const BorderSide(color: AppColors.cardBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
                    borderSide:   const BorderSide(
                      color: AppColors.champagneGold,
                      width: AppDimensions.borderFocus,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppDimensions.space8),
            Flexible(
              child: ListView.builder(
                shrinkWrap:  true,
                physics:     const BouncingScrollPhysics(),
                itemCount:   _filtered.length,
                itemBuilder: (_, i) {
                  final c          = _filtered[i];
                  final isSelected = c.dialCode == widget.selected.dialCode &&
                                     c.name == widget.selected.name;
                  return ListTile(
                    leading:  Text(c.flag, style: const TextStyle(fontSize: 22)),
                    title:    Text(c.name, style: AppTypography.body),
                    trailing: Text(c.dialCode, style: AppTypography.bodyMuted),
                    selected:      isSelected,
                    selectedColor: AppColors.champagneGold,
                    onTap:         () => widget.onSelected(c),
                  );
                },
              ),
            ),
            const SizedBox(height: AppDimensions.space16),
          ],
        ),
      ),
    );
  }
}
