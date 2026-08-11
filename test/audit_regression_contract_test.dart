import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:silarah/core/services/auth_callback_service.dart';

void main() {
  test('only the verified auth callback is accepted', () {
    expect(
      AuthCallbackService.isAuthCallback(
        Uri.parse('https://silarah.com/auth/callback?code=redacted'),
      ),
      isTrue,
    );
    expect(
      AuthCallbackService.isAuthCallback(
        Uri.parse('https://attacker.example/auth/callback?code=redacted'),
      ),
      isFalse,
    );
  });

  test('auth callback implementation never logs or renders callback values',
      () {
    final source =
        File('lib/core/services/auth_callback_service.dart').readAsStringSync();
    expect(source, isNot(contains('debugPrint(uri')));
    expect(source, isNot(contains('debugPrint(error')));
    expect(source, contains('exchangeCodeForSession'));
    expect(source, contains('setSession(refreshToken)'));
  });

  test('DigiLocker product code and deployment source are absent', () {
    expect(
        File('lib/core/services/digilocker_service.dart').existsSync(), false);
    expect(
      File('supabase/functions/digilocker-verify/index.ts').existsSync(),
      false,
    );
    expect(
      File('lib/features/verification/screens/kyc_verification_screen.dart')
          .existsSync(),
      false,
    );
    expect(File('supabase/functions/process-kyc/index.ts').existsSync(), false);

    final retirementMigration = File(
      'supabase/migrations/195_retire_digilocker_verification.sql',
    ).readAsStringSync();
    expect(
      retirementMigration,
      contains(
        'DROP TABLE IF EXISTS public.identity_verification_evidence',
      ),
    );
    final publicPolicy = File(
      'site/verification-policy/index.html',
    ).readAsStringSync();
    expect(publicPolicy.toLowerCase(), isNot(contains('digilocker')));
    expect(publicPolicy, contains('look at the camera'));
    expect(publicPolicy, contains('gentle smile'));
    expect(publicPolicy, contains('blink once'));
    expect(publicPolicy, contains('government-ID matching'));
    expect(publicPolicy, contains('48 hours'));
  });

  test('Android owns branded notification channels and native share', () {
    final activity = File(
      'android/app/src/main/kotlin/com/silarah/app/MainActivity.kt',
    ).readAsStringSync();
    final manifest =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    expect(activity, contains('silarah_alerts'));
    expect(activity, contains('IMPORTANCE_HIGH'));
    expect(activity, contains('Intent.ACTION_SEND'));
    expect(manifest, contains('default_notification_channel_id'));
  });

  test('block migration preserves completed match cycles', () {
    final migration = File(
      'supabase/migrations/191_preserve_match_history_on_block.sql',
    ).readAsStringSync();
    expect(migration, contains("AND status = 'active'"));
    expect(migration, isNot(contains("AND status <> 'blocked'")));
  });

  test('legacy feature text renders through the localization boundary', () {
    final roots = <Directory>[
      Directory('lib/features'),
      Directory('lib/core/widgets'),
    ];
    final rawTextConstructor = RegExp(r'\bText\(');
    final findings = <String>[];

    for (final root in roots) {
      for (final entity in root.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        if (entity.path.endsWith('language_selection_screen.dart')) continue;
        final source = entity.readAsStringSync();
        if (rawTextConstructor.hasMatch(source)) findings.add(entity.path);
      }
    }

    expect(findings, isEmpty, reason: findings.join('\n'));
  });
}
