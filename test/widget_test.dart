// test/widget_test.dart
// ============================================================
// NOOR — Widget Tests (Step 4 stub)
// Full test coverage added in Step 6 (QA Sprint).
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noor/main.dart';

void main() {
  testWidgets('NoorApp smoke test — renders splash screen', (WidgetTester tester) async {
    await tester.pumpWidget(const NoorApp());
    await tester.pump(const Duration(milliseconds: 500));
    // App should render without throwing.
    expect(find.byType(MaterialApp), findsNothing); // uses MaterialApp.router
    expect(find.byType(Router<Object>), findsOneWidget);
  });
}
