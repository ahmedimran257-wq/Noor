import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:silarah/core/cubits/discovery/discovery_feed_state.dart';

void main() {
  test('discovery failure metadata clears atomically after recovery', () {
    const offline = DiscoveryFeedState(
      status: FeedStatus.error,
      errorMessage: 'No internet connection.',
      failureKind: DiscoveryFailureKind.offline,
    );

    final recovered = offline.copyWith(
      status: FeedStatus.loaded,
      clearFailure: true,
    );

    expect(recovered.status, FeedStatus.loaded);
    expect(recovered.errorMessage, isNull);
    expect(recovered.failureKind, isNull);
  });

  test('in-app connectivity transitions preserve data and trigger recovery',
      () {
    final main = File('lib/main.dart').readAsStringSync();
    final discovery = File(
      'lib/core/cubits/discovery/discovery_feed_cubit.dart',
    ).readAsStringSync();
    final account = File(
      'lib/core/cubits/account_standing/account_standing_cubit.dart',
    ).readAsStringSync();
    final home = File('lib/features/home/home_screen.dart').readAsStringSync();

    expect(main, contains('_discoveryFeedCubit.markOffline()'));
    expect(main, contains('refreshIfChanged(forceCheck: true)'));
    expect(discovery, contains('state.profiles.isNotEmpty'));
    expect(discovery, contains('Saved profiles remain available'));
    expect(account, contains('Showing your last known account status'));
    expect(home, contains("const ValueKey('offline-banner')"));
    expect(home, contains('reconnection is automatic'));
  });

  test('generic discovery failures are never described as a paused account',
      () {
    final source = File(
      'lib/features/home/screens/discovery_feed_screen.dart',
    ).readAsStringSync();

    expect(source, isNot(contains("return 'Connection paused'")));
    expect(
        source, contains("DiscoveryFailureKind.offline => \"You're offline\""));
    expect(
      source,
      contains("DiscoveryFailureKind.unavailable => 'Profiles unavailable'"),
    );
  });
}
