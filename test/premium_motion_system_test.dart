import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:silarah/core/theme/app_colors.dart';
import 'package:silarah/core/theme/app_theme.dart';
import 'package:silarah/core/widgets/loaders/silarah_shimmer.dart';
import 'package:silarah/features/home/widgets/interest_ceremony_overlay.dart';

void main() {
  tearDown(() => AppColors.activate(SilarahThemeMode.blackWhite));

  test('feature UI cannot bypass the shared premium motion system', () {
    final sourceFiles = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'));
    final offenders = <String>[];
    final prohibited = RegExp(
      r'CircularProgressIndicator|LinearProgressIndicator|'
      r'Curves\.(?:easeOutBack|bounceIn|bounceOut|elasticIn|elasticOut)|'
      r'showModalBottomSheet',
    );

    for (final file in sourceFiles) {
      final source = file.readAsStringSync();
      if (prohibited.hasMatch(source)) offenders.add(file.path);
    }

    expect(
      offenders,
      isEmpty,
      reason: 'Generic motion or modal primitives found in: $offenders',
    );

    final acknowledgement = File(
      'lib/features/home/widgets/interest_ceremony_overlay.dart',
    ).readAsStringSync();
    expect(acknowledgement, isNot(contains('ParticlePainter')));
    expect(acknowledgement, isNot(contains('ceremonyParticles')));
    expect(acknowledgement.toLowerCase(), isNot(contains('confetti')));
  });

  test('modal surfaces use semantic palette tokens in every identity', () {
    for (final mode in SilarahThemeMode.values) {
      final palette = SilarahPalette.forMode(mode);
      final theme = AppTheme.forMode(mode);
      expect(
          theme.bottomSheetTheme.modalBackgroundColor, palette.surfaceElevated);
      expect(theme.bottomSheetTheme.surfaceTintColor, Colors.transparent);
      expect(theme.bottomSheetTheme.modalElevation, 0);
      expect(theme.dialogTheme.backgroundColor, palette.surfaceElevated);
      expect(theme.dialogTheme.surfaceTintColor, Colors.transparent);
      expect(theme.dialogTheme.elevation, 0);
    }
  });

  testWidgets('signature loaders remain stable when motion is reduced', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.forMode(SilarahThemeMode.ivoryEmerald),
        home: const MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SilarahActivityIndicator(),
                  SizedBox(height: 12),
                  SizedBox(
                    width: 180,
                    child: SilarahLinearProgress(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pump(const Duration(seconds: 3));
    expect(tester.takeException(), isNull);
    expect(find.byType(SilarahActivityIndicator), findsOneWidget);
    expect(find.byType(SilarahLinearProgress), findsOneWidget);
  });

  testWidgets('interest acknowledgement is concise under reduced motion', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.forMode(SilarahThemeMode.ivoryEmerald),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showInterestCeremony(
                context,
                firstName: 'Amina',
              ),
              child: const Text('Send'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Send'));
    await tester.pump();
    expect(find.text('Interest Sent'), findsOneWidget);
    expect(find.text('to Amina'), findsOneWidget);
    expect(find.textContaining('May Allah bless'), findsNothing);

    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump();
    expect(find.text('Interest Sent'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
