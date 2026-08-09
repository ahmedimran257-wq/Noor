import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:silarah/core/cubits/locale/locale_cubit.dart';
import 'package:silarah/l10n/generated/app_localizations.dart';
import 'package:silarah/l10n/ui_copy.dart';
import 'package:silarah/l10n/ui_copy_supplement.dart';

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

  test('all statically rendered UI copy is translated in every locale', () {
    final requiredCopy = <String>{
      'ACCOUNT STANDING',
      'Add an approved profile photo before browsing discovery.',
      'All Filters',
      'Account status could not be refreshed.',
      'Check connection',
      'Complete your profile before browsing discovery.',
      'Live in discovery',
      'No internet connection. Connect to open your photo gallery.',
      'No internet connection. Saved content remains available and reconnection is automatic.',
      'No internet connection. Saved profiles remain available and reconnection is automatic.',
      'No internet connection. Showing your last known account status.',
      'Profile not live yet',
      'Please sign in to view discovery profiles.',
      'Profiles are temporarily unavailable. Please try again.',
      'Profiles unavailable',
      'Send Interest Again',
      'Sign in required',
      'Silarah is temporarily unavailable. Saved content remains available and retry is automatic.',
      'Unlock Chat',
      'Unable to load profiles. Please try again.',
      'Your presence on Silarah',
      'Your primary photo must pass the safety scan before discovery.',
      'Your profile must be visible before discovery.',
      "You're offline",
    };
    final directCopy = RegExp(
      r'''(?:UiText|\.uiCopy)\(\s*(["'])(?<text>(?:\\.|(?!\1).)*?)\1''',
      multiLine: true,
      dotAll: true,
    );
    final copyProperty = RegExp(
      r'''(?:label|title|subtitle|body|message|errorMessage|ctaLabel|semanticLabel|hintText|helperText|emptyText|description)\s*:\s*(["'])(?<text>(?:\\.|(?!\1).)*?)\1''',
      multiLine: true,
      dotAll: true,
    );

    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final normalized = entity.path.replaceAll('\\', '/');
      if (normalized.contains('/l10n/') ||
          normalized.endsWith('/language_selection_screen.dart')) {
        continue;
      }
      final source = entity.readAsStringSync();
      for (final pattern in [directCopy, copyProperty]) {
        for (final match in pattern.allMatches(source)) {
          final value = _decodeDartLiteral(match.namedGroup('text')!);
          if (_isTranslatableUiCopy(value)) requiredCopy.add(value);
        }
      }
    }

    for (final locale in _completeLocales.where((code) => code != 'en')) {
      final missing = requiredCopy
          .where((source) => !UiCopy.hasTranslation(locale, source))
          .toList()
        ..sort();
      expect(missing, isEmpty, reason: '$locale: ${missing.join(' | ')}');
    }
  });

  test('supplemental UI catalog is complete and contains no batch markers', () {
    final expectedKeys = supplementalUiCopy['ar']!.keys.toSet();
    for (final locale in _completeLocales.where((code) => code != 'en')) {
      expect(supplementalUiCopy[locale]?.keys.toSet(), expectedKeys,
          reason: locale);
    }
    final source = File('lib/l10n/ui_copy_supplement.dart').readAsStringSync();
    expect(source, isNot(contains('ZZZSILARAH')));
    expect(source, isNot(contains('__PH')));
    expect(source, isNot(contains('PLACEHOLDER')));
  });
}

bool _isTranslatableUiCopy(String value) {
  if (value.contains(r'$') || !RegExp(r'[A-Za-z]').hasMatch(value)) {
    return false;
  }
  if (RegExp(r'^\d+(?:\.\d+)?%?$').hasMatch(value.trim())) return false;
  if (value == 'SILARAH' || value.contains('@silarah.com')) return false;
  return value.length <= 500;
}

String _decodeDartLiteral(String value) => value
    .replaceAll(r'\n', '\n')
    .replaceAll(r"\'", "'")
    .replaceAll(r'\"', '"')
    .replaceAll(r'\\', r'\');

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
