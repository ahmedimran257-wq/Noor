import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('runtime Dart sources remain valid UTF-8 without mojibake', () {
    const suspiciousFragments = <String>[
      'Ã',
      'Ø',
      'Ù',
      'â€',
      'Â·',
      'âœ',
    ];
    final failures = <String>[];

    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (entity.path.contains('l10n${Platform.pathSeparator}generated')) {
        continue;
      }
      final source = entity.readAsStringSync(encoding: utf8);
      for (final fragment in suspiciousFragments) {
        if (source.contains(fragment)) {
          failures.add('${entity.path}: contains "$fragment"');
        }
      }
    }

    expect(failures, isEmpty, reason: failures.join('\n'));
  });

  test('brand Arabic and typographic range separator stay correctly encoded',
      () {
    final discovery = File(
      'lib/features/home/screens/discovery_feed_screen.dart',
    ).readAsStringSync(encoding: utf8);
    final filters = File(
      'lib/features/home/widgets/discovery_filter_bar.dart',
    ).readAsStringSync(encoding: utf8);

    expect(discovery, contains('سيلارا'));
    expect(filters, contains('–'));
  });
}
