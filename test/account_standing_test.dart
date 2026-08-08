import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:silarah/core/cubits/account_standing/account_standing_state.dart';

void main() {
  test('paused and enforced account states always require a persistent notice',
      () {
    for (final kind in [
      AccountStandingKind.paused,
      AccountStandingKind.suspended,
      AccountStandingKind.banned,
      AccountStandingKind.deactivated,
    ]) {
      expect(AccountStandingState(kind: kind).showsPersistentNotice, isTrue);
    }
    expect(
      const AccountStandingState(kind: AccountStandingKind.active)
          .showsPersistentNotice,
      isFalse,
    );
  });

  test('edit profile has one canonical placement in the Profile tab', () {
    final settings = File('lib/features/home/screens/settings_screen.dart')
        .readAsStringSync();
    final profile = File('lib/features/home/screens/my_profile_screen.dart')
        .readAsStringSync();
    expect(settings, isNot(contains('settings_label_editProfile')));
    expect(settings, isNot(contains('AppRoutes.editProfile')));
    expect(profile, contains('_ProfilePrimaryActions('));
    expect(profile, contains("UiText(context.uiCopy('Edit profile')"));
  });

  test(
      'account standing is realtime, global, actionable, and not notification dependent',
      () {
    final cubit = File(
      'lib/core/cubits/account_standing/account_standing_cubit.dart',
    ).readAsStringSync();
    final home = File('lib/features/home/home_screen.dart').readAsStringSync();
    final profile = File('lib/features/home/screens/my_profile_screen.dart')
        .readAsStringSync();
    final migration = File(
      'supabase/migrations/126_realtime_account_standing.sql',
    ).readAsStringSync();

    expect(cubit, contains("channel('account_standing_\$userId')"));
    expect(cubit, contains("rpc(\n        'set_profile_pause'"));
    expect(home, contains('_PersistentStandingBanner'));
    expect(home, contains("'Resume'"));
    expect(home, contains("'Get help'"));
    expect(profile.indexOf('_ProfileLifecycleCard('),
        lessThan(profile.indexOf('_ProfilePreviewCard(')));
    expect(
        migration,
        contains(
            'ALTER PUBLICATION supabase_realtime ADD TABLE public.profiles'));
  });

  test('silent shadowban semantics remain isolated from user-visible standing',
      () {
    final cubit = File(
      'lib/core/cubits/account_standing/account_standing_cubit.dart',
    ).readAsStringSync();
    final moderation = File(
      'supabase/migrations/120_silent_shadowban_and_admin_status.sql',
    ).readAsStringSync();
    expect(cubit, isNot(contains("select('is_shadowbanned')")));
    expect(moderation, contains('Deliberately silent'));
    expect(moderation, contains("p_action = 'shadowban'"));
  });
}
