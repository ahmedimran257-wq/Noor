// lib/features/onboarding/screens/basic_identity_screen.dart
// ============================================================
// NOOR — Basic Identity Screen (Onboarding Step 1)
// First name, last name, date of birth, gender, city search,
// height stepper, complexion (optional), community (optional),
// mother tongue (required, country-based),
// residency status (optional), special needs (optional).
// Phase 2: DemographicsConfig + CopyEngine integrated.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:country_state_city/country_state_city.dart' as csc;

import '../../../core/data/country_data.dart';
import '../../../core/services/country_context_service.dart';
import '../../../core/cubits/auth/auth_cubit.dart';
import '../../../core/cubits/onboarding/onboarding_cubit.dart';
import '../../../core/cubits/onboarding/onboarding_state.dart';
import '../../../core/models/onboarding_data.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/copy_engine.dart';
import '../../../core/utils/validation_snackbar.dart';
import '../../../core/widgets/inputs/noor_text_field.dart';
import '../widgets/onboarding_scaffold.dart';
import '../widgets/step_header.dart';

// ── City data — 300+ cities with country metadata ─────────────

/// Each map has keys: 'name', 'country' (ISO-2), 'countryName'.
// ── Complexion options ─────────────────────────────────────────

const _kComplexions = <String>[
  'Fair', 'Medium', 'Olive', 'Dark', 'Prefer not to say',
];

// ── Residency status options ──────────────────────────────────

const _kResidencyOptions = <String>[
  'Citizen', 'Permanent Resident', 'Work Visa', 'Student Visa', 'Other', 'Prefer not to say',
];

// ── Special needs options ─────────────────────────────────────

const _kSpecialNeedsOptions = <String>[
  'None', 'Physical disability', 'Hearing impairment', 'Visual impairment', 'Other', 'Prefer not to say',
];



// ── Screen ────────────────────────────────────────────────────

class BasicIdentityScreen extends StatefulWidget {
  const BasicIdentityScreen({super.key});

  @override
  State<BasicIdentityScreen> createState() => _BasicIdentityScreenState();
}

class _BasicIdentityScreenState extends State<BasicIdentityScreen> {
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl  = TextEditingController();
  DateTime? _dob;
  Gender?   _gender;
  String    _dobError = '';

  // City search
  String? _selectedCity;
  String? _selectedCityId;
  String? _selectedCountryCode;
  String? _selectedCountryName;
  String? _selectedStateName;
  String? _selectedStateCode;

  // Demographics from CountryContextService
  List<String> _loadedLanguages = ['English', 'Arabic', 'Other'];
  List<String> _loadedCommunities = ['Prefer not to say'];



  // New fields
  int     _heightCm     = 165;
  String? _complexion;
  String? _motherTongue;
  String? _community; // Phase 2 — optional
  String? _residencyStatus; // Phase 1 — optional
  String? _specialNeeds;    // Phase 1 — optional

  // Guardian mode — derived from previous screens
  bool _isGuardianMode = false;
  bool _genderLocked   = false;  // true if gender was pre-filled by guardian flow
  String _candidateLabel = '';   // 'son', 'daughter', 'brother', 'sister'

  @override
  void initState() {
    super.initState();
    final data = context.read<OnboardingCubit>().currentData;
    _isGuardianMode = data.isGuardianMode;
    _candidateLabel = data.profileCreatorRelation ?? 'self';

    if (_isGuardianMode && data.gender != null) {
      _gender = data.gender;
      _genderLocked = true;
    } else {
      _gender = data.gender;
    }

    _firstNameCtrl.text = data.firstName ?? '';
    _lastNameCtrl.text = data.lastName ?? '';
    _dob = data.dateOfBirth;
    _heightCm = data.heightCm ?? 165;
    _complexion = data.complexion;
    _motherTongue = data.motherTongue;
    _community = data.community;
    _residencyStatus = data.residencyStatus;
    _specialNeeds = data.specialNeeds;

    if (data.countryCode != null) {
      _selectedCountryCode = data.countryCode;
      final match = kAllCountries.where((c) => c.iso2.toUpperCase() == _selectedCountryCode!.toUpperCase());
      if (match.isNotEmpty) {
        _selectedCountryName = match.first.name;
      }
      _fetchDemographics(_selectedCountryCode!);
    }

    if (data.cityName != null) {
      final parts = data.cityName!.split(', ');
      if (parts.length > 1) {
        _selectedCity = parts[0];
        _selectedStateName = parts[1];
      } else {
        _selectedCity = data.cityName;
      }
      _selectedCityId = data.cityId;
    }
  }

  Future<void> _fetchDemographics(String countryCode) async {
    final ctx = await CountryContextService.instance.getContext(countryCode);
    if (!mounted) return;
    setState(() {
      _loadedLanguages = ctx.languages;
      _loadedCommunities = [...ctx.communities];
      if (!_loadedCommunities.contains('Prefer not to say')) {
        _loadedCommunities.add('Prefer not to say');
      }
    });
  }


  String get _creatorRelation =>
      context.read<OnboardingCubit>().currentData.profileCreatorRelation ?? 'self';

  bool get _canProceed =>
      _firstNameCtrl.text.trim().isNotEmpty &&
      _lastNameCtrl.text.trim().isNotEmpty &&
      _dob != null &&
      _dobError.isEmpty &&
      _gender != null &&
      _selectedCountryCode != null &&
      _selectedStateName != null &&
      _selectedCity != null &&
      _motherTongue != null;

  void _showValidation() {
    final missing = <String>[];
    final nameSubject = _isGuardianMode ? "Candidate's first" : 'First';
    if (_firstNameCtrl.text.trim().isEmpty) missing.add('$nameSubject name');
    if (_lastNameCtrl.text.trim().isEmpty) missing.add('Last name');
    if (_dob == null) missing.add('Date of birth');
    if (_dobError.isNotEmpty) missing.add('Valid date of birth (18+)');
    if (_gender == null) missing.add('Gender');
    if (_selectedCountryCode == null) missing.add('Country');
    if (_selectedStateName == null) missing.add('State / Region');
    if (_selectedCity == null) missing.add('City');
    if (_motherTongue == null) missing.add('Mother tongue');
    showValidationSnackbar(context, missing);
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    super.dispose();
  }

  void _pickDob() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 365 * 25)),
      firstDate:   DateTime(1940),
      lastDate:    DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary:   AppColors.champagneGold,
              onPrimary: AppColors.obsidianNight,
              surface:   Color(0xFF12121A),
              onSurface: AppColors.pearlWhite,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked == null) return;
    final age = _calcAge(picked);
    setState(() {
      _dob      = picked;
      _dobError = age < 18
          ? _isGuardianMode
              ? 'Your $_candidateLabel must be 18 or older to use NOOR.'
              : 'You must be 18 or older to use NOOR. We look forward to welcoming you then.'
          : '';
    });
  }

  int _calcAge(DateTime dob) {
    final now = DateTime.now();
    int years = now.year - dob.year;
    if (now.month < dob.month ||
        (now.month == dob.month && now.day < dob.day)) { years--; }
    return years;
  }

  String _formatDob(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')} / '
      '${d.month.toString().padLeft(2, '0')} / '
      '${d.year}';


  void _showMotherTonguePicker() {
    showModalBottomSheet<void>(
      context:            context,
      backgroundColor:    const Color(0xFF12121A),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _GenericListPicker(
        title:      'Mother Tongue',
        options:    _loadedLanguages,
        selected:   _motherTongue,
        onSelected: (v) {
          setState(() => _motherTongue = v);
          Navigator.pop(context);
        },
      ),
    );
  }

  void _showCommunityPicker() {
    showModalBottomSheet<void>(
      context:            context,
      backgroundColor:    const Color(0xFF12121A),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _GenericListPicker(
        title:      CopyEngine.communityQuestion(_creatorRelation),
        options:    _loadedCommunities,
        selected:   _community,
        onSelected: (v) {
          setState(() => _community = v);
          Navigator.pop(context);
        },
      ),
    );
  }


  void _showStatePicker() {
    if (_selectedCountryCode == null) return;
    showModalBottomSheet<void>(
      context:            context,
      backgroundColor:    const Color(0xFF12121A),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _LocationPickerSheet(
        title:      'Select State / Province',
        selectedName: _selectedStateName,
        fetchItems: () async {
          final states = await csc.getStatesOfCountry(_selectedCountryCode!);
          return states.map((s) => {
            'name': s.name,
            'code': s.isoCode,
          }).toList();
        },
        onSelected: (v) {
          final code = v['code']!;
          final name = v['name']!;
          setState(() {
            _selectedStateCode = code;
            _selectedStateName = name;
            _selectedCity      = null;
            _selectedCityId    = null;
          });
          Navigator.pop(context);
        },
      ),
    );
  }

  void _showCityPicker() {
    if (_selectedCountryCode == null || _selectedStateCode == null) return;
    showModalBottomSheet<void>(
      context:            context,
      backgroundColor:    const Color(0xFF12121A),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _LocationPickerSheet(
        title:      'Select City',
        selectedName: _selectedCity,
        fetchItems: () async {
          final cities = await csc.getStateCities(_selectedCountryCode!, _selectedStateCode!);
          return cities.map((c) => {
            'name': c.name,
            'code': c.name,
          }).toList();
        },
        onSelected: (v) {
          final name = v['name']!;
          setState(() {
            _selectedCity   = name;
            _selectedCityId = name.toLowerCase();
          });
          Navigator.pop(context);
        },
      ),
    );
  }


  void _advance() async {
    final countryCode = _selectedCountryCode ?? 'XX';
    final cityName = _selectedStateName != null && _selectedStateName!.isNotEmpty
        ? '$_selectedCity, $_selectedStateName'
        : (_selectedCity ?? '');
    final data = context.read<OnboardingCubit>().currentData.copyWith(
      firstName:    _firstNameCtrl.text.trim(),
      lastName:     _lastNameCtrl.text.trim(),
      dateOfBirth:  _dob,
      gender:       _gender,
      cityName:     cityName,
      cityId:       _selectedCityId ?? cityName.toLowerCase(),
      countryCode:  countryCode,
      heightCm:        _heightCm,
      complexion:      _complexion,
      motherTongue:    _motherTongue,
      community:       _community,
      residencyStatus: _residencyStatus,
      specialNeeds:    _specialNeeds,
    );

    // ── Gender & Country propagation ──────────────────────────
    // Propagate gender to AuthCubit NOW so all subscription gates read the correct value immediately.
    // Fixed Flaw 20: Avoid calling setGender twice in guardian flow.
    if (_gender != null && !_isGuardianMode) {
      context.read<AuthCubit>().setGender(
          _gender == Gender.female ? 'female' : 'male');
    }

    // Save country code for regional pricing (subscription screen)
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_country_code', countryCode);

    if (mounted) {
      context.read<AuthCubit>().setCountryCode(countryCode);
    }

    if (mounted) {
      context.read<OnboardingCubit>().saveAndAdvance(data);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<OnboardingCubit, OnboardingState>(
      builder: (context, state) {
        final isLoading = state is OnboardingLoading;
        return OnboardingScaffold(
          ctaLabel:      'Continue',
          onCta:         _advance,
          isCtaEnabled:  _canProceed,
          isCtaLoading:  isLoading,
          onCtaDisabledTap: _showValidation,
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppDimensions.space32),

              // Guardian mode banner
              if (_isGuardianMode) ...[
                Container(
                  padding: const EdgeInsets.all(AppDimensions.space14),
                  decoration: BoxDecoration(
                    color:        AppColors.champagneGold.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
                    border:       Border.all(color: AppColors.goldBorder),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.shield_outlined,
                          color: AppColors.champagneGold, size: 16),
                      const SizedBox(width: AppDimensions.space10),
                      Expanded(
                        child: Text(
                          'You are filling this as a guardian. '
                          'These details are about your $_candidateLabel.',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.champagneGold,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppDimensions.space20),
              ],

              StepHeader(
                title: _isGuardianMode
                    ? 'Tell us about your $_candidateLabel'
                    : 'Tell us about yourself',
                subtitle: _isGuardianMode
                    ? 'This is what others will see on their profile.'
                    : 'This is what others will see on your profile.',
              ),
              const SizedBox(height: AppDimensions.space32),

              // Name row
              Row(
                children: [
                  Expanded(
                    child: NoorTextField(
                      controller:         _firstNameCtrl,
                      label:              _isGuardianMode
                                              ? "Candidate's first name"
                                              : 'First name',
                      textCapitalization: TextCapitalization.words,
                      textInputAction:    TextInputAction.next,
                      onChanged:          (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: AppDimensions.space12),
                  Expanded(
                    child: NoorTextField(
                      controller:         _lastNameCtrl,
                      label:              _isGuardianMode
                                              ? 'Last name'
                                              : 'Last name',
                      textCapitalization: TextCapitalization.words,
                      textInputAction:    TextInputAction.next,
                      onChanged:          (_) => setState(() {}),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: AppDimensions.space20),

              // Date of birth
              const Text('DATE OF BIRTH', style: AppTypography.sectionLabel),
              const SizedBox(height: AppDimensions.space8),
              GestureDetector(
                onTap: _pickDob,
                child: Container(
                  height: AppDimensions.buttonHeight,
                  padding: const EdgeInsetsDirectional.symmetric(
                    horizontal: AppDimensions.space16,
                  ),
                  decoration: BoxDecoration(
                    color:        AppColors.inputSurface,
                    borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined,
                          color: AppColors.slateMist,
                          size:  AppDimensions.iconSizeMedium),
                      const SizedBox(width: AppDimensions.space12),
                      Text(
                        _dob != null ? _formatDob(_dob!) : 'Select date of birth',
                        style: _dob != null
                            ? AppTypography.inputText
                            : AppTypography.inputText.copyWith(
                                color: AppColors.slateMist),
                      ),
                    ],
                  ),
                ),
              ),
              if (_dobError.isNotEmpty) ...[
                const SizedBox(height: AppDimensions.space8),
                Text(_dobError,
                    style: AppTypography.caption.copyWith(
                        color: AppColors.softCoral)),
              ],

              const SizedBox(height: AppDimensions.space20),

              // Gender
              Text(
                _isGuardianMode ? "CANDIDATE'S GENDER" : 'GENDER',
                style: AppTypography.sectionLabel,
              ),
              const SizedBox(height: AppDimensions.space8),
              if (_genderLocked) ...[
                // Gender is pre-set by guardian flow — show read-only
                Container(
                  height: AppDimensions.buttonHeight,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.space16,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.champagneGold.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
                    border: Border.all(color: AppColors.champagneGold),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _gender == Gender.male
                            ? Icons.male_rounded
                            : Icons.female_rounded,
                        color: AppColors.champagneGold,
                        size: 20,
                      ),
                      const SizedBox(width: AppDimensions.space12),
                      Text(
                        _gender == Gender.male ? 'Male' : 'Female',
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.champagneGold,
                        ),
                      ),
                      const Spacer(),
                      const Icon(
                        Icons.lock_outline_rounded,
                        color: AppColors.slateMist,
                        size: 14,
                      ),
                    ],
                  ),
                ),
              ] else ...[
                Row(
                  children: [
                    Expanded(
                      child: _GenderPill(
                        label:      'Male',
                        icon:       Icons.male_rounded,
                        isSelected: _gender == Gender.male,
                        onTap:      () => setState(() => _gender = Gender.male),
                      ),
                    ),
                    const SizedBox(width: AppDimensions.space12),
                    Expanded(
                      child: _GenderPill(
                        label:      'Female',
                        icon:       Icons.female_rounded,
                        isSelected: _gender == Gender.female,
                        onTap:      () => setState(() => _gender = Gender.female),
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: AppDimensions.space20),

              // ── Country Selector ──────────────────────────────────
              Text(_isGuardianMode ? 'THEIR COUNTRY' : 'YOUR COUNTRY', style: AppTypography.sectionLabel),
              const SizedBox(height: AppDimensions.space12),
              Container(
                height: AppDimensions.buttonHeight,
                padding: const EdgeInsets.symmetric(horizontal: AppDimensions.space16),
                decoration: BoxDecoration(
                  color: AppColors.champagneGold.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
                  border: Border.all(color: AppColors.champagneGold),
                ),
                child: Row(children: [
                  const Icon(Icons.public_rounded,
                      color: AppColors.champagneGold,
                      size: AppDimensions.iconSizeMedium),
                  const SizedBox(width: AppDimensions.space12),
                  Expanded(child: Text(
                    _selectedCountryName ?? 'Select country',
                    style: AppTypography.inputText.copyWith(
                      color: AppColors.champagneGold,
                    ),
                  )),
                  const Icon(
                    Icons.lock_outline_rounded,
                    color: AppColors.slateMist,
                    size: 14,
                  ),
                ]),
              ),

              const SizedBox(height: AppDimensions.space20),

              // ── State Selector ───────────────────────────────────
              Text(_isGuardianMode ? 'THEIR STATE / PROVINCE' : 'YOUR STATE / PROVINCE', style: AppTypography.sectionLabel),
              const SizedBox(height: AppDimensions.space12),
              GestureDetector(
                onTap: _selectedCountryCode != null ? _showStatePicker : null,
                child: Opacity(
                  opacity: _selectedCountryCode != null ? 1.0 : 0.5,
                  child: Container(
                    height: AppDimensions.buttonHeight,
                    padding: const EdgeInsets.symmetric(horizontal: AppDimensions.space16),
                    decoration: BoxDecoration(
                      color: AppColors.inputSurface,
                      borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
                      border: Border.all(
                        color: _selectedStateName != null ? AppColors.champagneGold : AppColors.cardBorder,
                        width: _selectedStateName != null ? AppDimensions.borderFocus : AppDimensions.borderThin,
                      ),
                    ),
                    child: Row(children: [
                      Icon(Icons.map_outlined,
                          color: _selectedStateName != null ? AppColors.champagneGold : AppColors.slateMist,
                          size: AppDimensions.iconSizeMedium),
                      const SizedBox(width: AppDimensions.space12),
                      Expanded(child: Text(
                        _selectedStateName ?? (_selectedCountryCode == null ? 'Select country first' : 'Select state / province'),
                        style: AppTypography.inputText.copyWith(
                          color: _selectedStateName != null ? AppColors.pearlWhite : AppColors.slateMist,
                        ),
                      )),
                      const Icon(Icons.expand_more_rounded, color: AppColors.slateMist),
                    ]),
                  ),
                ),
              ),

              const SizedBox(height: AppDimensions.space20),

              // ── City Selector ────────────────────────────────────
              Text(_isGuardianMode ? 'THEIR CITY' : 'YOUR CITY', style: AppTypography.sectionLabel),
              const SizedBox(height: AppDimensions.space12),
              GestureDetector(
                onTap: _selectedStateName != null ? _showCityPicker : null,
                child: Opacity(
                  opacity: _selectedStateName != null ? 1.0 : 0.5,
                  child: Container(
                    height: AppDimensions.buttonHeight,
                    padding: const EdgeInsets.symmetric(horizontal: AppDimensions.space16),
                    decoration: BoxDecoration(
                      color: AppColors.inputSurface,
                      borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
                      border: Border.all(
                        color: _selectedCity != null ? AppColors.champagneGold : AppColors.cardBorder,
                        width: _selectedCity != null ? AppDimensions.borderFocus : AppDimensions.borderThin,
                      ),
                    ),
                    child: Row(children: [
                      Icon(Icons.location_city_rounded,
                          color: _selectedCity != null ? AppColors.champagneGold : AppColors.slateMist,
                          size: AppDimensions.iconSizeMedium),
                      const SizedBox(width: AppDimensions.space12),
                      Expanded(child: Text(
                        _selectedCity ?? (_selectedStateName == null ? 'Select state first' : 'Select city'),
                        style: AppTypography.inputText.copyWith(
                          color: _selectedCity != null ? AppColors.pearlWhite : AppColors.slateMist,
                        ),
                      )),
                      const Icon(Icons.expand_more_rounded, color: AppColors.slateMist),
                    ]),
                  ),
                ),
              ),


              // Premium Confirmed Location Card
              if (_selectedCity != null) ...[
                const SizedBox(height: AppDimensions.space12),
                Container(
                  padding: const EdgeInsets.all(AppDimensions.space16),
                  decoration: BoxDecoration(
                    color: AppColors.inputSurface,
                    borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
                    border: Border.all(color: AppColors.champagneGold.withValues(alpha: 0.3)),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.champagneGold.withValues(alpha: 0.05),
                        blurRadius: 16,
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.check_circle_rounded,
                              color: AppColors.champagneGold, size: 18),
                          const SizedBox(width: AppDimensions.space8),
                          Text('Confirmed Location', style: AppTypography.captionMedium.copyWith(color: AppColors.champagneGold)),
                        ],
                      ),
                      const SizedBox(height: AppDimensions.space16),
                      // City
                      Row(
                        children: [
                          const Icon(Icons.location_city_rounded, color: AppColors.slateMist, size: 18),
                          const SizedBox(width: AppDimensions.space12),
                          const Text('City', style: AppTypography.inputLabel),
                          const Spacer(),
                          Text(_selectedCity!, style: AppTypography.bodyMedium),
                        ],
                      ),
                      // State
                      if (_selectedStateName != null && _selectedStateName!.isNotEmpty) ...[
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8.0),
                          child: Divider(color: AppColors.cardBorder, height: 1),
                        ),
                        Row(
                          children: [
                            const Icon(Icons.map_outlined, color: AppColors.slateMist, size: 18),
                            const SizedBox(width: AppDimensions.space12),
                            const Text('State / Region', style: AppTypography.inputLabel),
                            const Spacer(),
                            Text(_selectedStateName!, style: AppTypography.bodyMedium),
                          ],
                        ),
                      ],
                      // Country
                      if (_selectedCountryName != null) ...[
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8.0),
                          child: Divider(color: AppColors.cardBorder, height: 1),
                        ),
                        Row(
                          children: [
                            const Icon(Icons.public, color: AppColors.slateMist, size: 18),
                            const SizedBox(width: AppDimensions.space12),
                            const Text('Country', style: AppTypography.inputLabel),
                            const Spacer(),
                            Text(_selectedCountryName!, style: AppTypography.bodyMedium),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],

              const SizedBox(height: AppDimensions.space28),

              // ── COMMUNITY / BIRADARI (Optional) ────────────────────
              Builder(builder: (ctx) {
                final rel = ctx.read<OnboardingCubit>().currentData.profileCreatorRelation ?? 'self';
                return Text('${CopyEngine.communityQuestion(rel).toUpperCase()}  (Optional)', style: AppTypography.sectionLabel);
              }),
              const SizedBox(height: AppDimensions.space12),
              GestureDetector(
                onTap: _showCommunityPicker,
                child: Container(
                  height: AppDimensions.buttonHeight,
                  padding: const EdgeInsets.symmetric(horizontal: AppDimensions.space16),
                  decoration: BoxDecoration(
                    color: AppColors.inputSurface,
                    borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
                    border: Border.all(
                      color: _community != null ? AppColors.champagneGold : AppColors.cardBorder,
                      width: _community != null ? AppDimensions.borderFocus : AppDimensions.borderThin,
                    ),
                  ),
                  child: Row(children: [
                    Icon(Icons.groups_outlined,
                        color: _community != null ? AppColors.champagneGold : AppColors.slateMist,
                        size: AppDimensions.iconSizeMedium),
                    const SizedBox(width: AppDimensions.space12),
                    Expanded(child: Text(
                      _community ?? 'Select community (optional)',
                      style: AppTypography.inputText.copyWith(
                        color: _community != null ? AppColors.pearlWhite : AppColors.slateMist,
                      ),
                    )),
                    const Icon(Icons.expand_more_rounded, color: AppColors.slateMist),
                  ]),
                ),
              ),

              const SizedBox(height: AppDimensions.space28),

              // ── HEIGHT ─────────────────────────────────────────────
              Text(_isGuardianMode ? 'THEIR HEIGHT' : 'YOUR HEIGHT',
                  style: AppTypography.sectionLabel),
              const SizedBox(height: AppDimensions.space12),
              _HeightStepper(
                heightCm: _heightCm,
                onChanged: (v) => setState(() => _heightCm = v),
              ),

              const SizedBox(height: AppDimensions.space24),

              // ── COMPLEXION (Optional) ──────────────────────────────
              const Text('COMPLEXION  (Optional)', style: AppTypography.sectionLabel),
              const SizedBox(height: AppDimensions.space12),
              Wrap(
                spacing:    AppDimensions.space8,
                runSpacing: AppDimensions.space8,
                children: _kComplexions.map((o) => _SelectChip(
                  label:      o,
                  isSelected: _complexion == o,
                  onTap: () => setState(() =>
                      _complexion = _complexion == o ? null : o),
                )).toList(),
              ),

              const SizedBox(height: AppDimensions.space24),

              // ── MOTHER TONGUE (Required) ───────────────────────────
              const Text('MOTHER TONGUE', style: AppTypography.sectionLabel),
              const SizedBox(height: AppDimensions.space12),
              GestureDetector(
                onTap: _showMotherTonguePicker,
                child: Container(
                  height: AppDimensions.buttonHeight,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.space16,
                  ),
                  decoration: BoxDecoration(
                    color:        AppColors.inputSurface,
                    borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
                    border: Border.all(
                      color: _motherTongue != null
                          ? AppColors.champagneGold
                          : AppColors.cardBorder,
                      width: _motherTongue != null
                          ? AppDimensions.borderFocus
                          : AppDimensions.borderThin,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.translate_rounded,
                          color: _motherTongue != null
                              ? AppColors.champagneGold
                              : AppColors.slateMist,
                          size: AppDimensions.iconSizeMedium),
                      const SizedBox(width: AppDimensions.space12),
                      Expanded(
                        child: Text(
                          _motherTongue ?? 'Select language',
                          style: AppTypography.inputText.copyWith(
                            color: _motherTongue != null
                                ? AppColors.pearlWhite
                                : AppColors.slateMist,
                          ),
                        ),
                      ),
                      const Icon(Icons.expand_more_rounded,
                          color: AppColors.slateMist),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: AppDimensions.space28),

              // ── RESIDENCY STATUS (Optional) ─────────────────────────
              const Text('RESIDENCY STATUS  (Optional)', style: AppTypography.sectionLabel),
              const SizedBox(height: AppDimensions.space12),
              Wrap(
                spacing:    AppDimensions.space8,
                runSpacing: AppDimensions.space8,
                children: _kResidencyOptions.map((o) => _SelectChip(
                  label:      o,
                  isSelected: _residencyStatus == o,
                  onTap: () => setState(() =>
                      _residencyStatus = _residencyStatus == o ? null : o),
                )).toList(),
              ),

              const SizedBox(height: AppDimensions.space28),

              // ── SPECIAL NEEDS (Optional) ─────────────────────────────
              const Text('SPECIAL NEEDS  (Optional)', style: AppTypography.sectionLabel),
              const SizedBox(height: AppDimensions.space4),
              Container(
                padding: const EdgeInsets.all(AppDimensions.space10),
                decoration: BoxDecoration(
                  color: AppColors.surfaceGlass,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusChip),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.lock_outline_rounded,
                        color: AppColors.slateMist, size: 14),
                    SizedBox(width: AppDimensions.space8),
                    Expanded(
                      child: Text(
                        'This is only shared after mutual interest.',
                        style: AppTypography.caption,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppDimensions.space12),
              Wrap(
                spacing:    AppDimensions.space8,
                runSpacing: AppDimensions.space8,
                children: _kSpecialNeedsOptions.map((o) => _SelectChip(
                  label:      o,
                  isSelected: _specialNeeds == o,
                  onTap: () => setState(() =>
                      _specialNeeds = _specialNeeds == o ? null : o),
                )).toList(),
              ),

              const SizedBox(height: AppDimensions.space32),
            ],
          ),
        );
      },
    );
  }
}

// ── Gender pill button ────────────────────────────────────────

class _GenderPill extends StatelessWidget {
  const _GenderPill({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppDimensions.durationTransition,
        height: AppDimensions.buttonHeight,
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.champagneGold.withValues(alpha: 0.1)
              : AppColors.surfaceGlass,
          borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
          border: Border.all(
            color: isSelected ? AppColors.champagneGold : AppColors.cardBorder,
            width: isSelected ? AppDimensions.borderFocus : AppDimensions.borderThin,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                color: isSelected
                    ? AppColors.champagneGold
                    : AppColors.slateMist,
                size: AppDimensions.iconSizeMedium),
            const SizedBox(width: AppDimensions.space8),
            Text(label,
                style: AppTypography.bodyMedium.copyWith(
                  color: isSelected
                      ? AppColors.champagneGold
                      : AppColors.pearlWhite,
                )),
          ],
        ),
      ),
    );
  }
}

// ── Height Stepper ────────────────────────────────────────────

class _HeightStepper extends StatelessWidget {
  const _HeightStepper({
    required this.heightCm,
    required this.onChanged,
  });
  final int heightCm;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.space16,
        vertical:   AppDimensions.space12,
      ),
      decoration: BoxDecoration(
        color:        AppColors.inputSurface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
        border:       Border.all(color: AppColors.goldBorder),
      ),
      child: Row(
        children: [
          // Minus button
          _StepperButton(
            icon:    Icons.remove_rounded,
            onTap:   heightCm > 140 ? () => onChanged(heightCm - 1) : null,
          ),
          const SizedBox(width: AppDimensions.space12),

          // Height display
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$heightCm cm',
                  style: AppTypography.bodyMedium.copyWith(
                    color:      AppColors.champagneGold,
                    fontSize:   22,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 2),
                Text(
                  _feetInchDisplay(heightCm),
                  style: AppTypography.caption,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          const SizedBox(width: AppDimensions.space12),
          // Plus button
          _StepperButton(
            icon:  Icons.add_rounded,
            onTap: heightCm < 210 ? () => onChanged(heightCm + 1) : null,
          ),
        ],
      ),
    );
  }

  String _feetInchDisplay(int cm) {
    final totalInches = cm / 2.54;
    final feet        = totalInches ~/ 12;
    final inches      = totalInches.round() % 12;
    return '$feet ft $inches in';
  }
}

class _StepperButton extends StatelessWidget {
  const _StepperButton({required this.icon, required this.onTap});
  final IconData     icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width:  40,
        height: 40,
        decoration: BoxDecoration(
          color: enabled
              ? AppColors.champagneGold.withValues(alpha: 0.12)
              : AppColors.surfaceGlassHover,
          shape:  BoxShape.circle,
          border: Border.all(
            color: enabled ? AppColors.goldBorder : AppColors.cardBorder,
          ),
        ),
        child: Icon(icon,
          color: enabled ? AppColors.champagneGold : AppColors.slateMist,
          size:  20,
        ),
      ),
    );
  }
}

// ── Select Chip ───────────────────────────────────────────────

class _SelectChip extends StatelessWidget {
  const _SelectChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });
  final String label;
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
        child: Text(
          label,
          style: AppTypography.chipLabel.copyWith(
            color: isSelected ? AppColors.champagneGold : AppColors.pearlWhite,
          ),
        ),
      ),
    );
  }
}

// ── Generic List Picker sheet (replaces _MotherTonguePicker) ──
// Used for both Mother Tongue and Community pickers.
// Accepts any List<String> as options.

class _GenericListPicker extends StatefulWidget {
  const _GenericListPicker({
    required this.title,
    required this.options,
    required this.selected,
    required this.onSelected,
  });
  final String title;
  final List<String> options;
  final String? selected;
  final ValueChanged<String> onSelected;

  @override
  State<_GenericListPicker> createState() => _GenericListPickerState();
}

class _GenericListPickerState extends State<_GenericListPicker> {
  final _searchCtrl = TextEditingController();
  late List<String> _filtered;

  @override
  void initState() {
    super.initState();
    _filtered = List.from(widget.options);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearch(String q) {
    final lower = q.trim().toLowerCase();
    setState(() {
      _filtered = lower.isEmpty
          ? List.from(widget.options)
          : widget.options.where((l) => l.toLowerCase().contains(lower)).toList();
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
                color: AppColors.slateMist.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: AppDimensions.space16),
            Text(widget.title, style: AppTypography.bodyMedium),
            const SizedBox(height: AppDimensions.space12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppDimensions.space16),
              child: TextField(
                controller: _searchCtrl,
                onChanged:  _onSearch,
                style:      AppTypography.inputText,
                decoration: InputDecoration(
                  hintText:  'Search…',
                  hintStyle: AppTypography.inputLabel,
                  prefixIcon: const Icon(Icons.search_rounded, color: AppColors.slateMist, size: 20),
                  filled: true, fillColor: AppColors.inputSurface,
                  contentPadding: const EdgeInsets.symmetric(horizontal: AppDimensions.space12, vertical: AppDimensions.space10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppDimensions.radiusButton), borderSide: const BorderSide(color: AppColors.cardBorder)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppDimensions.radiusButton), borderSide: const BorderSide(color: AppColors.cardBorder)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppDimensions.radiusButton), borderSide: const BorderSide(color: AppColors.champagneGold, width: AppDimensions.borderFocus)),
                ),
              ),
            ),
            const SizedBox(height: AppDimensions.space8),
            Flexible(
              child: _filtered.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(AppDimensions.space24),
                      child: Text('Nothing found.', style: AppTypography.bodyMuted, textAlign: TextAlign.center),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      physics: const BouncingScrollPhysics(),
                      itemCount: _filtered.length,
                      itemBuilder: (_, i) {
                        final item = _filtered[i];
                        final isSel = item == widget.selected;
                        return ListTile(
                          title: Text(item, style: AppTypography.body),
                          trailing: isSel ? const Icon(Icons.check_rounded, color: AppColors.champagneGold, size: 20) : null,
                          selected: isSel,
                          selectedColor: AppColors.champagneGold,
                          onTap: () => widget.onSelected(item),
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

// ── Reusable Premium Location Picker Sheet ─────────────────────
// Uses country_state_city package offline data dynamically.

class _LocationPickerSheet extends StatefulWidget {
  const _LocationPickerSheet({
    required this.title,
    required this.fetchItems,
    required this.selectedName,
    required this.onSelected,
  });
  final String title;
  final Future<List<Map<String, String>>> Function() fetchItems;
  final String? selectedName;
  final ValueChanged<Map<String, String>> onSelected;

  @override
  State<_LocationPickerSheet> createState() => _LocationPickerSheetState();
}

class _LocationPickerSheetState extends State<_LocationPickerSheet> {
  final _searchCtrl = TextEditingController();
  List<Map<String, String>> _all = [];
  List<Map<String, String>> _filtered = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final items = await widget.fetchItems();
      if (mounted) {
        setState(() {
          _all = items;
          _filtered = items;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _onSearch(String q) {
    final lower = q.trim().toLowerCase();
    setState(() {
      _filtered = lower.isEmpty
          ? _all
          : _all.where((item) => item['name']!.toLowerCase().contains(lower)).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: bottom),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.75,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: AppDimensions.space16),
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: AppColors.slateMist.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: AppDimensions.space16),
              Text(widget.title, style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w600, fontSize: 18)),
              const SizedBox(height: AppDimensions.space12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppDimensions.space16),
                child: TextField(
                  controller: _searchCtrl,
                  onChanged:  _onSearch,
                  style:      AppTypography.inputText,
                  decoration: InputDecoration(
                    hintText:  'Search…',
                    hintStyle: AppTypography.inputLabel,
                    prefixIcon: const Icon(Icons.search_rounded, color: AppColors.slateMist, size: 20),
                    filled: true, fillColor: AppColors.inputSurface,
                    contentPadding: const EdgeInsets.symmetric(horizontal: AppDimensions.space12, vertical: AppDimensions.space10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppDimensions.radiusButton), borderSide: const BorderSide(color: AppColors.cardBorder)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppDimensions.radiusButton), borderSide: const BorderSide(color: AppColors.cardBorder)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppDimensions.radiusButton), borderSide: const BorderSide(color: AppColors.champagneGold, width: AppDimensions.borderFocus)),
                  ),
                ),
              ),
              const SizedBox(height: AppDimensions.space8),
              Flexible(
                child: _loading
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(AppDimensions.space24),
                          child: CircularProgressIndicator(color: AppColors.champagneGold),
                        ),
                      )
                    : _filtered.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.all(AppDimensions.space24),
                            child: Text('Nothing found.', style: AppTypography.bodyMuted, textAlign: TextAlign.center),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            physics: const BouncingScrollPhysics(),
                            itemCount: _filtered.length,
                            itemBuilder: (_, i) {
                              final item = _filtered[i];
                              final name = item['name']!;
                              final isSel = name == widget.selectedName;
                              return ListTile(
                                title: Text(name, style: AppTypography.body),
                                trailing: isSel ? const Icon(Icons.check_rounded, color: AppColors.champagneGold, size: 20) : null,
                                selected: isSel,
                                selectedColor: AppColors.champagneGold,
                                onTap: () => widget.onSelected(item),
                              );
                            },
                          ),
              ),
              const SizedBox(height: AppDimensions.space16),
            ],
          ),
        ),
      ),
    );
  }
}
