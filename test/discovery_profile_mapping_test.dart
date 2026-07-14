import 'package:flutter_test/flutter_test.dart';
import 'package:silarah/core/models/discovery_profile.dart';
import 'package:silarah/core/utils/silarah_compute.dart';

void main() {
  test('maps real Supabase discovery rows without invented defaults', () {
    final profile = mapDbRowToDiscoveryProfile({
      'user_id': '8d5c0b0d-6b84-45b6-9c6f-1ac3a7757f2d',
      'first_name': 'Aisha',
      'last_name': 'Khan',
      'age': 27,
      'city_name': 'Hyderabad',
      'is_verified': true,
    });

    expect(profile.id, '8d5c0b0d-6b84-45b6-9c6f-1ac3a7757f2d');
    expect(profile.firstName, 'Aisha');
    expect(profile.lastNameInitial, 'K');
    expect(profile.age, 27);
    expect(profile.cityName, 'Hyderabad');
    expect(profile.sect, isNull);
    expect(profile.deenLevel, isNull);
    expect(profile.occupation, isNull);
    expect(profile.education, isNull);
  });

  test('rejects discovery rows missing real user identity', () {
    expect(
      () => mapDbRowToDiscoveryProfile({
        'first_name': 'Aisha',
        'age': 27,
        'city_name': 'Hyderabad',
      }),
      throwsA(isA<StateError>()),
    );
  });

  test('discovery profile id getter never invents name-based ids', () {
    const profile = DiscoveryProfile(
      firstName: 'Aisha',
      lastNameInitial: 'K',
      age: 27,
      cityName: 'Hyderabad',
    );

    expect(() => profile.id, throwsA(isA<StateError>()));
  });
}
