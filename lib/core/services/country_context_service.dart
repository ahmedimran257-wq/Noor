// lib/core/services/country_context_service.dart
// ============================================================
// MITHAQ — Country Context Service
//
// Two optional, free data providers:
//   1. Wikidata           → location-specific language enrichment
//   2. Photon             → city search with coordinates
//
// Two curated data sources (no API exists for these):
//   3. CountryCommunityData → Muslim communities by country
//   4. CountrySectData      → Sect options adapted by country
//
// Official country languages are bundled from Wikidata (CC0), so onboarding
// remains globally functional when external providers are unavailable.
// ============================================================

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../data/country_communities_data.dart';
import '../data/country_languages_data.dart';
import '../data/country_sects_data.dart';
import 'supabase_service.dart';

// ── Models ────────────────────────────────────────────────────

class CityResult {
  const CityResult({
    required this.city,
    required this.state,
    required this.country,
    required this.countryCode,
    required this.postalCode,
    required this.fullAddress,
    required this.placeId,
    required this.lat,
    required this.lng,
  });

  final String city;
  final String state;
  final String country;
  final String countryCode;
  final String postalCode; // Pincode / ZIP / Postcode
  final String fullAddress; // "Andheri West, Mumbai, Maharashtra 400053, India"
  final String placeId;
  final double lat;
  final double lng;

  @override
  String toString() => fullAddress;
}

class CountryContext {
  const CountryContext({
    required this.languages,
    required this.communities,
    required this.sects,
  });

  final List<String> languages;
  final List<String> communities;
  final List<String> sects;
}

// ── Service ───────────────────────────────────────────────────

class CountryContextService {
  CountryContextService._();
  static final CountryContextService instance = CountryContextService._();

  // Simple in-memory cache for bundled and location-enriched language lists.
  final _languageCache = <String, List<String>>{};
  final _locationLanguageCache = <String, List<String>>{};

  @visibleForTesting
  Future<List<CityResult>> Function(String query, String countryCode)?
      cityCacheSearchOverride;
  @visibleForTesting
  Future<http.Response> Function(Uri uri)? photonRequestOverride;
  @visibleForTesting
  Duration photonTimeout = const Duration(seconds: 5);

  @visibleForTesting
  void resetCitySearchTestOverrides() {
    cityCacheSearchOverride = null;
    photonRequestOverride = null;
    photonTimeout = const Duration(seconds: 5);
  }

  // ── 1. GET LANGUAGES FOR COUNTRY ──────────────────────────
  //
  // Returns bundled official languages for every supported country. Cached in
  // SharedPreferences for consistent behavior with location enrichment.

  Future<List<String>> getLanguages(String iso2) async {
    final key = iso2.toUpperCase();

    // Ignore a stale fallback-only cache from an older failed lookup.
    final memoryCached = _languageCache[key];
    if (_hasUsableLanguages(memoryCached)) return memoryCached!;
    _languageCache.remove(key);

    // SharedPreferences offline cache
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getStringList('lang_cache_$key');
      if (_hasUsableLanguages(cached)) {
        _languageCache[key] = cached!;
        return cached;
      }
    } catch (_) {}

    final languages = _fallbackLanguages(key);
    _languageCache[key] = languages;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('lang_cache_$key', languages);
    } catch (_) {}
    return languages;
  }

  // ── 2. SEARCH CITIES (Supabase cache → Photon) ───────────

  Future<List<String>> getLanguagesForLocation({
    required String countryCode,
    String? stateName,
    String? cityName,
  }) async {
    final code = countryCode.toUpperCase();
    final state = stateName?.trim() ?? '';
    final city = cityName?.trim() ?? '';
    final cacheKey = [
      code,
      if (state.isNotEmpty) state.toLowerCase(),
      if (city.isNotEmpty) city.toLowerCase(),
    ].join('|');

    final memoryCached = _locationLanguageCache[cacheKey];
    if (_hasUsableLanguages(memoryCached)) return memoryCached!;
    _locationLanguageCache.remove(cacheKey);

    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getStringList('loc_lang_cache_$cacheKey');
      if (_hasUsableLanguages(cached)) {
        _locationLanguageCache[cacheKey] = cached!;
        return cached;
      }
    } catch (_) {}

    final locationLangs = <String>[];
    for (final placeName in <String>[state, city]) {
      if (placeName.isEmpty) continue;
      final langs = await _fetchWikidataLocationLanguages(
        placeName: placeName,
        countryCode: code,
      );
      locationLangs.addAll(langs);
      if (locationLangs.length >= 8) break;
    }

    final merged = _uniqueLanguages([
      ...locationLangs,
      ...await getLanguages(code),
      ..._fallbackLanguages(code),
    ]);
    if (!merged.contains('Other')) merged.add('Other');

    _locationLanguageCache[cacheKey] = merged;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('loc_lang_cache_$cacheKey', merged);
    } catch (_) {}

    return merged;
  }

  Future<List<String>> _fetchWikidataLocationLanguages({
    required String placeName,
    required String countryCode,
  }) async {
    final escapedName = _escapeSparqlString(placeName);
    final escapedCode = _escapeSparqlString(countryCode.toUpperCase());
    final query = '''
SELECT DISTINCT ?languageLabel WHERE {
  ?country wdt:P297 "$escapedCode".
  ?place rdfs:label "$escapedName"@en.
  ?place (wdt:P17|wdt:P131*/wdt:P17) ?country.
  {
    ?place (wdt:P37|wdt:P2936) ?language.
  } UNION {
    ?place wdt:P131* ?admin.
    ?admin (wdt:P37|wdt:P2936) ?language.
  }
  SERVICE wikibase:label { bd:serviceParam wikibase:language "en". }
}
LIMIT 12
''';

    try {
      final uri = Uri.https(
        'query.wikidata.org',
        '/sparql',
        {
          'query': query,
          'format': 'json',
        },
      );
      final response = await http.get(
        uri,
        headers: {
          'Accept': 'application/sparql-results+json',
          'User-Agent':
              'MithaqApp/1.0 (contact@mithaq.app; language resolution)',
        },
      ).timeout(const Duration(seconds: 6));

      if (response.statusCode != 200) return const [];
      final data =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final results = data['results'] as Map<String, dynamic>? ?? {};
      final bindings = results['bindings'] as List<dynamic>? ?? const [];

      return _uniqueLanguages(bindings.map((binding) {
        final map = binding as Map<String, dynamic>;
        final label = map['languageLabel'] as Map<String, dynamic>?;
        return label?['value'] as String? ?? '';
      }));
    } catch (e) {
      debugPrint(
        '[CountryContextService] Wikidata language fetch failed for '
        '$placeName, $countryCode: $e',
      );
      return const [];
    }
  }

  Future<List<CityResult>> searchCities(
    String query, {
    required String countryCode,
  }) async {
    debugPrint(
        '[CountryContextService] searchCities query: "$query", countryCode: "$countryCode"');
    final selectedCountry = countryCode.trim().toUpperCase();
    if (query.trim().length < 2 || selectedCountry.isEmpty) return [];

    // 1. Try the Supabase city cache first.
    if (cityCacheSearchOverride != null) {
      try {
        final cached = await cityCacheSearchOverride!(query, selectedCountry);
        if (cached.isNotEmpty) return cached;
      } catch (error) {
        debugPrint('[CountryContextService] Test city cache failed: $error');
      }
    } else if (SupabaseService.isInitialized) {
      try {
        debugPrint(
            '[CountryContextService] Querying Supabase rpc search_cities...');
        final response = await SupabaseService.client.rpc(
          'search_cities',
          params: {
            'search_term': query,
            'country_filter': selectedCountry,
          },
        );
        debugPrint('[CountryContextService] Supabase response: $response');
        if (response != null) {
          final list = response as List<dynamic>;
          if (list.isNotEmpty) {
            debugPrint(
                '[CountryContextService] Found ${list.length} cities from Supabase');
            return list.map((row) {
              final map = row as Map<String, dynamic>;
              final cityName = map['name'] as String? ?? '';
              final stateName = map['state'] as String? ?? '';
              final countryName = map['country'] as String? ?? '';
              final code = (map['country_code'] as String? ?? selectedCountry)
                  .toUpperCase();
              final lat = (map['lat'] as num?)?.toDouble() ?? 0.0;
              final lng = (map['lng'] as num?)?.toDouble() ?? 0.0;
              return CityResult(
                city: cityName,
                state: stateName,
                country: countryName,
                countryCode: code,
                postalCode: '',
                fullAddress: [
                  cityName,
                  if (stateName.isNotEmpty) stateName,
                  if (countryName.isNotEmpty) countryName,
                ].join(', '),
                placeId: map['id']?.toString() ?? '',
                lat: lat,
                lng: lng,
              );
            }).toList();
          }
        }
      } catch (e) {
        debugPrint('[CountryContextService] Supabase search_cities failed: $e');
      }
    }

    // 2. Photon is the global no-key fallback when the city cache misses.
    try {
      debugPrint(
          '[CountryContextService] Querying Photon Geocoding API for "$query" (countryCode: $countryCode)...');
      final uri = Uri.https(
        'photon.komoot.io',
        '/api',
        {
          'q': query,
          'limit': '5',
          'osm_tag': 'place:city,place:town,place:village',
        },
      );

      final request = photonRequestOverride != null
          ? photonRequestOverride!(uri)
          : http.get(
              uri,
              headers: {
                'User-Agent':
                    'MithaqApp/1.0 (contact@noorapp.com; matchmaking app)',
              },
            );
      final response = await request.timeout(photonTimeout);

      debugPrint(
          '[CountryContextService] Photon status code: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data =
            jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        final features = data['features'] as List<dynamic>? ?? [];
        final parsedResults = <CityResult>[];

        for (final feat in features) {
          final map = feat as Map<String, dynamic>;
          final properties = map['properties'] as Map<String, dynamic>? ?? {};
          final geometry = map['geometry'] as Map<String, dynamic>? ?? {};
          final coords = geometry['coordinates'] as List<dynamic>? ?? [];

          final cCode = properties['countrycode'] as String? ?? '';

          // The public Photon endpoint does not reliably enforce a country
          // filter, so reject any result outside the selected ISO country.
          if (cCode.toUpperCase() != selectedCountry) {
            continue;
          }

          final cityName = properties['name'] as String? ?? '';
          final stateName = properties['state'] as String? ?? '';
          final countryName = properties['country'] as String? ?? '';
          if (cityName.isEmpty ||
              coords.length < 2 ||
              coords[0] is! num ||
              coords[1] is! num) {
            continue;
          }
          final lng = (coords[0] as num).toDouble();
          final lat = (coords[1] as num).toDouble();

          // Formatted address: "Kurnool, Andhra Pradesh, India"
          final fullAddr = [
            cityName,
            if (stateName.isNotEmpty) stateName,
            if (countryName.isNotEmpty) countryName,
          ].join(', ');

          parsedResults.add(CityResult(
            city: cityName,
            state: stateName,
            country: countryName,
            countryCode: cCode.toUpperCase(),
            postalCode: properties['postcode'] as String? ?? '',
            fullAddress: fullAddr,
            placeId: 'photon-${properties['osm_id'] ?? cityName.toLowerCase()}',
            lat: lat,
            lng: lng,
          ));
        }

        if (parsedResults.isNotEmpty) {
          debugPrint(
              '[CountryContextService] Found ${parsedResults.length} cities from Photon');
          return parsedResults;
        }
      }
    } catch (e) {
      debugPrint('[CountryContextService] Photon search failed: $e');
    }

    // 3. Do not accept unverified free text: matching needs real coordinates.
    debugPrint(
        '[CountryContextService] No matches found, returning empty list.');
    return const [];
  }

  // ── Place detail fetch (postal code, lat/lng, components) ──

  // ── 3. GET COMMUNITIES FOR COUNTRY ────────────────────────
  //
  // No API for this exists. Uses CountryCommunityData.
  // The data file is designed to be replaceable by a Supabase query.

  List<String> getCommunities(String iso2) {
    return CountryCommunityData.forCountry(iso2);
  }

  // ── 4. GET SECTS FOR COUNTRY ──────────────────────────────
  //
  // Returns sect options adapted to the country's Muslim demographics.
  // Saudi Arabia: no main sect shown (sensitive), only deen level.
  // Iran: Shia first.
  // Mixed countries: full list.

  CountrySectConfig getSects(String iso2) {
    return CountrySectData.forCountry(iso2);
  }

  // ── 5. GET FULL CONTEXT (all four) ────────────────────────

  Future<CountryContext> getContext(String iso2) async {
    final langs = await getLanguages(iso2);
    return CountryContext(
      languages: langs,
      communities: getCommunities(iso2),
      sects: getSects(iso2).displaySects,
    );
  }

  // ── Language fallback ──────────────────────────────────────

  static List<String> _fallbackLanguages(String iso2) {
    return _uniqueLanguages([
      ...?kCountryLanguages[iso2.toUpperCase()],
      'Other',
    ]);
  }

  static bool _hasUsableLanguages(List<String>? languages) {
    return languages != null &&
        languages.any((language) => language.trim().toLowerCase() != 'other');
  }

  static String _escapeSparqlString(String value) {
    return value.replaceAll(r'\', r'\\').replaceAll('"', r'\"');
  }

  static List<String> _uniqueLanguages(Iterable<String> values) {
    final seen = <String>{};
    final result = <String>[];
    for (final value in values) {
      final normalized = value.trim();
      if (normalized.isEmpty) continue;
      final key = normalized.toLowerCase();
      if (seen.add(key)) result.add(normalized);
    }
    result.sort((a, b) {
      if (a == 'Other') return 1;
      if (b == 'Other') return -1;
      return a.compareTo(b);
    });
    return result;
  }
}
