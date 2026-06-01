import sys
import re

file_path = r'c:\Users\imran\noor\lib\features\onboarding\screens\basic_identity_screen.dart'
with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Update imports
content = content.replace(
    "import '../../../core/config/demographics_config.dart';",
    "import '../../../core/services/country_context_service.dart';"
)

# 2. Add state variables
state_vars_insertion = '''  // City search
  String? _selectedCity;
  String? _selectedCityId;
  String? _selectedCountryCode;
  String? _selectedCountryName;

  // Demographics from CountryContextService
  List<String> _loadedLanguages = ['English', 'Arabic', 'Other'];
  List<String> _loadedCommunities = ['Prefer not to say'];'''

content = content.replace(
    '''  // City search
  String? _selectedCity;
  String? _selectedCityId;
  String? _selectedCountryCode;
  String? _selectedCountryName;
  bool    _showSuggestions = false;''', 
    state_vars_insertion
)
content = content.replace(
    '''  // City search
  String? _selectedCity;
  String? _selectedCityId;
  String? _selectedCountryCode;
  String? _selectedCountryName;''', 
    state_vars_insertion
)

# 3. Add _fetchDemographics method and call in initState
init_state_end = '''    if (data.cityName != null) {
      _selectedCity = data.cityName;
      _selectedCityId = data.cityId;
      _selectedCountryCode = data.countryCode;
    }
  }'''

init_state_new = '''    if (data.cityName != null) {
      _selectedCity = data.cityName;
      _selectedCityId = data.cityId;
      _selectedCountryCode = data.countryCode;
      
      if (_selectedCountryCode != null) {
        _fetchDemographics(_selectedCountryCode!);
      }
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
  }'''

content = content.replace(init_state_end, init_state_new)

# 4. Remove old getters
old_getters = '''  // TODO (backend): read demographics from Supabase country_demographics table.
  List<String> get _countryLanguages {
    final code = _selectedCountryCode ?? '';
    return DemographicsConfig.languages(code);
  }

  List<String> get _countryCommunities {
    final code = _selectedCountryCode ?? '';
    return [...DemographicsConfig.communities(code), 'Prefer not to say'];
  }'''

content = content.replace(old_getters, '')

# 5. Update UI to call _fetchDemographics on city select
ui_old = '''                onSelected: (result) {
                  setState(() {
                    _selectedCity        = result.city.isNotEmpty ? result.city : result.fullAddress;
                    _selectedCityId      = result.placeId;
                    _selectedCountryCode = result.countryCode;
                    _selectedCountryName = result.country;
                  });
                },'''

ui_new = '''                onSelected: (result) {
                  final newCountry = result.countryCode;
                  final countryChanged = newCountry != _selectedCountryCode;
                  
                  setState(() {
                    _selectedCity        = result.city.isNotEmpty ? result.city : result.fullAddress;
                    _selectedCityId      = result.placeId;
                    _selectedCountryCode = newCountry;
                    _selectedCountryName = result.country;
                  });
                  
                  if (countryChanged && newCountry.isNotEmpty) {
                    _fetchDemographics(newCountry);
                  }
                },'''

content = content.replace(ui_old, ui_new)

# 6. Update references in the modal pickers
content = content.replace('_countryLanguages', '_loadedLanguages')
content = content.replace('_countryCommunities', '_loadedCommunities')

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)

print('Success')
