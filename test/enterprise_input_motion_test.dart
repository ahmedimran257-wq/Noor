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

  testWidgets('shared size reveal clips from its configured alignment', (
    tester,
  ) async {
    final controller = AnimationController(
      vsync: tester,
      duration: const Duration(milliseconds: 200),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SilarahSizeReveal(
            factor: controller,
            child: const SizedBox(width: 80, height: 100),
          ),
        ),
      ),
    );

    expect(tester.getSize(find.byType(SilarahSizeReveal)).height, 0);
    controller.value = 0.5;
    await tester.pump();
    expect(tester.getSize(find.byType(SilarahSizeReveal)).height, 50);
    controller.value = 1;
    await tester.pump();
    expect(tester.getSize(find.byType(SilarahSizeReveal)).height, 100);
  });

  test('motion call sites stay compatible with old and new Flutter stable', () {
    final files = <String>[
      'lib/features/home/screens/chat_screen.dart',
      'lib/features/onboarding/screens/photo_upload_screen.dart',
      'lib/features/onboarding/screens/profile_for_whom_screen.dart',
    ];
    final sources = files.map((path) => File(path).readAsStringSync()).join();

    expect(sources, isNot(contains('axisAlignment:')));
    expect(sources, isNot(contains('SizeTransition(')));
    expect(sources, contains('SilarahSizeReveal('));
  });

  test('CI actions and toolchains are immutable', () {
    final workflow = File('.github/workflows/ci.yml').readAsStringSync();

    expect(
      RegExp(r'uses:\s+\S+@v\d').hasMatch(workflow),
      isFalse,
      reason: 'Actions must use immutable commit SHAs, not mutable tags.',
    );
    expect(
      RegExp(r'uses:\s+\S+@[0-9a-f]{40}').allMatches(workflow).length,
      greaterThanOrEqualTo(6),
    );
    expect(workflow, contains('flutter-version: "3.41.4"'));
    expect(workflow, contains('deno-version: "2.8.1"'));
    expect(workflow, contains('version: "2.110.0"'));
    expect(workflow, isNot(contains('version: latest')));
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

  test('parent-owned fields cannot inherit a second decoration shell', () {
    final offenders = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final source = entity.readAsStringSync();
      for (final block in _inputDecorationBlocks(source)) {
        if (!block.contains('border: InputBorder.none')) continue;
        final ownsNoChrome = block.contains('filled: false') &&
            block.contains('enabledBorder: InputBorder.none') &&
            block.contains('focusedBorder: InputBorder.none') &&
            block.contains('disabledBorder: InputBorder.none') &&
            block.contains('errorBorder: InputBorder.none') &&
            block.contains('focusedErrorBorder: InputBorder.none');
        if (!ownsNoChrome) offenders.add(entity.path);
      }
    }

    expect(
      offenders,
      isEmpty,
      reason: 'Bare inputs inheriting nested theme chrome: $offenders',
    );
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

Iterable<String> _inputDecorationBlocks(String source) sync* {
  const marker = 'InputDecoration(';
  var cursor = 0;
  while (true) {
    final start = source.indexOf(marker, cursor);
    if (start < 0) return;
    var depth = 0;
    var end = start;
    for (; end < source.length; end++) {
      final char = source[end];
      if (char == '(') depth++;
      if (char == ')') {
        depth--;
        if (depth == 0) {
          end++;
          break;
        }
      }
    }
    yield source.substring(start, end.clamp(start, source.length));
    cursor = end;
  }
}
