import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:silarah/core/legal/legal_documents.dart';

void main() {
  const expected = <String, String>{
    'terms': 'Terms of Service',
    'privacy': 'Privacy Policy',
    'community-guidelines': 'Community Guidelines',
    'refund-policy': 'Refund Policy',
    'data-deletion': 'Data Deletion Policy',
    'verification-policy': 'KYC & Verification Policy',
    'photo-moderation-policy': 'Photo Moderation Policy',
    'guardian-policy': 'Guardian / Wali Policy',
  };

  test('all eight launch policies are substantive and uniquely versioned', () {
    expect(LegalDocuments.version, matches(RegExp(r'^\d+\.\d+\.\d+$')));
    expect(LegalDocuments.effectiveDate, isNotEmpty);
    expect(LegalDocuments.all.length, expected.length);
    expect(
      LegalDocuments.all.map((document) => document.slug).toSet(),
      expected.keys.toSet(),
    );

    for (final document in LegalDocuments.all) {
      expect(document.title, expected[document.slug], reason: document.slug);
      expect(document.summary.split(' ').length, greaterThanOrEqualTo(10));
      expect(document.sections.length, greaterThanOrEqualTo(7));
      final content = document.sections
          .map((section) => '${section.title} ${section.body}')
          .join(' ');
      expect(content.split(RegExp(r'\s+')).length, greaterThanOrEqualTo(250),
          reason: '${document.slug} is too short to be a launch policy');
      expect(
        content.toLowerCase(),
        isNot(anyOf(contains('lorem ipsum'), contains('coming soon'))),
      );
    }
  });

  test('public site exposes every policy with canonical metadata', () {
    for (final entry in expected.entries) {
      final file = File('site/${entry.key}/index.html');
      expect(file.existsSync(), isTrue, reason: file.path);
      final html = file.readAsStringSync();
      expect(
        html,
        contains(entry.value.replaceAll('&', '&amp;')),
        reason: file.path,
      );
      expect(html, contains('https://silarah.com/${entry.key}/'));
      expect(html, contains(LegalDocuments.version));
      expect(html, contains(LegalDocuments.effectiveDate));
      expect(html.toLowerCase(), isNot(contains('placeholder')));
      expect(html.toLowerCase(), isNot(contains('coming soon')));
    }

    final sitemap = File('site/sitemap.xml').readAsStringSync();
    for (final slug in expected.keys) {
      expect(sitemap, contains('https://silarah.com/$slug/'));
    }
  });

  test('settings and onboarding use the versioned policy catalogue', () {
    final settings = File('lib/features/home/screens/settings_screen.dart')
        .readAsStringSync();
    final legalGate =
        File('lib/features/onboarding/screens/legal_gate_screen.dart')
            .readAsStringSync();
    final consentService =
        File('lib/core/services/legal_consent_service.dart').readAsStringSync();
    final migration = File(
      'supabase/migrations/134_versioned_legal_policy_consents.sql',
    ).readAsStringSync();

    expect(settings, contains('LegalDocuments.all'));
    expect(legalGate, contains('community-guidelines'));
    expect(consentService, contains('LegalDocuments.version'));
    expect(migration, contains("'community_guidelines'"));
    expect(migration, contains("DEFAULT '${LegalDocuments.version}'"));
  });

  test('account deletion never claims app-store billing is cancelled', () {
    final screen = File('lib/features/home/screens/delete_account_screen.dart')
        .readAsStringSync();
    expect(screen, contains('Cancel store billing separately'));
    expect(screen, contains('does not cancel Apple or Google billing'));
    expect(screen, isNot(contains('Subscriptions cancelled')));
  });
}
