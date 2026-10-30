import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

import 'supabase_service.dart';

class LaunchConfiguration {
  const LaunchConfiguration({
    required this.enabledCountries,
    required this.defaultCountry,
  });

  static const india = LaunchConfiguration(
    enabledCountries: ['IN'],
    defaultCountry: 'IN',
  );

  final List<String> enabledCountries;
  final String defaultCountry;

  bool get isSingleCountry => enabledCountries.length == 1;
  bool get isGlobal => enabledCountries.length > 1;
}

class LaunchConfigurationService {
  LaunchConfigurationService._();

  static const _prefsCountries = 'launch_config_enabled_countries_v1';
  static const _prefsDefault = 'launch_config_default_country_v1';

  static LaunchConfiguration? _cached;
  static DateTime? _cachedAt;
  static Future<LaunchConfiguration>? _refresh;

  /// Returns the launch markets. A value remembered from the previous session
  /// is served at once on cold start and refreshed in the background, so
  /// Discovery does not wait a round trip for a setting that rarely changes.
  /// The server applies the same markets to every feed row regardless.
  static Future<LaunchConfiguration> load({bool force = false}) async {
    final cached = _cached;
    final cachedAt = _cachedAt;
    if (!force &&
        cached != null &&
        cachedAt != null &&
        DateTime.now().difference(cachedAt) < const Duration(minutes: 15)) {
      return cached;
    }
    if (!force && cached == null) {
      final remembered = await _readRemembered();
      if (remembered != null) {
        _cached = remembered;
        unawaited(_refreshOnce());
        return remembered;
      }
    }
    return _refreshOnce();
  }

  static Future<LaunchConfiguration> _refreshOnce() =>
      _refresh ??= _fetch().whenComplete(() => _refresh = null);

  static Future<LaunchConfiguration?> _readRemembered() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final countries = prefs.getStringList(_prefsCountries);
      if (countries == null || countries.isEmpty) return null;
      return LaunchConfiguration(
        enabledCountries: countries,
        defaultCountry: prefs.getString(_prefsDefault) ?? countries.first,
      );
    } catch (_) {
      return null;
    }
  }

  static Future<void> _remember(LaunchConfiguration config) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_prefsCountries, config.enabledCountries);
      await prefs.setString(_prefsDefault, config.defaultCountry);
    } catch (_) {}
  }

  static Future<LaunchConfiguration> _fetch() async {
    if (!SupabaseService.isInitialized) return LaunchConfiguration.india;
    try {
      final response =
          await SupabaseService.client.rpc('get_launch_configuration');
      final row = switch (response) {
        final Map value => Map<String, dynamic>.from(value),
        final List value when value.isNotEmpty && value.first is Map =>
          Map<String, dynamic>.from(value.first as Map),
        _ => null,
      };
      final countries = (row?['enabled_countries'] as Iterable?)
              ?.map((value) => value.toString().toUpperCase())
              .where((value) => RegExp(r'^[A-Z]{2}$').hasMatch(value))
              .toSet()
              .toList(growable: false) ??
          const <String>[];
      if (countries.isEmpty) return LaunchConfiguration.india;
      final config = LaunchConfiguration(
        enabledCountries: countries,
        defaultCountry: row?['default_country']?.toString().toUpperCase() ??
            countries.first,
      );
      _cached = config;
      _cachedAt = DateTime.now();
      unawaited(_remember(config));
      return config;
    } catch (_) {
      // Fail closed to the announced India launch instead of exposing a
      // global signup or discovery surface during a configuration outage.
      return _cached ?? LaunchConfiguration.india;
    }
  }
}
