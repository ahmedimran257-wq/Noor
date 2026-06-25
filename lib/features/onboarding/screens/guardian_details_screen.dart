// lib/features/onboarding/screens/guardian_details_screen.dart
// ============================================================
// MITHAQ — Guardian Details Screen (Onboarding Step 0.5)
//
// Shown when user selects Guardian → Son/Daughter/Brother/Sister
// in ProfileForWhomScreen. The candidate's gender and the
// guardian's relationship are ALREADY KNOWN from the previous
// selection:
//
//   "Son"      → gender=male,   relation=parent
//   "Daughter" → gender=female, relation=parent
//   "Brother"  → gender=male,   relation=sibling
//   "Sister"   → gender=female, relation=sibling
//
// This screen collects ONLY what we still need:
//   1. Guardian's name
//   2. Guardian's phone number (for verification)
//   3. Guardian mode preference (passive / active)
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
import '../../../core/data/country_data.dart';
import '../../../core/models/onboarding_data.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/validation_snackbar.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../widgets/onboarding_scaffold.dart';
import '../widgets/step_header.dart';

// ── Screen ────────────────────────────────────────────────────

class GuardianDetailsScreen extends StatefulWidget {
  const GuardianDetailsScreen({super.key});

  @override
  State<GuardianDetailsScreen> createState() => _GuardianDetailsScreenState();
}

class _GuardianDetailsScreenState extends State<GuardianDetailsScreen> {
  // Guardian name
  final   _nameCtrl     = TextEditingController();

  // Guardian phone
  CountryInfo _selectedCode = kAllCountries.firstWhere(
    (c) => c.iso2 == 'IN',
    orElse: () => kAllCountries.first,
  );
  final   _phoneCtrl    = TextEditingController();

  // Guardian mode preference
  String _guardianMode = 'passive';  // 'passive' or 'active'

  // Derived from previous screen — NOT asked again
  late Gender _candidateGender;
  late String _guardianRelationship;
  late String _candidateLabel;

  bool get _canProceed =>
      _nameCtrl.text.trim().length >= 2 &&
      _phoneCtrl.text.trim().length >= 7;

  @override
  void initState() {
    super.initState();
    // Derive gender and relationship from profileCreatorRelation
    // set on the previous screen (profile_for_whom_screen.dart)
    final data = context.read<OnboardingCubit>().currentData;
    final relation = data.profileCreatorRelation ?? 'son';

    switch (relation) {
      case 'son':
        _candidateGender = Gender.male;
        _guardianRelationship = 'parent';
        _candidateLabel = 'son';
        break;
      case 'daughter':
        _candidateGender = Gender.female;
        _guardianRelationship = 'parent';
        _candidateLabel = 'daughter';
        break;
      case 'brother':
        _candidateGender = Gender.male;
        _guardianRelationship = 'sibling';
        _candidateLabel = 'brother';
        break;
      case 'sister':
        _candidateGender = Gender.female;
        _guardianRelationship = 'sibling';
        _candidateLabel = 'sister';
        break;
      default:
        _candidateGender = Gender.male;
        _guardianRelationship = 'guardian';
        _candidateLabel = 'ward';
    }

    if (data.guardianName != null) {
      _nameCtrl.text = data.guardianName!;
    }
    if (data.guardianPhoneCountryCode != null) {
      _selectedCode = kAllCountries.firstWhere(
        (c) => c.dialCode == data.guardianPhoneCountryCode,
        orElse: () => _selectedCode,
      );
    } else {
      // Auto-detect based on device context if no saved code
      _selectedCode = deviceCountry();
    }
    if (data.guardianPhone != null && data.guardianPhoneCountryCode != null) {
      final dial = data.guardianPhoneCountryCode!;
      if (data.guardianPhone!.startsWith(dial)) {
        _phoneCtrl.text = data.guardianPhone!.substring(dial.length);
      } else {
        _phoneCtrl.text = data.guardianPhone!;
      }
    }
    if (data.guardianMode != null) {
      _guardianMode = data.guardianMode!;
    }
  }

  void _showValidation() {
    final l10n = AppLocalizations.of(context);
    final missing = <String>[];
    if (_nameCtrl.text.trim().length < 2) missing.add(l10n.guardian_details_your_name);
    if (_phoneCtrl.text.trim().length < 7) missing.add(l10n.guardian_details_your_phone);
    showValidationSnackbar(context, missing);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  void _showCodePicker() {
    showModalBottomSheet<void>(
      context:            context,
      backgroundColor:    AppColors.surfaceMid,
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
      gender:                   _candidateGender,
      isGuardianMode:           true,
      guardianName:             _nameCtrl.text.trim(),
      guardianPhone:            guardianPhone,
      guardianPhoneCountryCode: _selectedCode.dialCode,
      guardianRelationship:     _guardianRelationship,
      guardianMode:             _guardianMode,
      guardianAuthorityScope:   _guardianMode == 'active' ? 'full' : 'advisory', // Fixed Flaw 15: Set dynamically
    );
    context.read<OnboardingCubit>().saveAndAdvance(updated);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    // Helper to get localized relationship string
    String getRelationString() {
      switch (_candidateLabel) {
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

    return BlocBuilder<OnboardingCubit, OnboardingState>(
      builder: (context, state) {
        final isLoading = state is OnboardingLoading;
        return OnboardingScaffold(
          ctaLabel:     l10n.legal_button_continue,
          onCta:        _advance,
          isCtaEnabled: _canProceed,
          isCtaLoading: isLoading,
          onCtaDisabledTap: _showValidation,
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
                        l10n.guardian_details_notice(getRelationString()),
                        style: AppTypography.caption.copyWith(height: 1.6),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppDimensions.space28),

              StepHeader(
                title:    l10n.guardian_details_title,
                subtitle: l10n.guardian_details_subtitle,
              ),
              const SizedBox(height: AppDimensions.space32),

              // ── Candidate summary (read-only, derived) ──────────
              Text(l10n.guardian_details_candidate_label, style: AppTypography.sectionLabel),
              const SizedBox(height: AppDimensions.space12),
              Container(
                padding: const EdgeInsets.all(AppDimensions.space16),
                decoration: BoxDecoration(
                  color:        AppColors.surfaceGlass,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
                  border:       Border.all(color: AppColors.cardBorder),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.champagneGold.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _candidateGender == Gender.male
                            ? Icons.male_rounded
                            : Icons.female_rounded,
                        color: AppColors.champagneGold,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: AppDimensions.space14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.guardian_details_candidate_relation(getRelationString()),
                            style: AppTypography.bodyMedium.copyWith(
                              color: AppColors.champagneGold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _candidateGender == Gender.male
                                ? l10n.guardian_details_candidate_male
                                : l10n.guardian_details_candidate_female,
                            style: AppTypography.caption,
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.check_circle_rounded,
                      color: AppColors.verifiedTeal,
                      size: 20,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppDimensions.space28),

              // ── Guardian name ────────────────────────────────────
              Text(l10n.guardian_details_your_name, style: AppTypography.sectionLabel),
              const SizedBox(height: AppDimensions.space8),
              Text(
                l10n.guardian_details_name_subtitle,
                style: AppTypography.caption,
              ),
              const SizedBox(height: AppDimensions.space12),
              Container(
                height: AppDimensions.buttonHeight,
                decoration: BoxDecoration(
                  color:        AppColors.surfaceGlass,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
                  border:       Border.all(color: AppColors.cardBorder),
                ),
                child: TextField(
                  controller:   _nameCtrl,
                  keyboardType: TextInputType.name,
                  textCapitalization: TextCapitalization.words,
                  style:        AppTypography.inputText,
                  onChanged:    (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText:       l10n.guardian_details_name_hint,
                    hintStyle:      AppTypography.inputText.copyWith(
                                      color: AppColors.slateMist),
                    border:         InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppDimensions.space16,
                    ),
                    prefixIcon: const Icon(Icons.person_outline_rounded,
                        color: AppColors.slateMist, size: 20),
                  ),
                ),
              ),

              const SizedBox(height: AppDimensions.space28),

              // ── Guardian phone ──────────────────────────────────
              Text(l10n.guardian_details_your_phone, style: AppTypography.sectionLabel),
              const SizedBox(height: AppDimensions.space8),
              Text(
                l10n.guardian_details_phone_subtitle,
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
                          hintText:       l10n.guardian_details_phone_hint,
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

              // ── Guardian mode ───────────────────────────────────
              Text(l10n.guardian_details_involvement, style: AppTypography.sectionLabel),
              const SizedBox(height: AppDimensions.space8),
              Text(
                l10n.guardian_details_involvement_subtitle,
                style: AppTypography.caption,
              ),
              const SizedBox(height: AppDimensions.space12),

              _ModeCard(
                icon:        Icons.visibility_outlined,
                title:       l10n.guardian_details_mode_passive_title,
                subtitle:    l10n.guardian_details_mode_passive_sub(getRelationString()),
                isSelected:  _guardianMode == 'passive',
                onTap:       () => setState(() => _guardianMode = 'passive'),
              ),
              const SizedBox(height: AppDimensions.space10),
              _ModeCard(
                icon:        Icons.shield_outlined,
                title:       l10n.guardian_details_mode_active_title,
                subtitle:    l10n.guardian_details_mode_active_sub(getRelationString()),
                isSelected:  _guardianMode == 'active',
                onTap:       () => setState(() => _guardianMode = 'active'),
              ),

              const SizedBox(height: AppDimensions.space28),

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
                        l10n.guardian_details_privacy_note(getRelationString()),
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

// ── Guardian Mode Card ────────────────────────────────────────

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  final IconData     icon;
  final String       title;
  final String       subtitle;
  final bool         isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppDimensions.durationTransition,
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.all(AppDimensions.space16),
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width:  40,
              height: 40,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.champagneGold.withValues(alpha: 0.15)
                    : AppColors.surfaceGlassHover,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: isSelected
                    ? AppColors.champagneGold
                    : AppColors.slateMist,
                size: 20,
              ),
            ),
            const SizedBox(width: AppDimensions.space14),
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
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: AppTypography.caption.copyWith(height: 1.5),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppDimensions.space8),
            AnimatedOpacity(
              opacity:  isSelected ? 1.0 : 0.0,
              duration: AppDimensions.durationTransition,
              child: Container(
                width:  22,
                height: 22,
                decoration: const BoxDecoration(
                  color: AppColors.champagneGold,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: AppColors.obsidianNight,
                  size:  14,
                ),
              ),
            ),
          ],
        ),
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
  final CountryInfo selected;
  final ValueChanged<CountryInfo> onSelected;

  @override
  State<_CodePickerSheet> createState() => _CodePickerSheetState();
}

class _CodePickerSheetState extends State<_CodePickerSheet> {
  final _searchCtrl = TextEditingController();
  List<CountryInfo> _filtered = List.unmodifiable(kAllCountries);

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearch(String q) {
    final lower = q.trim().toLowerCase();
    setState(() {
      _filtered = lower.isEmpty
          ? List.unmodifiable(kAllCountries)
          : kAllCountries
              .where((c) =>
                  c.name.toLowerCase().contains(lower) ||
                  c.dialCode.contains(lower))
              .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
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
            Text(l10n.guardian_details_select_code, style: AppTypography.bodyMedium),
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
                  hintText:  l10n.guardian_details_search_hint,
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
