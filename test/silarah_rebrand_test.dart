import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Silarah rebrand contract', () {
    test('uses the final app and package identifiers', () {
      expect(
          File('pubspec.yaml').readAsStringSync(), contains('name: silarah'));
      final gradle = File('android/app/build.gradle.kts').readAsStringSync();
      expect(gradle, contains('namespace = "com.silarah.app"'));
      expect(gradle, contains('applicationId = "com.silarah.app"'));
      expect(File('ios/Runner/Info.plist').readAsStringSync(),
          contains('<string>Silarah</string>'));
    });

    test('new deep links use Silarah and legacy links remain parseable', () {
      final resolver =
          File('lib/core/utils/notification_deep_link.dart').readAsStringSync();
      expect(resolver, contains("{'silarah', 'mithaq'}"));
      final migration = File(
        'supabase/migrations/117_silarah_complete_rebrand.sql',
      ).readAsStringSync();
      expect(migration, contains("'mithaq://', 'silarah://'"));
      expect(migration, contains("'Mithaq', 'Silarah'"));
    });

    test('active customer-facing source has no old brand copy', () {
      final roots = ['lib', 'admin/src', 'supabase/functions', 'supabase/auth'];
      final violations = <String>[];
      for (final root in roots) {
        final directory = Directory(root);
        if (!directory.existsSync()) continue;
        for (final entity in directory.listSync(recursive: true)) {
          if (entity is! File) continue;
          if (!RegExp(r'\.(dart|ts|tsx|html|arb)$').hasMatch(entity.path)) {
            continue;
          }
          final source = entity.readAsStringSync();
          if (source.contains('Mithaq') || source.contains('mithaq.app')) {
            violations.add(entity.path);
          }
        }
      }
      expect(violations, isEmpty, reason: 'Old brand remains in $violations');
    });
  });
}
