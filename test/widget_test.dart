// test/widget_test.dart
// ============================================================
// Silarah — Widget Tests (Step 4 stub)
// Full test coverage added in Step 6 (QA Sprint).
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silarah/core/services/connectivity_service.dart';
import 'package:silarah/main.dart';

void main() {
  testWidgets('SilarahApp smoke test — renders splash screen',
      (WidgetTester tester) async {
    await tester.pumpWidget(const SilarahApp(initialLocation: '/'));

    // Let one-shot timers (auth check, splash animation, subscription) complete
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    // App should render without throwing.
    expect(find.byType(MaterialApp), findsOneWidget); // uses MaterialApp.router
    expect(find.byType(Router<Object>), findsOneWidget);

    // Cancel connectivity polling timer to prevent pending timers exception
    ConnectivityService.instance.dispose();
  });
}
