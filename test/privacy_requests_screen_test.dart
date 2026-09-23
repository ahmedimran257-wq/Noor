import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silarah/core/theme/app_colors.dart';
import 'package:silarah/core/theme/app_theme.dart';
import 'package:silarah/features/home/screens/privacy_requests_screen.dart';

void main() {
  for (final mode in SilarahThemeMode.values) {
    testWidgets('privacy intake remains usable in $mode at large text',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.forMode(mode),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(1.5),
              disableAnimations: true),
          child: child!,
        ),
        home: const PrivacyRequestsScreen(),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Privacy requests'), findsOneWidget);
      expect(tester.takeException(), isNull);
      final submit = find.byType(FilledButton);
      await tester.scrollUntilVisible(submit, 250,
          scrollable: find.byType(Scrollable).first);
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(
          find.text('Please describe your request in at least 10 characters.'),
          findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
