import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('production email delivery contract', () {
    late String config;
    late String verificationTemplate;

    setUpAll(() {
      config = File('supabase/config.toml').readAsStringSync();
      verificationTemplate = File(
        'supabase/auth/email_templates/silarah_verification_code.html',
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
        RegExp(
          r'content_path = "\./supabase/auth/email_templates/silarah_verification_code\.html"',
        ).allMatches(config),
        hasLength(2),
      );
      expect(verificationTemplate, contains('Expires in 10 minutes'));
      expect(verificationTemplate, contains('Silarah staff will never ask'));
      expect(verificationTemplate, contains('https://silarah.com/help/'));
      expect(verificationTemplate, contains('https://silarah.com/privacy/'));
      expect(verificationTemplate.toLowerCase(), isNot(contains('<script')));
      expect(verificationTemplate, isNot(contains('{{ .Email')));
      expect(verificationTemplate, isNot(contains('{{ .Data')));
    });
  });
}
