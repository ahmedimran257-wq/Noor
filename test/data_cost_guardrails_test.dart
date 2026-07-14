import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  String source(String path) => File(path).readAsStringSync();

  test('background health and presence writes are low-frequency', () {
    final connectivity = source('lib/core/services/connectivity_service.dart');
    final presence = source('lib/core/services/presence_service.dart');
    final main = source('lib/main.dart');

    expect(connectivity, contains('Duration(minutes: 5)'));
    expect(connectivity, contains('_offlineRetryInterval'));
    expect(connectivity, contains('if (!_isForeground)'));
    expect(main, isNot(contains('checkInterval: const Duration(seconds: 10)')));
    expect(presence, contains('Duration(minutes: 5)'));
    expect(presence, contains('_duplicateStateWindow'));
  });

  test('chat and notification reads are event-driven and bounded', () {
    final chatList = source('lib/features/home/screens/chat_list_screen.dart');
    final chat = source('lib/core/cubits/chat/chat_cubit.dart');
    final notifications =
        source('lib/core/cubits/notifications/notifications_cubit.dart');

    expect(chatList, isNot(contains('Timer.periodic')));
    expect(chat, contains('_inboxFreshness'));
    expect(chat, contains('_inboxLoadInFlight'));
    expect(chat, isNot(contains('unawaited(loadConversations());')));
    expect(notifications, contains('_maxRetainedNotifications = 100'));
    expect(notifications, contains('.limit(_maxRetainedNotifications)'));
    expect(notifications, contains('_freshness = Duration(minutes: 5)'));
  });

  test('signed photo URLs and bookmarks are account-scoped caches', () {
    final photos = source('lib/core/services/profile_photo_service.dart');
    final bookmarks = source('lib/core/services/bookmark_service.dart');

    expect(photos, contains('_readUrlCache'));
    expect(photos, contains('_readUrlLoads'));
    expect(photos, contains('_signedUrlSafetyMargin'));
    expect(photos, contains('_maxCachedUrls = 200'));
    expect(bookmarks, contains('_cachedUserId'));
    expect(bookmarks, contains('_loadInFlight'));
    expect(bookmarks, contains('_freshness = Duration(minutes: 5)'));
  });

  test('large relational screens batch instead of querying per person', () {
    final interests = source('lib/core/cubits/interests/interests_cubit.dart');
    final blocks =
        source('lib/core/cubits/block_report/block_report_cubit.dart');
    final home = source('lib/features/home/home_screen.dart');

    expect(interests, contains('Future.wait<dynamic>'));
    expect(interests, contains('_loadProfilesForUsers'));
    expect(interests, isNot(contains('_loadProfileForUser')));
    expect(interests, contains('_maxRowsPerSection = 100'));
    expect(blocks, contains(".inFilter('user_id', relatedUserIds"));
    expect(home, contains('List<Widget?>.filled(_tabCount, null)'));
  });

  test('discovery and admin refreshes have explicit cost ceilings', () {
    final discovery =
        source('lib/core/cubits/discovery/discovery_feed_cubit.dart');
    final cockpit = source('admin/src/components/live-operations-cockpit.tsx');
    final adminRefresh = source('admin/src/components/admin-auto-refresh.tsx');

    expect(
      RegExp(r'_loadServerViewQuota\(\)').allMatches(discovery).length,
      2,
    );
    expect(discovery, contains('_viewerReadinessFreshness'));
    expect(cockpit, contains('const refreshMs = 60000'));
    expect(cockpit, contains('if (!document.hidden)'));
    expect(adminRefresh, contains('const refreshMs = 120000'));
  });
}
