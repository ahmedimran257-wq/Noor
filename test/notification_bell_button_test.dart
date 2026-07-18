import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silarah/core/cubits/notifications/notifications_cubit.dart';
import 'package:silarah/features/home/widgets/notification_bell_button.dart';

class _TestNotificationsCubit extends NotificationsCubit {
  void showUnread() {
    emit(NotificationsState(items: [
      NotificationItem(
        id: 'unread-1',
        type: 'admin_announcement',
        title: 'Account update',
        body: 'Open to read',
        time: DateTime(2026, 7, 15),
      ),
    ]));
  }

  void markTestNotificationRead() {
    emit(NotificationsState(
      items: state.items.map((item) => item.copyWith(isRead: true)).toList(),
    ));
  }
}

void main() {
  testWidgets('shared notification bell follows realtime unread state',
      (tester) async {
    final cubit = _TestNotificationsCubit();
    addTearDown(cubit.close);
    var taps = 0;

    await tester.pumpWidget(
      BlocProvider<NotificationsCubit>.value(
        value: cubit,
        child: MaterialApp(
          home: Scaffold(
            body: NotificationBellButton(onTap: () => taps++),
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('notification-unread-dot')), findsNothing);

    cubit.showUnread();
    await tester.pumpAndSettle();
    expect(
        find.byKey(const ValueKey('notification-unread-dot')), findsOneWidget);

    await tester.tap(find.byIcon(Icons.notifications_none_rounded));
    await tester.pump();
    expect(taps, 1);

    cubit.markTestNotificationRead();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('notification-unread-dot')), findsNothing);
  });
}
