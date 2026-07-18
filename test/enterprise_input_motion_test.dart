import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silarah/core/widgets/animations/silarah_motion.dart';
import 'package:silarah/core/widgets/inputs/silarah_field_frame.dart';
import 'package:silarah/core/widgets/inputs/silarah_text_field.dart';

void main() {
  testWidgets('shared field has one stable visual edge while focused', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 320,
            child: SilarahTextField(
              hint: 'name@example.com',
              prefixIcon: Icons.alternate_email_rounded,
            ),
          ),
        ),
      ),
    );

    expect(find.byType(SilarahFieldFrame), findsOneWidget);
    final textField = tester.widget<TextField>(find.byType(TextField));
    expect(textField.decoration?.border, InputBorder.none);
    expect(textField.decoration?.enabledBorder, InputBorder.none);
    expect(textField.decoration?.focusedBorder, InputBorder.none);
    expect(textField.decoration?.errorBorder, InputBorder.none);

    final before = tester.getSize(find.byType(SilarahFieldFrame));
    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    final after = tester.getSize(find.byType(SilarahFieldFrame));
    expect(after, before);
  });

  testWidgets('onboarding motion honors reduced-motion preference', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: SilarahEntrance(child: Text('Ready')),
        ),
      ),
    );

    await tester.pump();
    final opacity = tester.widget<Opacity>(find.byType(Opacity).first);
    expect(opacity.opacity, 1);
  });

  test('app fields cannot reintroduce thick focused outlines', () {
    final offenders = <String>[];
    final thickFocus = RegExp(
      r'focusedBorder:\s*OutlineInputBorder\([\s\S]{0,260}?'
      r'width:\s*(?:2(?:\.0)?|1\.[1-9]|AppDimensions\.borderFocus)',
    );

    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (thickFocus.hasMatch(entity.readAsStringSync())) {
        offenders.add(entity.path);
      }
    }

    expect(offenders, isEmpty, reason: 'Thick focus outlines: $offenders');
  });

  test('email onboarding uses the shared field and motion system', () {
    final source = File(
      'lib/features/onboarding/screens/email_verification_screen.dart',
    ).readAsStringSync();

    expect(source, contains('return SilarahTextField('));
    expect(source, contains('SilarahContentSwap('));
    expect(source, contains('SilarahEntrance('));
    expect(source, isNot(contains('class _EmailInputState')));
  });
}
