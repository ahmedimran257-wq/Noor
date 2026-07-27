import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:silarah/core/legal/legal_documents.dart';
import 'package:silarah/core/legal/public_site_links.dart';

void main() {
  test('every public page has a canonical URL and an app conversion path', () {
    final pages = Directory('site')
        .listSync(recursive: true)
        .whereType<File>()
        .where(
            (file) => file.path.replaceAll('\\', '/').endsWith('/index.html'))
        .toList();

    expect(pages.length, greaterThanOrEqualTo(16));
    for (final page in pages) {
      final html = page.readAsStringSync();
      expect(html, contains('rel="canonical"'), reason: page.path);
      expect(
        html,
        contains('https://app.silarah.com/'),
        reason: '${page.path} has no route back into Silarah',
      );
    }
  });

  test('all app policy documents resolve to a matching public page', () {
    for (final document in LegalDocuments.all) {
      final file = File('site/${document.slug}/index.html');
      expect(file.existsSync(), isTrue, reason: document.slug);
      expect(
        PublicSiteLinks.policy(document.slug).toString(),
        'https://silarah.com/${document.slug}/',
      );
    }
  });

  test('app exposes official help and policy web routes', () {
    final help = File(
      'lib/features/home/screens/help_support_screen.dart',
    ).readAsStringSync();
    final legal = File(
      'lib/features/home/screens/legal_doc_screen.dart',
    ).readAsStringSync();

    for (final marker in [
      'PublicSiteLinks.help',
      'PublicSiteLinks.faq',
      'PublicSiteLinks.safety',
      'PublicSiteLinks.legal',
      'PublicSiteLinks.about',
    ]) {
      expect(help, contains(marker), reason: marker);
    }
    expect(legal, contains('PublicSiteLinks.policy(document.slug)'));
    expect(legal, contains('Open official web version'));
  });

  test('critical external route constants use secure production hosts', () {
    expect(PublicSiteLinks.app.scheme, 'https');
    expect(PublicSiteLinks.app.host, 'app.silarah.com');
    expect(PublicSiteLinks.help.host, 'silarah.com');
    expect(PublicSiteLinks.deleteAccount.path, '/delete-account/');
  });
}
