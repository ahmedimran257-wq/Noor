import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:silarah/core/cubits/notification_prefs/notification_prefs_state.dart';
import 'package:silarah/core/utils/notification_deep_link.dart';

void main() {
  final migration =
      File('supabase/migrations/279_festival_greetings.sql').readAsStringSync();
  final cubit = File(
    'lib/core/cubits/notification_prefs/notification_prefs_cubit.dart',
  ).readAsStringSync();

  const languages = [
    'en',
    'ar',
    'bn',
    'de',
    'fr',
    'hi',
    'id',
    'ms',
    'tr',
    'ur'
  ];
  const occasions = [
    'ramadan_start',
    'last_ten_nights',
    'eid_al_fitr',
    'eid_al_adha',
    'islamic_new_year',
  ];

  test('every occasion has a greeting in every app language', () {
    for (final occasion in occasions) {
      for (final language in languages) {
        expect(migration, contains("('$occasion', '$language', "),
            reason: '$occasion is missing its $language greeting');
      }
    }
  });

  test('greetings avoid occasions that divide members', () {
    final lower = migration.toLowerCase();
    expect(lower, isNot(contains("'mawlid")));
    expect(lower, isNot(contains("'shab_e_barat")));
  });

  test('greetings send once, at local morning, on the country date', () {
    expect(
        migration, contains('PRIMARY KEY (user_id, occasion_key, hijri_year)'));
    expect(migration, contains("m.local_ts::time >= time '09:00'"));
    expect(
        migration,
        contains("ORDER BY occ.occasion_key, occ.hijri_year, "
            "(occ.country_code = '*')"));
    expect(
        migration, contains("('eid_al_fitr', 1448, 'IN', date '2027-03-10')"));
  });

  test('members can switch greetings off', () {
    expect(migration,
        contains('festival_greetings boolean NOT NULL DEFAULT true'));
    expect(migration,
        contains('AND coalesce(prefs.festival_greetings, true) = true'));
    expect(migration, contains("WHEN p_type = 'festival_greeting'"));
    expect(const NotificationPrefsState().festivalGreetings, isTrue);
    expect(cubit, contains("'festival_greetings': snapshot.festivalGreetings"));
    final settings = File('lib/features/home/screens/settings_screen.dart')
        .readAsStringSync();
    expect(settings, contains('.toggleFestivalGreetings(v)'));
    for (final language in languages) {
      expect(
        File('lib/l10n/app_$language.arb').readAsStringSync(),
        contains('"settings_notify_festivalGreetingsSub"'),
        reason: 'The greetings switch needs a $language caption',
      );
    }
  });

  test('a greeting opens the notification list', () {
    expect(notificationDestinationPath(type: 'festival_greeting'),
        '/notifications');
    expect(
      notificationDestinationPath(
        type: 'festival_greeting',
        deepLink: 'silarah://notifications',
      ),
      '/notifications',
    );
  });
}
