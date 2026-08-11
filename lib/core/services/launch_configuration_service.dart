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

  static LaunchConfiguration? _cached;
  static DateTime? _cachedAt;

  static Future<LaunchConfiguration> load({bool force = false}) async {
    final cached = _cached;
    final cachedAt = _cachedAt;
    if (!force &&
        cached != null &&
        cachedAt != null &&
        DateTime.now().difference(cachedAt) < const Duration(minutes: 15)) {
      return cached;
    }
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
      return config;
    } catch (_) {
      // Fail closed to the announced India launch instead of exposing a
      // global signup or discovery surface during a configuration outage.
      return _cached ?? LaunchConfiguration.india;
    }
  }
}
