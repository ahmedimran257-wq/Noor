import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('production email delivery contract', () {
    late String config;
    late String verificationTemplate;
    late String welcomeTemplate;

    setUpAll(() {
      config = File('supabase/config.toml').readAsStringSync();
      verificationTemplate = File(
        'supabase/auth/email_templates/silarah_verification_code.html',
      ).readAsStringSync();
      welcomeTemplate = File(
        'supabase/auth/email_templates/silarah_welcome_verification_code.html',
      ).readAsStringSync();
    });

    test('uses authenticated Brevo SMTP with an explicit project allowance',
        () {
      expect(config, contains('host = "smtp-relay.brevo.com"'));
      expect(config, contains('admin_email = "noreply@mail.silarah.com"'));
      expect(config, contains('[auth.rate_limit]'));
      expect(config, contains('email_sent = 100'));
      expect(config, contains('max_frequency = "60s"'));
    });

    test('ships a secure branded OTP template', () {
      expect(RegExp(r'\{\{ \.Token \}\}').allMatches(verificationTemplate),
          hasLength(1));
      expect(verificationTemplate, isNot(contains('{{ .ConfirmationURL }}')));
      expect(config, contains('[auth.email.template.magic_link]'));
      expect(config, contains('[auth.email.template.confirmation]'));
      expect(
        config,
        contains(
          'content_path = "./supabase/auth/email_templates/silarah_verification_code.html"',
        ),
      );
      expect(
        config,
        contains(
          'content_path = "./supabase/auth/email_templates/silarah_welcome_verification_code.html"',
        ),
      );
      expect(RegExp(r'\{\{ \.Token \}\}').allMatches(welcomeTemplate),
          hasLength(1));
      expect(welcomeTemplate, isNot(contains('{{ .ConfirmationURL }}')));
      expect(verificationTemplate, contains('Expires in 10 minutes'));
      expect(verificationTemplate, contains('Silarah staff will never ask'));
      expect(verificationTemplate, contains('https://silarah.com/help/'));
      expect(verificationTemplate, contains('https://silarah.com/privacy/'));
      expect(verificationTemplate, contains('background:#f3f1ec'));
      expect(verificationTemplate, contains('background:#ffffff'));
      expect(verificationTemplate, contains('@media only screen'));
      expect(verificationTemplate, contains('noreply@mail.silarah.com'));
      expect(welcomeTemplate, contains('background:#f3f1ec'));
      expect(welcomeTemplate, contains('After verification'));
      expect(welcomeTemplate, contains('noreply@mail.silarah.com'));
      expect(verificationTemplate, isNot(contains('background-color:#09090d')));
      expect(welcomeTemplate, isNot(contains('background-color:#09090d')));
      expect(verificationTemplate.toLowerCase(), isNot(contains('<script')));
      expect(verificationTemplate, isNot(contains('{{ .Email')));
      expect(verificationTemplate, isNot(contains('{{ .Data')));
    });
  });
}
