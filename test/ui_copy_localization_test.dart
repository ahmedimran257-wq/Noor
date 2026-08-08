import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silarah/l10n/generated/app_localizations.dart';
import 'package:silarah/l10n/ui_copy.dart';

void main() {
  const translatedLocales = <Locale>[
    Locale('ar'),
    Locale('bn'),
    Locale('de'),
    Locale('fr'),
    Locale('hi'),
    Locale('id'),
    Locale('ms'),
    Locale('tr'),
    Locale('ur'),
  ];

  for (final locale in translatedLocales) {
    testWidgets('legacy UI copy changes for ${locale.languageCode}',
        (tester) async {
      late String staticCopy;
      late String dynamicCopy;

      await tester.pumpWidget(
        MaterialApp(
          locale: locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Builder(
            builder: (context) {
              staticCopy = context.uiCopy('No blocked profiles');
              dynamicCopy = context.uiPhotoNumber(2);
              return const UiText('No blocked profiles');
            },
          ),
        ),
      );

      expect(staticCopy, isNot('No blocked profiles'));
      expect(dynamicCopy, isNotEmpty);
      expect(dynamicCopy, contains('2'));
      expect(dynamicCopy, isNot(contains('{number}')));
      expect(find.text(staticCopy), findsOneWidget);
    });
  }

  test('generated compatibility catalog contains no batch markers', () {
    final source = File('lib/l10n/ui_copy.dart').readAsStringSync();
    expect(source, isNot(contains('ZZZSILARAH')));
    expect(source, isNot(contains('__PH')));
  });
}
