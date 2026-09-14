import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silarah/core/cubits/notifications/notifications_cubit.dart';
import 'package:silarah/core/theme/app_colors.dart';
import 'package:silarah/core/theme/app_theme.dart';
import 'package:silarah/core/theme/app_typography.dart';
import 'package:silarah/features/home/widgets/profile_header_action_rail.dart';

NotificationItem _notification({
  required String id,
  required String type,
  bool isRead = false,
}) {
  return NotificationItem(
    id: id,
    type: type,
    title: 'Title',
    body: 'Body',
    time: DateTime(2026),
    isRead: isRead,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    AppColors.activate(SilarahThemeMode.blackWhite);
  });

  test('profile-view alerts are partitioned from the bell count', () {
    final state = NotificationsState(items: [
      _notification(id: 'profile-new', type: 'profile_view'),
      _notification(id: 'message-new', type: 'new_message'),
      _notification(id: 'profile-read', type: 'profile_view', isRead: true),
    ]);

    expect(state.unreadCount, 2);
    expect(state.profileViewUnreadAlertCount, 1);
    expect(state.bellUnreadCount, 1);
  });

  testWidgets('premium activity rail is compact in every theme',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    for (final mode in SilarahThemeMode.values) {
      var viewsOpened = 0;
      var notificationsOpened = 0;
      var settingsOpened = 0;
      final notifications = NotificationsCubit();

      await tester.pumpWidget(
        BlocProvider<NotificationsCubit>.value(
          value: notifications,
          child: MaterialApp(
            theme: AppTheme.forMode(mode),
            home: Scaffold(
              body: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Profile', style: AppTypography.screenTitle),
                            Text(
                              'Your presence on Silarah',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.caption,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      ProfileHeaderActionRail(
                        unseenViewCount: 123,
                        onProfileViews: () => viewsOpened++,
                        onNotifications: () => notificationsOpened++,
                        onSettings: () => settingsOpened++,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('99+'), findsOneWidget, reason: mode.storageValue);
      expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
      expect(find.byIcon(Icons.notifications_none_rounded), findsOneWidget);
      expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
      expect(tester.takeException(), isNull, reason: mode.storageValue);

      await tester.tap(find.byKey(const ValueKey('profile-views-action')));
      await tester
          .tap(find.byKey(const ValueKey('profile-notification-action')));
      await tester.tap(find.byKey(const ValueKey('profile-settings-action')));
      expect(viewsOpened, 1);
      expect(notificationsOpened, 1);
      expect(settingsOpened, 1);

      await tester.pumpWidget(const SizedBox.shrink());
      await notifications.close();
    }
  });

  testWidgets('read state removes the numeral without removing the eye',
      (tester) async {
    final notifications = NotificationsCubit();
    addTearDown(notifications.close);

    await tester.pumpWidget(
      BlocProvider<NotificationsCubit>.value(
        value: notifications,
        child: MaterialApp(
          theme: AppTheme.forMode(SilarahThemeMode.blackWhite),
          home: ProfileHeaderActionRail(
            unseenViewCount: 0,
            onProfileViews: () {},
            onNotifications: () {},
            onSettings: () {},
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
    expect(
      find.byKey(const ValueKey('profile-views-unseen-count')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });
}
