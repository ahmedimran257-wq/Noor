import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String home;

  setUpAll(() {
    home = File('site/index.html').readAsStringSync();
  });

  test('homepage has a real primary conversion path', () {
    expect(home, contains('href="https://app.silarah.com/"'));
    expect(home, contains('Get Android access'));
    expect(home, contains('Explore the experience'));
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

  test('public site uses the signed Android brand and is not installable', () {
    expect(home, contains('class="brand"'));
    expect(home, contains('<img'));
    expect(home, contains('fictional AI-generated models'));
    expect(home, contains('not members or testimonials'));
    expect(home, contains('href="/favicon-48.png"'));
    expect(home, contains('/assets/silarah-app-icon-v2.png'));
    expect(home, isNot(contains('site.webmanifest')));
    expect(home, isNot(contains('brand-gold-s.svg')));
    expect(File('site/favicon-48.png').existsSync(), isTrue);
    expect(File('site/assets/silarah-wordmark-v2.png').existsSync(), isTrue);
  });

  test('Android handoff is truthful, non-indexable and never starts web auth',
      () {
    final launch = File('site-app/index.html').readAsStringSync();
    expect(launch, contains('Silarah for Android'));
    expect(launch, contains('noindex,nofollow,noarchive'));
    expect(launch, contains('does not currently offer profile registration'));
    expect(launch, contains('Ask about Android access'));
    expect(launch, isNot(contains('site.webmanifest')));
    expect(launch, isNot(contains('main.dart.js')));
    expect(launch, isNot(contains('firebase')));
  });

  test('web identity assets are generated from the signed app icon', () {
    final generator = File('tool/generate_silarah_icon.py').readAsStringSync();
    expect(generator, contains('assets/icon/app_icon.png'));
    expect(generator, contains('site/assets/silarah-app-icon-v2.png'));
    expect(generator, isNot(contains('ImageFont')));
    expect(generator, isNot(contains('brand-gold-s')));
  });

  test('every public page uses current brand, launch copy and privacy identity',
      () {
    final pages = Directory('site')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.html'));

    for (final page in pages) {
      final html = page.readAsStringSync();
      for (final retired in <String>[
        'brand-gold-s',
        'silarah-icon.png',
        'site.webmanifest',
        'Open Silarah',
        'Start your profile',
        'Get Silarah',
        'Imran Ahmed',
        'individual developer',
        '₹300',
      ]) {
        expect(html, isNot(contains(retired)),
            reason: '${page.path} contains retired copy: $retired');
      }
    }
  });

  test('every root-relative public asset and route resolves locally', () {
    final pages = Directory('site')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.html'));
    final references = RegExp(r'''(?:href|src)="(/[^"#]*)"''');

    for (final page in pages) {
      final html = page.readAsStringSync();
      for (final match in references.allMatches(html)) {
        final raw = match.group(1)!;
        final clean = raw.split('?').first;
        if (clean == '/') {
          expect(File('site/index.html').existsSync(), isTrue);
          continue;
        }
        final relative = clean.substring(1);
        final file = File('site/$relative');
        final directoryIndex = File('site/$relative/index.html');
        expect(file.existsSync() || directoryIndex.existsSync(), isTrue,
            reason: '${page.path} references missing $clean');
      }
    }
  });
}
