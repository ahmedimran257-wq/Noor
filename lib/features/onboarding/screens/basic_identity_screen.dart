// lib/features/onboarding/screens/basic_identity_screen.dart
// ============================================================
// NOOR — Basic Identity Screen (Onboarding Step 1)
// First name, last name, date of birth, gender, city search.
// Under-18 DOB is blocked with a kind message.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/cubits/onboarding/onboarding_cubit.dart';
import '../../../core/cubits/onboarding/onboarding_state.dart';
import '../../../core/models/onboarding_data.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/inputs/noor_text_field.dart';
import '../widgets/onboarding_scaffold.dart';
import '../widgets/step_header.dart';

class BasicIdentityScreen extends StatefulWidget {
  const BasicIdentityScreen({super.key});

  @override
  State<BasicIdentityScreen> createState() => _BasicIdentityScreenState();
}

class _BasicIdentityScreenState extends State<BasicIdentityScreen> {
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl  = TextEditingController();
  final _cityCtrl      = TextEditingController();
  DateTime? _dob;
  Gender?   _gender;
  String    _dobError = '';

  // City search
  String? _selectedCity;   // set when user picks from suggestions
  String? _selectedCityId;
  bool _showSuggestions = false;
  final List<String> _mockCities = [
    'Mumbai', 'Delhi', 'Karachi', 'Lahore', 'Dhaka',
    'London', 'Birmingham', 'New York', 'Toronto', 'Dubai',
    'Riyadh', 'Kuala Lumpur', 'Jakarta', 'Istanbul', 'Cairo',
    'Hyderabad', 'Chennai', 'Bengaluru', 'Kolkata', 'Islamabad',
    'Manchester', 'Leeds', 'Bradford', 'Sydney', 'Melbourne',
  ];

  /// City is valid if user either (a) picked from suggestions, or (b) typed at
  /// least 2 characters as a free-text city name.
  String get _effectiveCity => _selectedCity ?? _cityCtrl.text.trim();

  bool get _canProceed =>
      _firstNameCtrl.text.trim().isNotEmpty &&
      _lastNameCtrl.text.trim().isNotEmpty &&
      _dob != null &&
      _dobError.isEmpty &&
      _gender != null &&
      _effectiveCity.length >= 2;

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _cityCtrl.dispose();
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
            colorScheme: ColorScheme.dark(
              primary:   AppColors.champagneGold,
              onPrimary: AppColors.obsidianNight,
              surface:   const Color(0xFF12121A),
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
          ? 'You must be 18 or older to use NOOR. We look forward to welcoming you then.'
          : '';
    });
  }

  int _calcAge(DateTime dob) {
    final now = DateTime.now();
    int years = now.year - dob.year;
    if (now.month < dob.month ||
        (now.month == dob.month && now.day < dob.day)) years--;
    return years;
  }

  String _formatDob(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')} / '
      '${d.month.toString().padLeft(2, '0')} / '
      '${d.year}';

  List<String> get _filteredCities {
    final q = _cityCtrl.text.trim();
    if (q.isEmpty || _selectedCity != null) return [];
    return _mockCities
        .where((c) => c.toLowerCase().contains(q.toLowerCase()))
        .toList();
  }

  void _advance() {
    final cityName = _effectiveCity;
    final data = context.read<OnboardingCubit>().currentData.copyWith(
      firstName:   _firstNameCtrl.text.trim(),
      lastName:    _lastNameCtrl.text.trim(),
      dateOfBirth: _dob,
      gender:      _gender,
      cityName:    cityName,
      cityId:      _selectedCityId ?? cityName.toLowerCase(),
      countryCode: 'IN', // mock — real value comes from city lookup
    );
    context.read<OnboardingCubit>().saveAndAdvance(data);
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<OnboardingCubit, OnboardingState>(
      builder: (context, state) {
        final isLoading = state is OnboardingLoading;
        return OnboardingScaffold(
          step:          1,
          ctaLabel:      'Continue',
          onCta:         _advance,
          isCtaEnabled:  _canProceed,
          isCtaLoading:  isLoading,
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppDimensions.space32),
              const StepHeader(
                title:    'Tell us about yourself',
                subtitle: 'This is what others will see on your profile.',
              ),
              const SizedBox(height: AppDimensions.space32),

              // Name row
              Row(
                children: [
                  Expanded(
                    child: NoorTextField(
                      controller:         _firstNameCtrl,
                      label:              'First name',
                      textCapitalization: TextCapitalization.words,
                      textInputAction:    TextInputAction.next,
                      onChanged:          (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: AppDimensions.space12),
                  Expanded(
                    child: NoorTextField(
                      controller:         _lastNameCtrl,
                      label:              'Last name',
                      textCapitalization: TextCapitalization.words,
                      textInputAction:    TextInputAction.next,
                      onChanged:          (_) => setState(() {}),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: AppDimensions.space20),

              // Date of birth
              Text('DATE OF BIRTH', style: AppTypography.sectionLabel),
              const SizedBox(height: AppDimensions.space8),
              GestureDetector(
                onTap: _pickDob,
                child: Container(
                  height: AppDimensions.buttonHeight,
                  padding: const EdgeInsetsDirectional.symmetric(
                    horizontal: AppDimensions.space16,
                  ),
                  decoration: BoxDecoration(
                    color:        AppColors.surfaceGlass,
                    borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today_outlined,
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
              Text('GENDER', style: AppTypography.sectionLabel),
              const SizedBox(height: AppDimensions.space8),
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

              const SizedBox(height: AppDimensions.space20),

              // City search
              Text('YOUR CITY', style: AppTypography.sectionLabel),
              const SizedBox(height: AppDimensions.space8),
              NoorTextField(
                controller:      _cityCtrl,
                hint:            'Type your city',
                prefixIcon:      Icons.location_on_outlined,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.done,
                onChanged: (q) => setState(() {
                  // Clear the locked selection so user can re-type
                  _selectedCity = null;
                  _selectedCityId = null;
                  _showSuggestions = q.trim().isNotEmpty;
                }),
              ),
              // Confirmed city badge (picked from list)
              if (_selectedCity != null) ...[
                const SizedBox(height: AppDimensions.space8),
                Row(
                  children: [
                    const Icon(Icons.check_circle_outline,
                        color: AppColors.verifiedTeal, size: 16),
                    const SizedBox(width: AppDimensions.space8),
                    Text(_selectedCity!, style: AppTypography.captionMedium),
                  ],
                ),
              ],
              // Suggestions dropdown
              if (_showSuggestions && _filteredCities.isNotEmpty) ...[
                const SizedBox(height: AppDimensions.space4),
                Container(
                  decoration: BoxDecoration(
                    color:        AppColors.surfaceGlass,
                    borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
                    border:       Border.all(color: AppColors.cardBorder),
                  ),
                  child: Column(
                    children: _filteredCities.take(5).map((city) {
                      return ListTile(
                        dense: true,
                        leading: const Icon(Icons.location_city_outlined,
                            color: AppColors.slateMist, size: 18),
                        title:  Text(city, style: AppTypography.body),
                        onTap: () => setState(() {
                          _selectedCity    = city;
                          _selectedCityId  = city.toLowerCase();
                          _showSuggestions = false;
                          _cityCtrl.text   = city;
                        }),
                      );
                    }).toList(),
                  ),
                ),
              ],

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
