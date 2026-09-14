import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silarah/core/router/notification_navigation.dart';

void main() {
  testWidgets('Back from a secondary home tab returns to Discover first',
      (tester) async {
    var returnedToDiscover = false;

    await tester.pumpWidget(
      MaterialApp(
        home: HomeTabBackScope(
          currentTab: 2,
          onReturnToPrimaryTab: () => returnedToDiscover = true,
          child: const Scaffold(body: Text('Messages')),
        ),
      ),
    );

    await tester.binding.handlePopRoute();
    await tester.pump();

    expect(returnedToDiscover, isTrue);
    expect(find.text('Messages'), findsOneWidget);
  });
}
