import 'package:flutter_test/flutter_test.dart';
import 'package:silarah/core/services/support_email.dart';

void main() {
  test('support mail link reads naturally in Gmail and Apple Mail', () {
    final uri = supportEmailUri(
      SupportInbox.support,
      appVersion: '1.0.0 (42045)',
      device: 'Android 14',
      memberId: '3f2a9c1e-5b7d-4c11-9a0e-000000000000',
    );
    final raw = uri.toString();

    expect(uri.scheme, 'mailto');
    expect(uri.path, 'support@silarah.com');
    // Form encoding shows spaces as "+" in mail apps; keep %20 encoding.
    expect(raw, isNot(contains('+')));
    expect(raw, contains('subject=Help%20with%20my%20Silarah%20account'));

    final body = Uri.decodeComponent(raw.split('&body=').last);
    expect(body, startsWith('Assalamu alaikum Silarah team,'));
    expect(body, contains('App: Silarah 1.0.0 (42045)'));
    expect(body, contains('Device: Android 14'));
    expect(body, contains('Member reference: 3f2a9c1e\n'));
    expect(body, isNot(contains('5b7d')));
    expect(body, contains('never send OTP codes, passwords or card details'));
  });

  test('each inbox has its own subject and prompt', () {
    final subjects = SupportInbox.values.map((inbox) => inbox.subject).toSet();
    expect(subjects, hasLength(SupportInbox.values.length));
    final safety = Uri.decodeComponent(
      supportEmailUri(SupportInbox.safety).toString(),
    );
    expect(safety, contains('mailto:safety@silarah.com'));
    expect(safety, contains('immediate danger'));
    expect(safety, isNot(contains('Member reference')));
  });
}
