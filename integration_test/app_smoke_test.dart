import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:silarah/core/services/auth_callback_service.dart';
import 'package:silarah/l10n/generated/app_localizations.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
      'verified auth callbacks are recognized without rendering secrets',
      (tester) async {
    final callback = Uri.parse(
      'https://silarah.com/auth/callback?code=secret-auth-code',
    );
    expect(AuthCallbackService.isAuthCallback(callback), isTrue);

    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    expect(find.textContaining('secret-auth-code'), findsNothing);
  });

  for (final locale in AppLocalizations.supportedLocales) {
    testWidgets('${locale.languageCode} critical surfaces are localized',
        (tester) async {
      late AppLocalizations copy;
      await tester.pumpWidget(MaterialApp(
        locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Builder(builder: (context) {
          copy = AppLocalizations.of(context);
          return Text(copy.kyc_title);
        }),
      ));
      await tester.pumpAndSettle();

      expect(copy.kyc_title, isNotEmpty);
      expect(copy.settings_appearance, isNotEmpty);
      expect(copy.referral_title, isNotEmpty);
      expect(copy.chat_noConversationsFound, isNotEmpty);
      if (locale.languageCode != 'en') {
        expect(copy.kyc_title, isNot('Verify your identity'));
        expect(copy.settings_appearance, isNot('Appearance'));
      }
    });
  }
}
