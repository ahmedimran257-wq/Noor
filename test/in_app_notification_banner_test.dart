import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silarah/core/cubits/notifications/notifications_cubit.dart';
import 'package:silarah/core/widgets/in_app_notification_banner.dart';

void main() {
  testWidgets('realtime banner is overlay-safe and constrained on a phone',
      (tester) async {
    final notifications = StreamController<NotificationItem>.broadcast();
    addTearDown(notifications.close);

    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => InAppNotificationBannerHost(
          notifications: notifications.stream,
          onTap: (_) {},
          child: child ?? const SizedBox.shrink(),
        ),
        home: const Scaffold(body: SizedBox.expand()),
      ),
    );

    notifications.add(
      NotificationItem(
        id: 'notification-1',
        type: 'admin_announcement',
        title: 'Important account update with a long title',
        body:
            'This intentionally long notification body verifies that the banner remains inside a narrow phone viewport.',
        time: DateTime(2026, 7, 13),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(tester.takeException(), isNull);
    expect(find.textContaining('Important account update'), findsOneWidget);
    expect(find.byIcon(Icons.close_rounded), findsOneWidget);

    final banner = tester.getRect(find.byType(Dismissible));
    expect(banner.left, greaterThanOrEqualTo(0));
    expect(banner.right, lessThanOrEqualTo(320));
  });
}
