import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silarah/core/cubits/theme/theme_cubit.dart';
import 'package:silarah/core/theme/app_colors.dart';
import 'package:silarah/core/theme/app_theme.dart';
import 'package:silarah/features/home/widgets/policy_reminder_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    AppColors.activate(SilarahThemeMode.blackWhite);
  });

  testWidgets('policy reminder is complete and overflow-free in every theme',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    for (final mode in SilarahThemeMode.values) {
      AppColors.activate(mode);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.forMode(mode),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => PolicyReminderSheet.show(context),
                child: const Text('Open reminder'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open reminder'));
      await tester.pumpAndSettle();

      expect(find.text("A reminder about Silarah's rules"), findsOneWidget);
      expect(find.text('Read Terms'), findsOneWidget);
      expect(find.text('Read Privacy'), findsOneWidget);
      expect(find.text('Read Guidelines'), findsOneWidget);
      expect(find.text('I understand'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: mode.storageValue);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    }
  });
}
