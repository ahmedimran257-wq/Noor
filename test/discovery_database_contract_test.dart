import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('discovery database contract', () {
    late final String cityIdSql;
    late final String textSql;
    late final String profileSearchSql;
    late final List<File> feedDefinitionMigrations;

    setUpAll(() {
      cityIdSql = File(
        'supabase/migrations/112_fix_discovery_city_id_contract.sql',
      ).readAsStringSync();
      textSql = File(
        'supabase/migrations/113_fix_discovery_feed_text_contract.sql',
      ).readAsStringSync();
      profileSearchSql = File(
        'supabase/migrations/114_fix_profile_search_city_text_contract.sql',
      ).readAsStringSync();
      feedDefinitionMigrations = Directory('supabase/migrations')
          .listSync()
          .whereType<File>()
          .where((file) => file.path.endsWith('.sql'))
          .where(
            (file) => file.readAsStringSync().contains(
                'CREATE OR REPLACE FUNCTION public.get_discovery_feed('),
          )
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));
    });

    test('anchors the feed city id to the profiles schema', () {
      expect(
        cityIdSql,
        contains('v_viewer_city_id public.profiles.city_id%TYPE;'),
      );
      expect(cityIdSql, isNot(contains('v_viewer_city_id uuid;')));
      expect(cityIdSql, contains('OR dp.city_id = v_viewer_city_id'));
    });

    test('casts global city fields to the public RPC text contract', () {
      expect(textSql, contains('dp.city_name::text'));
      expect(textSql, contains('dp.country_code::text'));
      expect(
        textSql,
        contains('v_updated_definition = v_definition'),
      );
    });

    test('keeps the authenticated feed signature and permission', () {
      expect(
        cityIdSql,
        contains('CREATE OR REPLACE FUNCTION public.get_discovery_feed('),
      );
      expect(
        cityIdSql,
        contains('IF auth.uid() IS DISTINCT FROM p_viewer_id THEN'),
      );
      expect(
        cityIdSql,
        contains('TO authenticated;'),
      );
    });

    test('rejects later feed replacements that drop the repaired contract', () {
      expect(feedDefinitionMigrations, isNotEmpty);
      final latestDefinition = feedDefinitionMigrations.last;
      final latestSql = latestDefinition.readAsStringSync();

      expect(
        latestSql,
        contains('v_viewer_city_id public.profiles.city_id%TYPE;'),
        reason:
            '${latestDefinition.path} replaced discovery without preserving '
            'the schema-anchored city id.',
      );

      final filename = latestDefinition.uri.pathSegments.last;
      final migrationNumber = int.parse(filename.substring(0, 3));
      if (migrationNumber > 112) {
        expect(latestSql, contains('dp.city_name::text'));
        expect(latestSql, contains('dp.country_code::text'));
      }
    });

    test('keeps the sibling profile search city contract explicit', () {
      expect(profileSearchSql, contains('c.name::text'));
      expect(
        profileSearchSql,
        contains('IF auth.uid() IS DISTINCT FROM p_viewer_id THEN'),
      );
      expect(profileSearchSql, contains('p.onboarding_completed = true'));
      expect(profileSearchSql, contains('p.approved_at IS NOT NULL'));
    });
  });
}
