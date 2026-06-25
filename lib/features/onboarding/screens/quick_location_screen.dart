import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/cubits/onboarding/onboarding_cubit.dart';
import '../../../core/cubits/auth/auth_cubit.dart';
import '../../../core/data/country_data.dart';
import '../../../core/services/country_context_service.dart';
import '../../../core/services/location_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/country_picker_screen.dart';
import '../../../core/widgets/inputs/city_search_field.dart';
import '../widgets/onboarding_scaffold.dart';
import '../widgets/step_header.dart';

class QuickLocationScreen extends StatefulWidget {
  const QuickLocationScreen({super.key});

  @override
  State<QuickLocationScreen> createState() => _QuickLocationScreenState();
}

class _QuickLocationScreenState extends State<QuickLocationScreen> {
  late CountryInfo _country;
  CityResult? _city;
  String? _initialCity;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final data = context.read<OnboardingCubit>().currentData;
    final matches = kAllCountries.where(
      (country) =>
          country.iso2.toUpperCase() == data.countryCode?.toUpperCase(),
    );
    _country = matches.isEmpty ? deviceCountry() : matches.first;
    _initialCity = data.cityName;
  }

  bool get _isValid => _city != null;

  void _selectCountry(CountryInfo country) {
    if (country.iso2 == _country.iso2) return;
    setState(() {
      _country = country;
      _city = null;
      _initialCity = null;
    });
  }

  Future<void> _continue() async {
    final city = _city;
    if (city == null || _saving) return;
    setState(() => _saving = true);

    final resolution = await LocationService.resolveCity(city);
    if (!mounted) return;
    if (!resolution.isSuccess) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(resolution.errorMessage!)),
      );
      return;
    }

    final cityName =
        city.state.isEmpty ? city.city : '${city.city}, ${city.state}';
    final cubit = context.read<OnboardingCubit>();
    await context.read<AuthCubit>().setCountryCode(_country.iso2);
    await cubit.saveAndAdvance(cubit.currentData.copyWith(
      countryCode: _country.iso2,
      cityId: resolution.cityId,
      cityName: cityName,
      postalCode: city.postalCode,
      lat: city.lat,
      lng: city.lng,
    ));
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingScaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const StepHeader(
            title: 'Where are you?',
            subtitle: 'This helps us show you relevant matches nearby.',
          ),
          const SizedBox(height: AppDimensions.space32),
          const Text('Country', style: AppTypography.sectionLabel),
          const SizedBox(height: AppDimensions.space8),
          InkWell(
            borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => CountryPickerScreen(
                selected: _country,
                onSelected: _selectCountry,
              ),
            )),
            child: Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.surfaceGlass,
                borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Row(children: [
                Text(_country.flag, style: const TextStyle(fontSize: 24)),
                const SizedBox(width: 12),
                Expanded(child: Text(_country.name, style: AppTypography.body)),
                const Icon(Icons.keyboard_arrow_down_rounded,
                    color: AppColors.slateMist),
              ]),
            ),
          ),
          const SizedBox(height: AppDimensions.space24),
          const Text('City', style: AppTypography.sectionLabel),
          const SizedBox(height: AppDimensions.space8),
          CitySearchField(
            key: ValueKey(_country.iso2),
            countryCode: _country.iso2,
            initialValue: _initialCity,
            hint: 'Search your city or area',
            onSelected: (result) => setState(() {
              _city = result;
              _initialCity = null;
            }),
          ),
          const SizedBox(height: AppDimensions.space16),
          const Text(
            'Select a city from the results to continue.',
            style: AppTypography.bodyMuted,
          ),
        ],
      ),
      ctaLabel: 'Continue',
      onCta: _isValid ? _continue : null,
      isCtaEnabled: _isValid,
      isCtaLoading: _saving,
    );
  }
}
