import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String home;

  setUpAll(() {
    home = File('site/index.html').readAsStringSync();
  });

  test('homepage has a real primary conversion path', () {
    expect(home, contains('href="https://app.silarah.com/"'));
    expect(home, contains('Get Silarah'));
    expect(home, contains('See how it works'));
    expect(home, isNot(contains('Visit Help Center')));
  });

  test('verification language does not confuse liveness with identity', () {
    expect(home, contains('Photo verified'));
    expect(home, contains('not legal identity verification'));
    expect(home, isNot(contains('Verified identities')));
  });

  test('homepage contains substantive discovery, privacy and safety content',
      () {
    for (final phrase in <String>[
      'Create a thoughtful profile',
      'Discover compatible introductions',
      'Communicate with boundaries',
      'Visible to everyone',
      'After mutual interest',
      'Request to view',
      'Block and report',
      'Strictly 18+',
    ]) {
      expect(home, contains(phrase), reason: phrase);
    }
  });

  test('launch-critical public routes are present and indexable', () {
    for (final slug in <String>[
      'about',
      'safety',
      'faq',
      'delete-account',
      'child-safety',
    ]) {
      final page = File('site/$slug/index.html');
      expect(page.existsSync(), isTrue, reason: page.path);
      final html = page.readAsStringSync();
      expect(html, contains('https://silarah.com/$slug/'));
      expect(html.toLowerCase(), isNot(contains('coming soon')));
    }
  });

  test('account deletion can be initiated outside the app', () {
    final deletion = File('site/delete-account/index.html').readAsStringSync();
    expect(deletion, contains('mailto:privacy@silarah.com'));
    expect(deletion, contains('Request account deletion'));
    expect(deletion, contains('What is deleted'));
    expect(deletion, contains('What may be retained'));
  });

  test('child safety standards expose enforcement and a contact', () {
    final safety = File('site/child-safety/index.html').readAsStringSync();
    expect(safety, contains('strictly for adults aged 18 and over'));
    expect(safety, contains('CSAM'));
    expect(safety, contains('safety@silarah.com'));
    expect(safety, contains('permanently ban'));
  });

  test('SEO and social metadata are complete', () {
    for (final marker in <String>[
      'rel="canonical"',
      'property="og:title"',
      'property="og:description"',
      'name="twitter:card"',
      '"@type": "Organization"',
      '"@type": "FAQPage"',
    ]) {
      expect(home, contains(marker), reason: marker);
    }

    final robots = File('site/robots.txt').readAsStringSync();
    final sitemap = File('site/sitemap.xml').readAsStringSync();
    expect(robots, contains('https://silarah.com/sitemap.xml'));
    expect(sitemap, contains('https://silarah.com/delete-account/'));
    expect(sitemap, contains('https://silarah.com/child-safety/'));
  });

  test('public homepage uses honest campaign imagery and a restrained favicon',
      () {
    expect(home, isNot(contains('silarah-icon')));
    expect(home, contains('class="brand"'));
    expect(home, contains('<img'));
    expect(home, contains('fictional AI-generated models'));
    expect(home, contains('not members or testimonials'));
    expect(home, contains('href="/brand-gold-s.svg"'));

    final favicon = File('site/brand-gold-s.svg').readAsStringSync();
    expect(favicon, contains('fill="#0A0A0D"'));
    expect(favicon, contains('fill="#D8AF55"'));
    expect(favicon, contains('>S</text>'));
  });
}
