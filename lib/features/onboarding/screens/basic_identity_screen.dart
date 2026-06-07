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
import 'package:noor/l10n/generated/app_localizations.dart';
import '../../../core/widgets/inputs/city_search_field.dart';

import '../../../core/data/country_data.dart';
import '../../../core/services/country_context_service.dart';
import '../../../core/services/supabase_service.dart';
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
  final _stateCtrl     = TextEditingController();
  DateTime? _dob;
  Gender?   _gender;
  String    _dobError = '';

  // City search
  String? _selectedCity;
  String? _selectedCityId;
  String? _selectedCountryCode;
  String? _selectedCountryName;
  String? _selectedStateName;

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
  String? _postalCode;
  double? _lat;
  double? _lng;

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
        _stateCtrl.text = parts[1];
      } else {
        _selectedCity = data.cityName;
      }
      _selectedCityId = data.cityId;
    }
    _postalCode = data.postalCode;
    _lat = data.lat;
    _lng = data.lng;
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
      _selectedCity != null &&
      _selectedStateName != null &&
      _selectedStateName!.trim().isNotEmpty &&
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
    if (_selectedCity == null || _selectedCity!.trim().isEmpty) missing.add('City');
    if (_selectedStateName == null || _selectedStateName!.trim().isEmpty) missing.add('State / Region');
    if (_motherTongue == null) missing.add('Mother tongue');
    showValidationSnackbar(context, missing);
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _stateCtrl.dispose();
    super.dispose();
  }

  String _getLocalizedRelation(AppLocalizations l10n) {
    if (_candidateLabel == 'son') return l10n.onboarding_profileForWhom_relation_son;
    if (_candidateLabel == 'daughter') return l10n.onboarding_profileForWhom_relation_daughter;
    if (_candidateLabel == 'brother') return l10n.onboarding_profileForWhom_relation_brother;
    if (_candidateLabel == 'sister') return l10n.onboarding_profileForWhom_relation_sister;
    return _candidateLabel;
  }

  String _getLocalizedComplexion(AppLocalizations l10n, String raw) {
    if (l10n.localeName == 'ar') {
      switch (raw) {
        case 'Fair': return 'فاتحة';
        case 'Medium': return 'قمحية';
        case 'Olive': return 'زيتونية';
        case 'Dark': return 'سمراء';
        case 'Prefer not to say': return 'أفضل عدم الإجابة';
      }
    }
    return raw;
  }

  String _getLocalizedResidency(AppLocalizations l10n, String raw) {
    if (l10n.localeName == 'ar') {
      switch (raw) {
        case 'Citizen': return 'مواطن';
        case 'Permanent Resident': return 'مقيم دائم';
        case 'Work Visa': return 'تأشيرة عمل';
        case 'Student Visa': return 'تأشيرة طالب';
        case 'Other': return 'أخرى';
        case 'Prefer not to say': return 'أفضل عدم الإجابة';
      }
    }
    return raw;
  }

  String _getLocalizedSpecialNeeds(AppLocalizations l10n, String raw) {
    if (l10n.localeName == 'ar') {
      switch (raw) {
        case 'None': return 'لا يوجد';
        case 'Physical disability': return 'إعاقة جسدية';
        case 'Hearing impairment': return 'ضعف السمع';
        case 'Visual impairment': return 'ضعف البصر';
        case 'Other': return 'أخرى';
        case 'Prefer not to say': return 'أفضل عدم الإجابة';
      }
    }
    return raw;
  }

  void _pickDob() async {
    final l10n = AppLocalizations.of(context);
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
              surface:   AppColors.surfaceMid,
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
              ? l10n.onboarding_error_under18_guardian(_getLocalizedRelation(l10n))
              : l10n.onboarding_error_under18_self
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
    final l10n = AppLocalizations.of(context);
    showModalBottomSheet<void>(
      context:            context,
      backgroundColor:    AppColors.surfaceMid,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _GenericListPicker(
        title:      l10n.onboarding_label_motherTongue,
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
    final l10n = AppLocalizations.of(context);
    showModalBottomSheet<void>(
      context:            context,
      backgroundColor:    AppColors.surfaceMid,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _GenericListPicker(
        title:      CopyEngine.communityQuestion(l10n, _creatorRelation),
        options:    _loadedCommunities,
        selected:   _community,
        onSelected: (v) {
          setState(() => _community = v);
          Navigator.pop(context);
        },
      ),
    );
  }


  // State and City picker sheets removed in favor of CitySearchField Google Places Autocomplete


  void _advance() async {
    final countryCode = _selectedCountryCode ?? 'XX';
    final cityName = _selectedStateName != null && _selectedStateName!.isNotEmpty
        ? '$_selectedCity, $_selectedStateName'
        : (_selectedCity ?? '');

    // Pre-capture BLoC references before any asynchronous gap
    final authCubit = context.read<AuthCubit>();
    final onboardingCubit = context.read<OnboardingCubit>();

    String? resolvedCityId = _selectedCityId;
    final intRegex = RegExp(r'^\d+$');

    if (_selectedCity != null &&
        (resolvedCityId == null || !intRegex.hasMatch(resolvedCityId))) {
      if (SupabaseService.isInitialized) {
        try {
          debugPrint(
              '[BasicIdentityScreen] Ingesting city dynamically: $_selectedCity...');
          final response = await SupabaseService.client.rpc(
            'get_or_create_city',
            params: {
              'p_city_name':    _selectedCity,
              'p_region_name':  _selectedStateName ?? '',
              'p_country_name': _selectedCountryName ?? '',
              'p_country_code': countryCode,
              'p_latitude':     _lat ?? 0.0,
              'p_longitude':    _lng ?? 0.0,
            },
          );
          if (response != null && intRegex.hasMatch(response.toString())) {
            resolvedCityId = response.toString();
            debugPrint(
                '[BasicIdentityScreen] Ingested successfully. Returned ID: $resolvedCityId');
          }
        } catch (e) {
          debugPrint('[BasicIdentityScreen] Dynamic city ingestion failed: $e');
        }
      }
    }

    final data = onboardingCubit.currentData.copyWith(
      firstName:    _firstNameCtrl.text.trim(),
      lastName:     _lastNameCtrl.text.trim(),
      dateOfBirth:  _dob,
      gender:       _gender,
      cityName:     cityName,
      cityId:       resolvedCityId ?? cityName.toLowerCase(),
      countryCode:  countryCode,
      postalCode:   _postalCode,
      lat:          _lat,
      lng:          _lng,
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
      authCubit.setGender(_gender == Gender.female ? 'female' : 'male');
    }

    // Save country code for regional pricing (subscription screen)
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_country_code', countryCode);

    if (mounted) {
      authCubit.setCountryCode(countryCode);
    }

    if (mounted) {
      onboardingCubit.saveAndAdvance(data);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final localizedRelation = _getLocalizedRelation(l10n);
    return BlocBuilder<OnboardingCubit, OnboardingState>(
      builder: (context, state) {
        final isLoading = state is OnboardingLoading;
        return OnboardingScaffold(
          ctaLabel:      l10n.legal_button_continue,
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
                          l10n.onboarding_basicIdentity_guardianBanner(localizedRelation),
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
                    ? l10n.onboarding_basicIdentity_title_guardian(localizedRelation)
                    : l10n.onboarding_basicIdentity_title,
                subtitle: _isGuardianMode
                    ? l10n.onboarding_basicIdentity_subtitle_guardian
                    : l10n.onboarding_basicIdentity_subtitle_self,
              ),
              const SizedBox(height: AppDimensions.space32),

              // Name row
              Row(
                children: [
                  Expanded(
                    child: NoorTextField(
                      controller:         _firstNameCtrl,
                      label:              _isGuardianMode
                                              ? l10n.onboarding_label_firstName_guardian
                                              : l10n.onboarding_label_firstName_self,
                      textCapitalization: TextCapitalization.words,
                      textInputAction:    TextInputAction.next,
                      onChanged:          (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: AppDimensions.space12),
                  Expanded(
                    child: NoorTextField(
                      controller:         _lastNameCtrl,
                      label:              l10n.onboarding_label_lastName,
                      textCapitalization: TextCapitalization.words,
                      textInputAction:    TextInputAction.next,
                      onChanged:          (_) => setState(() {}),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: AppDimensions.space20),

              // Date of birth
              Text(l10n.onboarding_label_dateOfBirth.toUpperCase(), style: AppTypography.sectionLabel),
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
                        _dob != null ? _formatDob(_dob!) : l10n.onboarding_hint_selectDateOfBirth,
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
                _isGuardianMode ? l10n.onboarding_label_gender_guardian.toUpperCase() : l10n.onboarding_label_gender_self.toUpperCase(),
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
                        _gender == Gender.male ? l10n.onboarding_label_male : l10n.onboarding_label_female,
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
                        label:      l10n.onboarding_label_male,
                        icon:       Icons.male_rounded,
                        isSelected: _gender == Gender.male,
                        onTap:      () => setState(() => _gender = Gender.male),
                      ),
                    ),
                    const SizedBox(width: AppDimensions.space12),
                    Expanded(
                      child: _GenderPill(
                        label:      l10n.onboarding_label_female,
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
              Text(_isGuardianMode ? l10n.onboarding_label_country_guardian.toUpperCase() : l10n.onboarding_label_country_self.toUpperCase(), style: AppTypography.sectionLabel),
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
                    _selectedCountryName ?? l10n.onboarding_hint_selectCountry,
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

              // ── City Search with Autocomplete ────────────────────
              CitySearchField(
                countryCode: _selectedCountryCode,
                initialValue: _selectedCity != null && _selectedStateName != null && _selectedStateName!.isNotEmpty
                    ? '$_selectedCity, $_selectedStateName'
                    : _selectedCity,
                label: _isGuardianMode ? l10n.onboarding_label_city_guardian.toUpperCase() : l10n.onboarding_label_city_self.toUpperCase(),
                hint: l10n.onboarding_hint_searchCity,
                onSelected: (result) {
                  setState(() {
                    _selectedCity = result.city.isNotEmpty ? result.city : null;
                    _selectedStateName = result.state.isNotEmpty ? result.state : null;
                    _stateCtrl.text = result.state;
                    
                    // Keep country info locked to verified selection if result is cleared
                    if (result.countryCode.isNotEmpty) {
                      _selectedCountryCode = result.countryCode;
                    }
                    if (result.country.isNotEmpty) {
                      _selectedCountryName = result.country;
                    }
                    
                    _selectedCityId = result.placeId.isNotEmpty ? result.placeId : null;
                    _postalCode = result.postalCode.isNotEmpty ? result.postalCode : null;
                    _lat = result.lat;
                    _lng = result.lng;
                  });
                  if (result.countryCode.isNotEmpty) {
                    _fetchDemographics(result.countryCode);
                  }
                },
              ),

              if (_selectedCity != null) ...[
                const SizedBox(height: AppDimensions.space20),
                NoorTextField(
                  controller: _stateCtrl,
                  label: l10n.localeName == 'ar' ? 'المنطقة / الولاية' : 'STATE / REGION',
                  hint: l10n.localeName == 'ar' ? 'أدخل المنطقة' : 'Enter state, region or province',
                  textCapitalization: TextCapitalization.words,
                  onChanged: (v) {
                    setState(() {
                      _selectedStateName = v;
                    });
                  },
                ),
              ],


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
                          Text(l10n.onboarding_location_confirmed, style: AppTypography.captionMedium.copyWith(color: AppColors.champagneGold)),
                        ],
                      ),
                      const SizedBox(height: AppDimensions.space16),
                      // City
                      Row(
                        children: [
                          const Icon(Icons.location_city_rounded, color: AppColors.slateMist, size: 18),
                          const SizedBox(width: AppDimensions.space12),
                          Text(l10n.onboarding_label_city, style: AppTypography.inputLabel),
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
                            Text(l10n.localeName == 'ar' ? 'المنطقة' : 'State / Region', style: AppTypography.inputLabel),
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
                            Text(l10n.localeName == 'ar' ? 'البلد' : 'Country', style: AppTypography.inputLabel),
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
                final l10nBuild = AppLocalizations.of(ctx);
                final rel = ctx.read<OnboardingCubit>().currentData.profileCreatorRelation ?? 'self';
                return Text('${CopyEngine.communityQuestion(l10nBuild, rel).toUpperCase()}  (Optional)', style: AppTypography.sectionLabel);
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
                      _community ?? l10n.onboarding_hint_selectCommunity,
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
              Text(_isGuardianMode ? l10n.onboarding_label_height_guardian.toUpperCase() : l10n.onboarding_label_height_self.toUpperCase(),
                  style: AppTypography.sectionLabel),
              const SizedBox(height: AppDimensions.space12),
              _HeightStepper(
                heightCm: _heightCm,
                onChanged: (v) => setState(() => _heightCm = v),
              ),

              const SizedBox(height: AppDimensions.space24),

              // ── COMPLEXION (Optional) ──────────────────────────────
              Text(l10n.localeName == 'ar' ? 'البشرة (اختياري)'.toUpperCase() : 'COMPLEXION  (Optional)', style: AppTypography.sectionLabel),
              const SizedBox(height: AppDimensions.space12),
              Wrap(
                spacing:    AppDimensions.space8,
                runSpacing: AppDimensions.space8,
                children: _kComplexions.map((o) => _SelectChip(
                  label:      _getLocalizedComplexion(l10n, o),
                  isSelected: _complexion == o,
                  onTap: () => setState(() =>
                      _complexion = _complexion == o ? null : o),
                )).toList(),
              ),

              const SizedBox(height: AppDimensions.space24),

              // ── MOTHER TONGUE (Required) ───────────────────────────
              Text(l10n.onboarding_label_motherTongue.toUpperCase(), style: AppTypography.sectionLabel),
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
                          _motherTongue ?? l10n.onboarding_hint_selectLanguage,
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
              Text(l10n.localeName == 'ar' ? 'حالة الإقامة (اختياري)'.toUpperCase() : 'RESIDENCY STATUS  (Optional)', style: AppTypography.sectionLabel),
              const SizedBox(height: AppDimensions.space12),
              Wrap(
                spacing:    AppDimensions.space8,
                runSpacing: AppDimensions.space8,
                children: _kResidencyOptions.map((o) => _SelectChip(
                  label:      _getLocalizedResidency(l10n, o),
                  isSelected: _residencyStatus == o,
                  onTap: () => setState(() =>
                      _residencyStatus = _residencyStatus == o ? null : o),
                )).toList(),
              ),

              const SizedBox(height: AppDimensions.space28),

              // ── SPECIAL NEEDS (Optional) ─────────────────────────────
              Text(l10n.localeName == 'ar' ? 'ذوو الاحتياجات الخاصة (اختياري)'.toUpperCase() : 'SPECIAL NEEDS  (Optional)', style: AppTypography.sectionLabel),
              const SizedBox(height: AppDimensions.space4),
              Container(
                padding: const EdgeInsets.all(AppDimensions.space10),
                decoration: BoxDecoration(
                  color: AppColors.surfaceGlass,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusChip),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.lock_outline_rounded,
                        color: AppColors.slateMist, size: 14),
                    const SizedBox(width: AppDimensions.space8),
                    Expanded(
                      child: Text(
                        l10n.localeName == 'ar' ? 'يتم مشاركة هذا فقط بعد الاهتمام المتبادل.' : 'This is only shared after mutual interest.',
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
                  label:      _getLocalizedSpecialNeeds(l10n, o),
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


