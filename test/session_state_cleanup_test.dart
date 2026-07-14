import 'package:flutter_test/flutter_test.dart';
import 'package:silarah/core/cubits/block_report/block_report_cubit.dart';
import 'package:silarah/core/cubits/block_report/block_report_state.dart';
import 'package:silarah/core/cubits/chat/chat_cubit.dart';
import 'package:silarah/core/cubits/chat/chat_state.dart';
import 'package:silarah/core/cubits/discovery/discovery_feed_cubit.dart';
import 'package:silarah/core/cubits/discovery/discovery_feed_state.dart';
import 'package:silarah/core/cubits/interests/interests_cubit.dart';
import 'package:silarah/core/cubits/interests/interests_state.dart';
import 'package:silarah/core/cubits/notifications/notifications_cubit.dart';

class TestChatCubit extends ChatCubit {
  void seed(ChatState value) => emit(value);
}

class TestNotificationsCubit extends NotificationsCubit {
  void seed(NotificationsState value) => emit(value);
}

class TestDiscoveryFeedCubit extends DiscoveryFeedCubit {
  void seed(DiscoveryFeedState value) => emit(value);
}

class TestInterestsCubit extends InterestsCubit {
  void seed(InterestsState value) => emit(value);
}

class TestBlockReportCubit extends BlockReportCubit {
  void seed(BlockReportState value) => emit(value);
}

void main() {
  test('ChatCubit.clear removes session-scoped conversations and messages',
      () async {
    final cubit = TestChatCubit();
    addTearDown(cubit.close);

    cubit.seed(ChatState(
      conversations: [
        Conversation(
          id: 'match-1',
          matchName: 'Private',
          matchLastInitial: 'M',
          unreadCount: 2,
          messages: [
            ChatMessage(
              id: 'msg-1',
              text: 'Sensitive message',
              sentAt: DateTime(2026),
              isMe: false,
            ),
          ],
        ),
      ],
      isLoading: true,
      messagingSuspendedUntil: DateTime(2027),
    ));

    cubit.clear();

    expect(cubit.state.conversations, isEmpty);
    expect(cubit.state.totalUnread, 0);
    expect(cubit.state.isLoading, isFalse);
    expect(cubit.state.messagingSuspendedUntil, isNull);
  });

  test('NotificationsCubit.clear removes session-scoped notifications',
      () async {
    final cubit = TestNotificationsCubit();
    addTearDown(cubit.close);

    cubit.seed(NotificationsState(
      items: [
        NotificationItem(
          id: 'notif-1',
          type: 'message',
          title: 'Private alert',
          body: 'New message',
          time: DateTime(2026),
        ),
      ],
    ));

    cubit.clear();

    expect(cubit.state.items, isEmpty);
    expect(cubit.state.unreadCount, 0);
  });

  test('DiscoveryFeedCubit.clear removes session-scoped feed data', () {
    final cubit = TestDiscoveryFeedCubit();
    addTearDown(cubit.close);

    cubit.seed(const DiscoveryFeedState(
      status: FeedStatus.error,
      errorMessage: 'private account state',
      profilesViewedToday: 9,
      dailyLimit: 10,
      hasMore: false,
    ));

    cubit.clear();

    expect(cubit.state.status, FeedStatus.initial);
    expect(cubit.state.errorMessage, isNull);
    expect(cubit.state.profilesViewedToday, 0);
  });

  test('InterestsCubit.clear removes session-scoped interest state', () {
    final cubit = TestInterestsCubit();
    addTearDown(cubit.close);

    cubit.seed(const InterestsState(
      interestsSentToday: 4,
      dailyLimit: 5,
      limitError: true,
    ));

    cubit.clear();

    expect(cubit.state.received, isEmpty);
    expect(cubit.state.sent, isEmpty);
    expect(cubit.state.matches, isEmpty);
    expect(cubit.state.interestsSentToday, 0);
  });

  test('BlockReportCubit.clear removes hidden profiles and report state', () {
    final cubit = TestBlockReportCubit();
    addTearDown(cubit.close);

    cubit.seed(const BlockReportState(
      hiddenProfileIds: {'profile-a'},
      successMessage: 'done',
      error: 'private error',
    ));

    cubit.clear();

    expect(cubit.state.hiddenProfileIds, isEmpty);
    expect(cubit.state.successMessage, isNull);
    expect(cubit.state.error, isNull);
  });
}
