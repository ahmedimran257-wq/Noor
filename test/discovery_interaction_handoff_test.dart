import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:silarah/core/cubits/interests/interests_state.dart';
import 'package:silarah/core/models/discovery_profile.dart';

void main() {
  const profile = DiscoveryProfile(
    id: '00000000-0000-0000-0000-000000000002',
    firstName: 'Member',
    lastNameInitial: 'S',
    age: 28,
    cityName: 'Kurnool',
  );
  final now = DateTime.utc(2026, 7, 19);

  InterestEntry entry(InterestStatus status) => InterestEntry(
        id: '00000000-0000-0000-0000-000000000003',
        profile: profile,
        timeAgo: 'Now',
        sentAt: now,
        createdAt: now,
        status: status,
      );

  test('an accepted match hands an empty discovery feed to Chat', () {
    final state = InterestsState(
      matches: [entry(InterestStatus.accepted)],
      sent: [entry(InterestStatus.accepted)],
    );

    expect(state.discoveryHandoff, DiscoveryInteractionHandoff.matched);
  });

  test('active incoming and outgoing requests hand discovery to Interests', () {
    final received = InterestsState(
      received: [entry(InterestStatus.pending)],
    );
    final sent = InterestsState(
      sent: [entry(InterestStatus.pending)],
    );

    expect(
      received.discoveryHandoff,
      DiscoveryInteractionHandoff.receivedInterest,
    );
    expect(sent.discoveryHandoff, DiscoveryInteractionHandoff.sentInterest);
  });

  test('inactive history does not replace the genuine empty-feed guidance', () {
    final state = InterestsState(
      sent: [
        entry(InterestStatus.declined),
        entry(InterestStatus.withdrawn),
        entry(InterestStatus.expired),
      ],
    );

    expect(state.discoveryHandoff, DiscoveryInteractionHandoff.none);
  });

  test('one profile has one authoritative active relationship state', () {
    expect(
      InterestsState(sent: [entry(InterestStatus.pending)])
          .interactionWith(profile.id),
      ProfileInteractionState.pendingSent,
    );
    expect(
      InterestsState(received: [entry(InterestStatus.pending)])
          .interactionWith(profile.id),
      ProfileInteractionState.pendingReceived,
    );
    expect(
      InterestsState(matches: [entry(InterestStatus.accepted)])
          .interactionWith(profile.id),
      ProfileInteractionState.matched,
    );
    expect(
      InterestsState(sent: [entry(InterestStatus.declined)])
          .interactionWith(profile.id),
      ProfileInteractionState.none,
    );
  });

  test('chat, bookmarks, and interest surfaces keep launch-safe contracts', () {
    final chatState =
        File('lib/core/cubits/chat/chat_state.dart').readAsStringSync();
    final chatCubit =
        File('lib/core/cubits/chat/chat_cubit.dart').readAsStringSync();
    final chatScreen =
        File('lib/features/home/screens/chat_screen.dart').readAsStringSync();
    final bookmarks =
        File('lib/core/services/bookmark_service.dart').readAsStringSync();
    final migration = File(
      'supabase/migrations/142_chat_delivery_reliability.sql',
    ).readAsStringSync();

    expect(chatState, contains('final String? photoUrl;'));
    expect(chatCubit, contains('getAuthorizedPhotoUrls'));
    expect(chatCubit, contains('retryMessage'));
    expect(chatScreen, contains('resizeToAvoidBottomInset: true'));
    expect(chatScreen, isNot(contains('SpringKeyboardPadding')));
    expect(bookmarks, contains('_writeQueue'));
    expect(migration, contains('SECURITY DEFINER'));
    expect(migration, contains('EXCEPTION WHEN OTHERS'));
    expect(migration, contains('Message % committed without push enqueue'));
  });

  test('the server keeps active pairs out of duplicate discovery contexts', () {
    final migration = File(
      'supabase/migrations/131_authoritative_global_location_discovery.sql',
    ).readAsStringSync();
    final screen = File(
      'lib/features/home/screens/discovery_feed_screen.dart',
    ).readAsStringSync();

    expect(migration, contains("i.status IN ('pending', 'accepted')"));
    expect(screen, contains('discovery_handoff_match_title'));
    expect(screen, contains('discovery_handoff_interest_title'));
    expect(screen, contains('loadInitial(force: true)'));
  });
}
