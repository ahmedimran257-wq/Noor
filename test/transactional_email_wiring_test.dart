import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String source(String path) => File(path).readAsStringSync();

void main() {
  test('new signup and returning sign-in use distinct OTP templates', () {
    final config = source('supabase/config.toml');
    final welcome = source(
      'supabase/auth/email_templates/silarah_welcome_verification_code.html',
    );
    final signIn = source(
      'supabase/auth/email_templates/silarah_verification_code.html',
    );

    expect(config, contains('[auth.email.template.confirmation]'));
    expect(config, contains('silarah_welcome_verification_code.html'));
    expect(config, contains('[auth.email.template.magic_link]'));
    expect(welcome, contains('{{ .Token }}'));
    expect(welcome, contains('Welcome to Silarah'));
    expect(welcome, isNot(contains('{{ .ConfirmationURL }}')));
    expect(signIn, contains('{{ .Token }}'));
  });

  test('RevenueCat billing email is server-only, durable, and idempotent', () {
    final webhook = source('supabase/functions/revenuecat-webhook/index.ts');
    final migration = source(
      'supabase/migrations/127_transactional_subscription_email_outbox.sql',
    );
    final renderer = source(
      'supabase/functions/_shared/transactional_email.ts',
    );

    expect(webhook, contains('REVENUECAT_WEBHOOK_SECRET'));
    expect(webhook, contains('claim_transactional_email'));
    expect(webhook, contains('sendBrevoTransactionalEmail'));
    expect(webhook, contains('Email delivery deferred'));
    expect(migration, contains('transactional_email_outbox'));
    expect(migration, contains('UNIQUE'));
    expect(migration, contains("status = 'sending'"));
    expect(migration, contains('attempts < 8'));
    expect(renderer, contains('https://api.brevo.com/v3/smtp/email'));
    expect(renderer, contains('noreply@mail.silarah.com'));
    expect(renderer, contains('textContent'));
    expect(renderer, contains('escapeHtml'));
  });

  test('Brevo no-expiration credential cannot become idle', () {
    final keepalive = source(
      'supabase/functions/brevo-key-keepalive/index.ts',
    );
    final schedule = source(
      'supabase/migrations/128_brevo_api_key_keepalive.sql',
    );

    expect(keepalive, contains('isAuthorizedCronRequest'));
    expect(keepalive, contains('https://api.brevo.com/v3/account'));
    expect(keepalive, isNot(contains('/v3/smtp/email')));
    expect(schedule, contains("'brevo_api_key_keepalive'"));
    expect(schedule, contains("'10 4 1 * *'"));
    expect(schedule, contains("'x-cron-secret'"));
  });
}
