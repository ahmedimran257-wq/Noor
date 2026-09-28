import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silarah/l10n/generated/app_localizations.dart';
import 'package:silarah/l10n/ui_copy.dart';

void main() {
  for (final locale in AppLocalizations.supportedLocales) {
    testWidgets('deletion error hides server details in $locale',
        (tester) async {
      final error =
          StateError('private_table synthetic-secret@example.invalid');
      String? message;
      String? expected;
      await tester.pumpWidget(MaterialApp(
        locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Builder(builder: (context) {
          message = context.uiDeleteFailed(error);
          expected = AppLocalizations.of(context).common_error_generic;
          return const SizedBox();
        }),
      ));
      await tester.pumpAndSettle();
      expect(message, expected);
      expect(message, isNot(contains('private_table')));
      expect(message, isNot(contains('synthetic-secret')));
    });
  }
}
