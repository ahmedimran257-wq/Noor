import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silarah/core/theme/silarah_spring.dart';
import 'package:silarah/core/widgets/buttons/silarah_pressable.dart';

void main() {
  test('spring curve never emits unsafe interpolation values', () {
    const curve = SpringCurve(
      spring: SilarahSpring.snappy,
      duration: Duration(milliseconds: 320),
    );

    for (var step = 0; step <= 1000; step++) {
      final value = curve.transform(step / 1000);
      expect(value, inInclusiveRange(0.0, 1.0));
    }
  });

  testWidgets('enterprise pressable fires once and exposes button semantics',
      (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SilarahPressable(
            semanticLabel: 'Open profile settings',
            onTap: () => taps++,
            child: const SizedBox(width: 120, height: 48),
          ),
        ),
      ),
    );

    expect(find.bySemanticsLabel('Open profile settings'), findsOneWidget);
    await tester.tap(find.byType(SilarahPressable));
    await tester.pumpAndSettle();
    expect(taps, 1);
  });

  testWidgets('disabled enterprise pressable cannot invoke its action',
      (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SilarahPressable(
            enabled: false,
            onTap: () => taps++,
            child: const SizedBox(width: 120, height: 48),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(SilarahPressable));
    await tester.pumpAndSettle();
    expect(taps, 0);
  });
}
