import 'package:silarah/l10n/ui_copy.dart';
import 'package:flutter/material.dart';

import '../data/country_data.dart';
import '../services/launch_configuration_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

class CountryPickerScreen extends StatefulWidget {
  const CountryPickerScreen({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final CountryInfo selected;
  final ValueChanged<CountryInfo> onSelected;

  @override
  State<CountryPickerScreen> createState() => _CountryPickerScreenState();
}

class _CountryPickerScreenState extends State<CountryPickerScreen> {
  String _query = '';
  LaunchConfiguration _launch = LaunchConfiguration.india;

  @override
  void initState() {
    super.initState();
    LaunchConfigurationService.load().then((configuration) {
      if (mounted) setState(() => _launch = configuration);
    });
  }

  @override
  Widget build(BuildContext context) {
    final query = _query.trim().toLowerCase();
    final enabled = _launch.enabledCountries.toSet();
    final countries = kAllCountries.where((country) {
      if (!enabled.contains(country.iso2)) return false;
      return query.isEmpty ||
          country.name.toLowerCase().contains(query) ||
          country.iso2.toLowerCase().contains(query);
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.obsidianNight,
      appBar: AppBar(
        backgroundColor: AppColors.obsidianNight,
        foregroundColor: AppColors.pearlWhite,
        title: UiText(context.uiCopy('Select country')),
      ),
      body: Column(
        children: [
          if (!_launch.isSingleCountry)
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                onChanged: (value) => setState(() => _query = value),
                onTapOutside: (_) =>
                    FocusManager.instance.primaryFocus?.unfocus(),
                style: AppTypography.body,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search_rounded),
                  hintText: context.uiCopy('Search country'),
                ),
              ),
            ),
          Expanded(
            child: ListView.builder(
              itemCount: countries.length,
              itemBuilder: (context, index) {
                final country = countries[index];
                final selected = country.iso2 == widget.selected.iso2;
                return ListTile(
                  leading: UiText(country.flag,
                      style: const TextStyle(fontSize: 22)),
                  title: UiText(country.name, style: AppTypography.body),
                  trailing: selected
                      ? Icon(Icons.check_rounded,
                          color: AppColors.champagneGold)
                      : null,
                  onTap: () {
                    FocusManager.instance.primaryFocus?.unfocus();
                    widget.onSelected(country);
                    Navigator.of(context).pop();
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
