import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:silarah/core/cubits/subscription/subscription_state.dart';
import 'package:silarah/core/services/compatibility_service.dart';
import 'package:silarah/core/services/incognito_service.dart';
import 'package:silarah/core/services/shortlist_service.dart';
import 'package:silarah/core/utils/notification_deep_link.dart';

void main() {
  test('Premium entitlement gates all three relationship tools', () {
    const free = SubscriptionState();
    const premium = SubscriptionState(status: SubscriptionStatus.active);

    expect(free.canViewCompatibilityInsights, isFalse);
    expect(free.canOrganizeShortlists, isFalse);
    expect(free.canUseIncognito, isFalse);
    expect(premium.canViewCompatibilityInsights, isTrue);
    expect(premium.canOrganizeShortlists, isTrue);
    expect(premium.canUseIncognito, isTrue);
  });

  test('compatibility parses aggregate criteria without raw preferences', () {
    final insight = CompatibilityInsight.fromJson({
      'matched_count': 5,
      'total_count': 7,
      'criteria': [
        {
          'key': 'deen',
          'matched_count': 2,
          'total_count': 2,
          'status': 'aligned',
        },
      ],
      'disclaimer': 'Stated preferences only.',
    });

    expect(insight.fraction, closeTo(5 / 7, 0.0001));
    expect(insight.criteria.single.key, 'deen');
    expect(insight.criteria.single.status, 'aligned');
  });

  test('shortlist and Incognito payloads preserve privacy state', () {
    final reminder = DateTime.now().toUtc().add(const Duration(days: 1));
    final detail = ShortlistDetail.fromJson({
      'saved_user_id': 'candidate',
      'list_key': 'discuss_with_family',
      'private_note': '  Ask about relocation  ',
      'remind_at': reminder.toIso8601String(),
    });
    final setting = IncognitoSetting.fromJson({
      'requested': true,
      'enabled': true,
      'can_enable': true,
      'effective_until': reminder.toIso8601String(),
    });

    expect(detail.category, ShortlistCategory.discussWithFamily);
    expect(detail.privateNote, 'Ask about relocation');
    expect(detail.hasPendingReminder, isTrue);
    expect(setting.requested, isTrue);
    expect(setting.enabled, isTrue);
    expect(setting.canEnable, isTrue);
  });

  test('shortlist reminders open the authenticated shortlist route', () {
    expect(notificationPathFromDeepLink('silarah://shortlist'), '/shortlist');
  });

  test('server implementation is bounded and avoids discovery N+1 work', () {
    final migration = File(
      'supabase/migrations/251_premium_compatibility_shortlists_and_incognito.sql',
    ).readAsStringSync();
    final compatibility = File(
      'lib/core/services/compatibility_service.dart',
    ).readAsStringSync();
    final profiles = File(
      'lib/core/services/authorized_profile_service.dart',
    ).readAsStringSync();

    expect(migration, contains('LIMIT v_limit'));
    expect(migration, contains("'17 * * * *'"));
    expect(migration, contains('LIMIT 50'));
    expect(migration, contains('private.can_access_incognito_profile'));
    expect(compatibility, contains('Discovery cards never trigger this RPC'));
    expect(compatibility, contains('Duration(minutes: 5)'));
    expect(profiles, contains('loadDiscoveryProfiles'));
    expect(profiles, contains('getAuthorizedPhotoUrls'));
  });

  test('paywall, website and Play listing describe the same feature set', () {
    final paywall = File(
      'lib/features/home/screens/subscription_screen.dart',
    ).readAsStringSync();
    final home = File('site/index.html').readAsStringSync();
    final listing = File('release/play-listing.md').readAsStringSync();

    for (final source in [paywall, home, listing]) {
      expect(source.toLowerCase(), contains('compatibility'));
      expect(source.toLowerCase(), contains('shortlist'));
      expect(source.toLowerCase(), contains('incognito'));
    }
  });
}
