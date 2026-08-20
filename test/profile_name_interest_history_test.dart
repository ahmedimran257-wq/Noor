import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:silarah/core/cubits/chat/chat_state.dart';
import 'package:silarah/core/models/discovery_profile.dart';

void main() {
  test('member-facing models render complete names without forced punctuation',
      () {
    const profile = DiscoveryProfile(
      id: 'profile-user',
      firstName: 'Khatun',
      lastNameInitial: 'Khatun',
      age: 25,
      cityName: 'Kurnool',
    );
    const conversation = Conversation(
      id: 'match',
      matchName: 'Imran',
      matchLastInitial: 'Ahmed',
      messages: [],
    );

    expect(profile.displayName, 'Khatun Khatun');
    expect(conversation.displayName, 'Imran Ahmed');
    expect(profile.displayName, isNot(endsWith('.')));
    expect(conversation.displayName, isNot(endsWith('.')));
  });

  test('received interest history loads durable response states', () {
    final cubit = File(
      'lib/core/cubits/interests/interests_cubit.dart',
    ).readAsStringSync();
    final home = File('lib/features/home/home_screen.dart').readAsStringSync();

    expect(
      cubit,
      contains(
        ".inFilter('status', ['pending', 'accepted', 'declined', 'expired'])",
      ),
    );
    expect(cubit, contains("status: _parseStatus(row['status'] as String)"));
    expect(home, contains('read<InterestsCubit>().refreshIfChanged()'));
  });

  test('database transports complete surnames on every profile surface', () {
    final migration = File(
      'supabase/migrations/143_full_profile_names.sql',
    ).readAsStringSync();

    expect(migration, contains('p.last_name AS last_name_initial'));
    expect(
      migration,
      contains("coalesce(nullif(p.last_name, ''), '') AS other_last_initial"),
    );
    expect(migration, contains("coalesce(p.last_name, '')"));
    expect(migration, isNot(contains('left(p.last_name, 1)')));
  });
}
