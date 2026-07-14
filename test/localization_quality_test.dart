import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:silarah/core/cubits/locale/locale_cubit.dart';
import 'package:silarah/l10n/generated/app_localizations.dart';

const _completeLocales = {
  'ar',
  'bn',
  'de',
  'en',
  'fr',
  'hi',
  'id',
  'ms',
  'tr',
  'ur',
};

void main() {
  test('only complete production locales are shipped', () {
    final localeCodes = AppLocalizations.supportedLocales
        .map((locale) => locale.languageCode)
        .toSet();

    expect(localeCodes, _completeLocales);
    expect(LocaleCubit.supportedLanguageCodes, localeCodes);
    expect(Directory('lib/l10n/_phase2_stubs').existsSync(), isFalse);

    final arbFiles = Directory('lib/l10n')
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('.arb'))
        .map((file) => file.uri.pathSegments.last)
        .toSet();

    expect(
      arbFiles,
      _completeLocales.map((locale) => 'app_$locale.arb').toSet(),
    );
  });

  test('all ARB files contain the same message keys and placeholders', () {
    final english = _messageKeys('lib/l10n/app_en.arb');

    for (final locale in _completeLocales) {
      final path = 'lib/l10n/app_$locale.arb';
      final keys = _messageKeys(path);
      expect(keys.difference(english), isEmpty, reason: path);
      expect(english.difference(keys), isEmpty, reason: path);
      _expectPlaceholdersMatch('lib/l10n/app_en.arb', path);
      _expectNoGeneratorTokens(path);
    }
  });
}

Set<String> _messageKeys(String path) {
  final data =
      jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
  return data.keys.where((key) => !key.startsWith('@')).toSet();
}

void _expectPlaceholdersMatch(String sourcePath, String localePath) {
  final source =
      jsonDecode(File(sourcePath).readAsStringSync()) as Map<String, dynamic>;
  final locale =
      jsonDecode(File(localePath).readAsStringSync()) as Map<String, dynamic>;
  final placeholder = RegExp(r'\{[A-Za-z_][A-Za-z0-9_]*\}');

  for (final entry in source.entries) {
    if (entry.key.startsWith('@')) continue;
    final sourcePlaceholders =
        placeholder.allMatches('${entry.value}').map((m) => m.group(0)).toSet();
    final localePlaceholders = placeholder
        .allMatches('${locale[entry.key]}')
        .map((m) => m.group(0))
        .toSet();
    expect(localePlaceholders, sourcePlaceholders,
        reason: '$localePath:${entry.key}');
  }
}

void _expectNoGeneratorTokens(String localePath) {
  final text = File(localePath).readAsStringSync();
  expect(text.contains('<ph'), isFalse, reason: localePath);
  expect(text.contains('brand0'), isFalse, reason: localePath);
  expect(text.contains('PLACEHOLDER'), isFalse, reason: localePath);
}
