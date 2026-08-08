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
    final kyc = File(
      'lib/features/verification/screens/kyc_verification_screen.dart',
    ).readAsStringSync();
    expect(kyc.toLowerCase(), isNot(contains('digilocker')));

    final retirementMigration = File(
      'supabase/migrations/195_retire_digilocker_verification.sql',
    ).readAsStringSync();
    expect(
      retirementMigration,
      contains(
        'DROP TABLE IF EXISTS public.identity_verification_evidence',
      ),
    );
    expect(
      retirementMigration,
      contains('clear selfie plus government-ID photos'),
    );
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
}
