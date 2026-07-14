import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import 'country_context_service.dart';
import 'supabase_service.dart';

class LocationResolution {
  const LocationResolution({this.cityId, this.errorMessage});

  final String? cityId;
  final String? errorMessage;
  bool get isSuccess => cityId != null && cityId!.isNotEmpty;
}

/// Resolves externally searched cities into reusable rows in the Silarah city
/// cache. The server remains authoritative for IDs and location validation.
abstract final class LocationService {
  static Future<LocationResolution> resolveCity(CityResult city) async {
    if (!SupabaseService.isInitialized) {
      return const LocationResolution(
        errorMessage: 'Location saving is not configured. Please try again.',
      );
    }

    try {
      final regionName = city.state.trim().isNotEmpty
          ? city.state.trim()
          : (city.country.trim().isNotEmpty
              ? city.country.trim()
              : city.countryCode.trim());
      final response =
          await SupabaseService.client.rpc('get_or_create_city', params: {
        'p_city_name': city.city,
        'p_region_name': regionName,
        'p_country_name': city.country,
        'p_country_code': city.countryCode,
        'p_latitude': city.lat,
        'p_longitude': city.lng,
      });
      final cityId = response?.toString();
      if (cityId != null && cityId.trim().isNotEmpty) {
        return LocationResolution(cityId: cityId);
      }
    } catch (error) {
      debugPrint('LocationService: city resolution failed: $error');
    }

    return const LocationResolution(
      errorMessage: 'We could not save that city. Please try again.',
    );
  }

  /// Refreshes the viewer's radius-search origin from the device. The server
  /// rounds it before storage; denied/unavailable GPS keeps the city point.
  static Future<bool> refreshDiscoveryLocation() async {
    if (!SupabaseService.isInitialized ||
        SupabaseService.currentUserId == null) {
      return false;
    }

    try {
      if (!await Geolocator.isLocationServiceEnabled()) return false;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return false;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 8),
        ),
      );
      await SupabaseService.client.rpc(
        'update_discovery_location',
        params: {
          'p_latitude': position.latitude,
          'p_longitude': position.longitude,
        },
      );
      return true;
    } catch (error) {
      debugPrint('LocationService: device location refresh failed: $error');
      return false;
    }
  }
}
