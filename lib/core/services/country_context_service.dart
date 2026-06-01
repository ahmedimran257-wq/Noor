// lib/core/services/country_context_service.dart
// ============================================================
// NOOR — Country Context Service
//
// Two real APIs:
//   1. REST Countries API  → official languages for any country
//   2. Google Places API   → city search with postal code + address
//
// Two curated data sources (no API exists for these):
//   3. CountryCommunityData → Muslim communities by country
//   4. CountrySectData      → Sect options adapted by country
//
// SETUP REQUIRED:
//   Add your Google Places API key to AppConfig:
//     static const googlePlacesApiKey = 'YOUR_KEY_HERE';
//
//   Enable in Google Cloud Console:
//     - Places API (New)
//     - Geocoding API
//
//   Free tier: 28,500 requests/month — sufficient for MVP.
//
// REST Countries API:
//   No key required. Hosted at https://restcountries.com/v3.1/
//   Returns official languages, spoken languages, currency, region.
// ============================================================

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import '../data/country_communities_data.dart';
import '../data/country_sects_data.dart';

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
  final String postalCode;   // Pincode / ZIP / Postcode
  final String fullAddress;  // "Andheri West, Mumbai, Maharashtra 400053, India"
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

  // Simple in-memory cache — REST Countries response rarely changes
  final _languageCache = <String, List<String>>{};

  // ── 1. GET LANGUAGES FOR COUNTRY ──────────────────────────
  //
  // Calls: GET https://restcountries.com/v3.1/alpha/{iso2}?fields=languages
  // Returns all officially recognised + spoken languages for the country.
  // Cached in memory for the app session + SharedPreferences for offline.

  Future<List<String>> getLanguages(String iso2) async {
    final key = iso2.toUpperCase();

    // Memory cache hit
    if (_languageCache.containsKey(key)) return _languageCache[key]!;

    // SharedPreferences offline cache
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getStringList('lang_cache_$key');
      if (cached != null && cached.isNotEmpty) {
        _languageCache[key] = cached;
        return cached;
      }
    } catch (_) {}

    // Live API call
    try {
      final uri = Uri.parse(
        'https://restcountries.com/v3.1/alpha/$key?fields=languages',
      );
      final response = await http.get(uri).timeout(
        const Duration(seconds: 6),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final langMap = (data['languages'] as Map<String, dynamic>?) ?? {};
        // REST Countries returns { "hin": "Hindi", "eng": "English", ... }
        final langs = langMap.values.cast<String>().toList()..sort();
        // Always append "Other" at end
        if (!langs.contains('Other')) langs.add('Other');

        // Cache it
        _languageCache[key] = langs;
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setStringList('lang_cache_$key', langs);
        } catch (_) {}

        return langs;
      }
    } catch (e) {
      debugPrint('[CountryContextService] Language fetch failed for $key: $e');
    }

    // Fallback to curated data if API fails
    return _fallbackLanguages(key);
  }

  // ── 2. SEARCH CITIES (Google Places Autocomplete) ─────────
  //
  // Restricts results to the given country code.
  // Returns city name, state, postal code, full formatted address,
  // lat/lng, and placeId (used for detail fetch).

  Future<List<CityResult>> searchCities(
    String query, {
    String? countryCode,
  }) async {
    if (query.trim().length < 2) return [];

    const apiKey = AppConfig.googlePlacesApiKey;
    if (apiKey.isEmpty || apiKey == 'YOUR_GOOGLE_PLACES_API_KEY') {
      // Return empty — city field becomes a free-text input
      debugPrint('[CountryContextService] No Google Places key set');
      return [];
    }

    try {
      // Autocomplete with locality + sublocality types
      final uri = Uri.https(
        'maps.googleapis.com',
        '/maps/api/place/autocomplete/json',
        {
          'input':       query,
          'types':       '(cities)',
          if (countryCode != null) 'components':  'country:${countryCode.toLowerCase()}',
          'key':         apiKey,
          'language':    'en',
        },
      );

      final response = await http.get(uri).timeout(
        const Duration(seconds: 5),
      );

      if (response.statusCode != 200) return [];

      final data    = jsonDecode(response.body) as Map<String, dynamic>;
      final status  = data['status'] as String?;
      if (status != 'OK' && status != 'ZERO_RESULTS') return [];

      final predictions = (data['predictions'] as List<dynamic>? ?? []);

      // Fetch details for each to get postal code
      // Limit to 5 for performance
      final results = <CityResult>[];
      for (final pred in predictions.take(5)) {
        final placeId = pred['place_id'] as String? ?? '';
        if (placeId.isEmpty) continue;

        final detail = await _fetchPlaceDetail(placeId, apiKey);
        if (detail != null) results.add(detail);
      }

      return results;
    } catch (e) {
      debugPrint('[CountryContextService] City search failed: $e');
      return [];
    }
  }

  // ── Place detail fetch (postal code, lat/lng, components) ──

  Future<CityResult?> _fetchPlaceDetail(
    String placeId,
    String apiKey,
  ) async {
    try {
      final uri = Uri.https(
        'maps.googleapis.com',
        '/maps/api/place/details/json',
        {
          'place_id': placeId,
          'fields':   'address_components,geometry,formatted_address,name',
          'key':      apiKey,
        },
      );

      final res = await http.get(uri).timeout(const Duration(seconds: 4));
      if (res.statusCode != 200) return null;

      final data   = jsonDecode(res.body) as Map<String, dynamic>;
      final result = data['result'] as Map<String, dynamic>?;
      if (result == null) return null;

      final components =
          (result['address_components'] as List<dynamic>? ?? [])
              .cast<Map<String, dynamic>>();

      String city       = '';
      String state      = '';
      String country    = '';
      String countryCode = '';
      String postalCode = '';

      for (final comp in components) {
        final types = (comp['types'] as List<dynamic>).cast<String>();
        final longName  = comp['long_name']  as String? ?? '';
        final shortName = comp['short_name'] as String? ?? '';

        if (types.contains('locality')) city = longName;
        if (types.contains('sublocality_level_1') && city.isEmpty) {
          city = longName;
        }
        if (types.contains('administrative_area_level_1')) state = longName;
        if (types.contains('country')) {
          country     = longName;
          countryCode = shortName;
        }
        if (types.contains('postal_code')) postalCode = longName;
      }

      final geometry = result['geometry'] as Map<String, dynamic>?;
      final location = geometry?['location'] as Map<String, dynamic>?;
      final lat = (location?['lat'] as num?)?.toDouble() ?? 0.0;
      final lng = (location?['lng'] as num?)?.toDouble() ?? 0.0;

      final formatted = result['formatted_address'] as String? ?? '';

      return CityResult(
        city:        city.isEmpty ? (result['name'] as String? ?? '') : city,
        state:       state,
        country:     country,
        countryCode: countryCode,
        postalCode:  postalCode,
        fullAddress: formatted,
        placeId:     placeId,
        lat:         lat,
        lng:         lng,
      );
    } catch (_) {
      return null;
    }
  }

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
      languages:   langs,
      communities: getCommunities(iso2),
      sects:       getSects(iso2).displaySects,
    );
  }

  // ── Language fallback ──────────────────────────────────────

  static List<String> _fallbackLanguages(String iso2) {
    // Minimal fallback per region — only used if API + cache both fail
    const Map<String, List<String>> fallback = {
      'IN': ['Urdu', 'Hindi', 'Tamil', 'Telugu', 'Malayalam', 'Bengali', 'Other'],
      'PK': ['Urdu', 'Punjabi', 'Sindhi', 'Pashto', 'Balochi', 'Other'],
      'BD': ['Bengali', 'Other'],
      'ID': ['Indonesian', 'Javanese', 'Sundanese', 'Other'],
      'SA': ['Arabic', 'English', 'Urdu', 'Other'],
      'AE': ['Arabic', 'English', 'Urdu', 'Hindi', 'Other'],
      'TR': ['Turkish', 'Kurdish', 'Other'],
      'EG': ['Arabic', 'English', 'Other'],
      'NG': ['Hausa', 'Yoruba', 'Igbo', 'English', 'Other'],
      'GB': ['English', 'Urdu', 'Arabic', 'Bengali', 'Other'],
      'US': ['English', 'Arabic', 'Urdu', 'Somali', 'Other'],
      'MY': ['Malay', 'English', 'Mandarin', 'Tamil', 'Other'],
    };
    return fallback[iso2] ?? ['Arabic', 'English', 'Other'];
  }
}
