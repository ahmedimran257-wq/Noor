import sys
import re

file_path = r'c:\Users\imran\noor\lib\features\onboarding\screens\basic_identity_screen.dart'
with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Add import
if 'city_search_field.dart' not in content:
    content = content.replace(
        "import '../../../core/widgets/inputs/noor_text_field.dart';",
        "import '../../../core/widgets/inputs/noor_text_field.dart';\nimport '../../../core/widgets/inputs/city_search_field.dart';"
    )

# 2. Remove _kCities
content = re.sub(r'const _kCities = <Map<String, String>>\[.*?\];\n\n\n\n', '', content, flags=re.DOTALL)

# 3. Remove _cityCtrl declaration and dispose
content = content.replace('  final _cityCtrl      = TextEditingController();\n', '')
content = content.replace('    _cityCtrl.dispose();\n', '')

# 4. Update initState logic
init_state_old = '''    if (data.cityName != null) {
      _selectedCity = data.cityName;
      _cityCtrl.text = data.cityName!;
      _selectedCityId = data.cityId;
      _selectedCountryCode = data.countryCode;

      final cityMatch = _kCities.firstWhere(
        (c) => c['name'] == data.cityName,
        orElse: () => <String, String>{},
      );
      if (cityMatch.isNotEmpty) {
        _selectedCountryName = cityMatch['countryName'];
        _selectedCountryCode ??= cityMatch['country'];
      }
    }'''
init_state_new = '''    if (data.cityName != null) {
      _selectedCity = data.cityName;
      _selectedCityId = data.cityId;
      _selectedCountryCode = data.countryCode;
    }'''
content = content.replace(init_state_old, init_state_new)

# 5. Remove _effectiveCity and _filteredCities
content = re.sub(r'  /// City is valid if user either \(a\) picked from suggestions, or\n  /// \(b\) typed at least 2 characters as a free-text city name\.\n  String get _effectiveCity => _selectedCity \?\? _cityCtrl\.text\.trim\(\);\n', '  String get _effectiveCity => _selectedCity ?? \'\';\n', content)

content = re.sub(r'  List<Map<String, String>> get _filteredCities \{\n    final q = _cityCtrl\.text\.trim\(\);\n    if \(q\.isEmpty \|\| _selectedCity != null\) return \[\];\n    final lower = q\.toLowerCase\(\);\n    return _kCities\n        \.where\(\(c\) => c\[\'name\'\]!\.toLowerCase\(\)\.contains\(lower\)\)\n        \.take\(6\)\n        \.toList\(\);\n  \}\n', '', content)

# 6. Replace UI
ui_old = '''              // City search
              Text(
                _isGuardianMode ? "THEIR CITY" : 'YOUR CITY',
                style: AppTypography.sectionLabel,
              ),
              const SizedBox(height: AppDimensions.space8),
              NoorTextField(
                controller:         _cityCtrl,
                hint:               'Type your city',
                prefixIcon:         Icons.location_on_outlined,
                textCapitalization: TextCapitalization.words,
                textInputAction:    TextInputAction.done,
                onChanged: (q) => setState(() {
                  // Clear locked selection so user can re-type
                  _selectedCity        = null;
                  _selectedCityId      = null;
                  _selectedCountryCode = null;
                  _selectedCountryName = null;
                  _showSuggestions     = q.trim().isNotEmpty;
                }),
              ),

              // Suggestions dropdown
              if (_showSuggestions && _filteredCities.isNotEmpty) ...[
                const SizedBox(height: AppDimensions.space4),
                Container(
                  decoration: BoxDecoration(
                    color:        AppColors.inputSurface,
                    borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
                    border:       Border.all(color: AppColors.cardBorder),
                  ),
                  child: Column(
                    children: _filteredCities.map((city) {
                      return ListTile(
                        dense: true,
                        leading: const Icon(Icons.location_city_outlined,
                            color: AppColors.slateMist, size: 18),
                        title: Text(city['name']!, style: AppTypography.body),
                        subtitle: Text(
                          city['countryName']!,
                          style: AppTypography.caption.copyWith(
                            color: AppColors.slateMist,
                          ),
                        ),
                        onTap: () => setState(() {
                          _selectedCity        = city['name'];
                          _selectedCityId      = city['name']!.toLowerCase();
                          _selectedCountryCode = city['country'];
                          _selectedCountryName = city['countryName'];
                          _showSuggestions     = false;
                          _cityCtrl.text       = city['name']!;
                        }),
                      );
                    }).toList(),
                  ),
                ),
              ],'''

ui_new = '''              // City search
              CitySearchField(
                label: _isGuardianMode ? "THEIR CITY" : 'YOUR CITY',
                hint: 'Type your city',
                initialValue: _selectedCity,
                onSelected: (result) {
                  setState(() {
                    _selectedCity        = result.city.isNotEmpty ? result.city : result.fullAddress;
                    _selectedCityId      = result.placeId;
                    _selectedCountryCode = result.countryCode;
                    _selectedCountryName = result.country;
                  });
                },
              ),'''

if ui_old in content:
    content = content.replace(ui_old, ui_new)
else:
    print('Failed to replace UI part!')

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)

print('Success')
