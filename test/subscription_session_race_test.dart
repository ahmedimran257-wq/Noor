import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:silarah/core/cubits/subscription/subscription_cubit.dart';
import 'package:silarah/core/services/subscription_service.dart';
import 'package:silarah/core/services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Map<String, dynamic> info({bool premium = false}) {
  final entitlements = {
    if (premium)
      'premium': {
        'identifier': 'premium',
        'isActive': true,
        'willRenew': true,
        'latestPurchaseDate': '2026-01-01T00:00:00Z',
        'originalPurchaseDate': '2026-01-01T00:00:00Z',
        'productIdentifier': 'silarah_monthly',
        'isSandbox': true,
        'expirationDate': '2036-01-01T00:00:00Z',
      },
  };
  return {
    'originalAppUserId': 'fixture-user',
    'entitlements': {'all': entitlements, 'active': entitlements},
    'activeSubscriptions': [],
    'allExpirationDates': {},
    'allPurchasedProductIdentifiers': [],
    'firstSeen': '2026-01-01T00:00:00Z',
    'requestDate': '2026-09-26T00:00:00Z',
    'allPurchaseDates': {},
    'nonSubscriptionTransactions': [],
  };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('purchases_flutter');
  late SupabaseClient client;
  late SubscriptionCubit cubit;
  late List<String> calls;
  Future<Object?> Function(MethodCall)? intercept;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    client = SupabaseClient('https://billing.example.invalid', 'fixture-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((request) async {
      if (request.url.path.endsWith('get_my_premium_entitlement')) {
        return http.Response(
            '[{"is_active":false,"source":"none","expires_at":null}]', 200,
            request: request, headers: {'content-type': 'application/json'});
      }
      return http.Response('[]', 200,
          request: request, headers: {'content-type': 'application/json'});
    }));
    SupabaseService.initializeForTesting(client);
    cubit = SubscriptionCubit();
    calls = [];
    intercept = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      if (intercept != null) return intercept!(call);
      return response(call);
    });
  });

  tearDown(() async {
    cubit.clear();
    await cubit.close();
    SupabaseService.reset();
    await client.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('late login cannot restore Premium after clear', () async {
    final started = Completer<void>();
    final gate = Completer<Object?>();
    intercept = (call) async {
      if (call.method == 'logIn') {
        started.complete();
        return gate.future;
      }
      if (call.method == 'getCustomerInfo') return info(premium: true);
      return response(call);
    };
    final login = cubit.loginUser('fixture-user');
    await started.future;
    cubit.clear();
    gate.complete({'customerInfo': info(premium: true), 'created': false});
    await login;
    expect(cubit.state.isSubscribed, isFalse);
    expect(SubscriptionService.instance.currentPricing, isNull);
  });

  test('late refresh cannot restore Premium after clear', () async {
    await cubit.loginUser('fixture-user');
    final started = Completer<void>();
    final gate = Completer<Object?>();
    intercept = (call) async {
      if (call.method == 'getCustomerInfo') {
        started.complete();
        return gate.future;
      }
      return response(call);
    };
    final refresh = cubit.refreshEntitlement();
    await started.future;
    cubit.clear();
    gate.complete(info(premium: true));
    await refresh;
    expect(cubit.state.isSubscribed, isFalse);
  });

  test('store logout waits for an in-flight identity login', () async {
    final started = Completer<void>();
    final gate = Completer<Object?>();
    intercept = (call) async {
      if (call.method == 'logIn') {
        started.complete();
        return gate.future;
      }
      return response(call);
    };
    final login = cubit.loginUser('fixture-user');
    await started.future;
    final logout = cubit.logoutUser();
    await Future<void>.delayed(Duration.zero);
    final loggedOutBeforeLoginFinished = calls.contains('logOut');
    gate.complete({'customerInfo': info(), 'created': false});
    await Future.wait([login, logout]);
    expect(loggedOutBeforeLoginFinished, isFalse);
    expect(calls.where((call) => call == 'logOut').length, 1);
    expect(cubit.state.isSubscribed, isFalse);
  });

  test('late restore cannot repopulate cleared service cache', () async {
    final started = Completer<void>();
    final gate = Completer<Object?>();
    intercept = (call) async {
      if (call.method == 'restorePurchases') {
        started.complete();
        return gate.future;
      }
      return response(call);
    };
    final restore = SubscriptionService.instance.restorePurchases();
    await started.future;
    SubscriptionService.instance.clearUser();
    gate.complete(info(premium: true));
    expect(await restore, isFalse);
    expect(SubscriptionService.instance.isSubscribed, isFalse);
    expect(SubscriptionService.instance.customerInfo, isNull);
  });

  test('current paid login remains active after initialization', () async {
    intercept = (call) async =>
        call.method == 'getCustomerInfo' ? info(premium: true) : response(call);
    await cubit.loginUser('fixture-user');
    expect(cubit.state.isSubscribed, isTrue);
    await cubit.initialize();
    await cubit.initialize();
    expect(cubit.state.isSubscribed, isTrue);
    expect(cubit.state.hasPaidPremium, isTrue);
  });

  test('rapid account switch serializes SDK identities and keeps latest state',
      () async {
    final started = Completer<void>();
    final gate = Completer<void>();
    final identities = <String>[];
    String? nativeUser;
    intercept = (call) async {
      if (call.method == 'logIn') {
        final user = (call.arguments as Map)['appUserID'] as String;
        identities.add(user);
        if (user == 'old-user') {
          started.complete();
          await gate.future;
        }
        nativeUser = user;
        return {'customerInfo': info(), 'created': false};
      }
      if (call.method == 'getCustomerInfo') {
        return info(premium: nativeUser == 'old-user');
      }
      return response(call);
    };
    final first = cubit.loginUser('old-user');
    await started.future;
    final second = cubit.loginUser('new-user');
    await Future<void>.delayed(Duration.zero);
    final startedBeforeFirstFinished = identities.length;
    gate.complete();
    await Future.wait([first, second]);
    expect(startedBeforeFirstFinished, 1);
    expect(identities, ['old-user', 'new-user']);
    expect(nativeUser, 'new-user');
    expect(cubit.state.isSubscribed, isFalse);
  });

  test('old refresh cannot affect a new session for the same user', () async {
    await cubit.loginUser('fixture-user');
    final started = Completer<void>();
    final gate = Completer<Object?>();
    var pending = true;
    intercept = (call) async {
      if (call.method == 'getCustomerInfo' && pending) {
        pending = false;
        started.complete();
        return gate.future;
      }
      return response(call);
    };
    final refresh = cubit.refreshEntitlement();
    await started.future;
    cubit.clear();
    await cubit.loginUser('fixture-user');
    gate.complete(info(premium: true));
    await refresh;
    expect(cubit.state.isSubscribed, isFalse);
  });

  test('late pricing result cannot restart a cleared cache or retry', () async {
    final started = Completer<void>();
    final gate = Completer<Object?>();
    intercept = (call) async {
      if (call.method == 'syncAttributesAndOfferingsIfNeeded') {
        started.complete();
        return gate.future;
      }
      return response(call);
    };
    final pricing = SubscriptionService.instance.retryPricing();
    await started.future;
    SubscriptionService.instance.clearUser();
    gate.complete({'all': {}, 'current': null});
    await pricing;
    expect(SubscriptionService.instance.currentPricing, isNull);
  });

  test('cached native listener payload cannot grant a different session',
      () async {
    // RevenueCat replays its last native event immediately when a listener
    // is attached. That event can precede the latest identity switch.
    final delivered = Completer<void>();
    ServicesBinding.instance.channelBuffers.push(
      'purchases_flutter',
      const StandardMethodCodec().encodeMethodCall(
        MethodCall('Purchases-CustomerInfoUpdated', info(premium: true)),
      ),
      (_) => delivered.complete(),
    );
    await delivered.future;
    await cubit.loginUser('new-user');
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state.isSubscribed, isFalse);
  });

  test('failed identity switch cannot read the previous store entitlement',
      () async {
    intercept = (call) async {
      if (call.method == 'logIn') {
        throw PlatformException(code: '10', message: 'synthetic offline login');
      }
      if (call.method == 'getCustomerInfo') return info(premium: true);
      return response(call);
    };
    await cubit.loginUser('new-user');
    await cubit.refreshEntitlement();
    expect(cubit.state.isSubscribed, isFalse);
    expect(calls, isNot(contains('getCustomerInfo')));
  });

  for (final storeMethod in ['restorePurchases', 'purchasePackage']) {
    test('logout waits for $storeMethod without restoring cleared access',
        () async {
      await cubit.loginUser('fixture-user');
      final started = Completer<void>();
      final gate = Completer<Object?>();
      intercept = (call) async {
        if (call.method == storeMethod) {
          started.complete();
          return gate.future;
        }
        if (call.method == 'syncAttributesAndOfferingsIfNeeded') {
          return offering();
        }
        return response(call);
      };
      final operation = storeMethod == 'restorePurchases'
          ? cubit.restore()
          : cubit.purchase(SubscriptionCubit.monthlyProductId);
      await started.future;
      final logout = cubit.logoutUser();
      await Future<void>.delayed(Duration.zero);
      final loggedOutTooEarly = calls.contains('logOut');
      gate.complete(storeMethod == 'restorePurchases'
          ? info(premium: true)
          : purchaseResult());
      await operation;
      await logout;
      expect(loggedOutTooEarly, isFalse);
      expect(cubit.state.isSubscribed, isFalse);
      expect(cubit.state.successMessage, isNull);
      expect(SubscriptionService.instance.customerInfo, isNull);
    });
  }

  test('current-session purchase and restore still activate Premium', () async {
    await cubit.loginUser('fixture-user');
    intercept = (call) async => switch (call.method) {
          'syncAttributesAndOfferingsIfNeeded' => offering(),
          'purchasePackage' => purchaseResult(),
          'restorePurchases' || 'getCustomerInfo' => info(premium: true),
          _ => response(call),
        };
    expect(await cubit.purchase(SubscriptionCubit.monthlyProductId), isTrue);
    expect(cubit.state.hasPaidPremium, isTrue);
    cubit.clear();
    await cubit.loginUser('fixture-user');
    await cubit.restore();
    expect(cubit.state.hasPaidPremium, isTrue);
    expect(SubscriptionService.instance.isSubscribed, isTrue);
  });

  test('restore connection failure is not reported as no purchases', () async {
    await cubit.loginUser('fixture-user');
    intercept = (call) async {
      if (call.method == 'restorePurchases') {
        throw PlatformException(
            code: '10', message: 'synthetic offline restore');
      }
      return response(call);
    };
    await cubit.restore();
    expect(cubit.state.error, 'Restore failed. Please try again.');
    expect(cubit.state.isLoading, isFalse);
  });
}

Map<String, dynamic> purchaseResult() => {
      'customerInfo': info(premium: true),
      'transaction': {
        'transactionIdentifier': 'synthetic-transaction',
        'productIdentifier': 'silarah_monthly',
        'purchaseDate': '2026-09-27T00:00:00Z',
      },
    };

Map<String, dynamic> offering() {
  final monthly = {
    'identifier': r'$rc_monthly',
    'packageType': 'MONTHLY',
    'presentedOfferingContext': {'offeringIdentifier': 'fixture'},
    'product': {
      'identifier': 'silarah_monthly',
      'description': 'Synthetic plan',
      'title': 'Synthetic plan',
      'price': 1.0,
      'priceString': '1.00',
      'currencyCode': 'INR',
    },
  };
  final current = {
    'identifier': 'fixture',
    'serverDescription': 'Synthetic offering',
    'metadata': <String, Object>{},
    'availablePackages': [monthly],
    'monthly': monthly,
  };
  return {
    'all': {'fixture': current},
    'current': current
  };
}

Object? response(MethodCall call) => switch (call.method) {
      'logIn' => {'customerInfo': info(), 'created': false},
      'getCustomerInfo' || 'logOut' || 'restorePurchases' => info(),
      'syncAttributesAndOfferingsIfNeeded' => {'all': {}, 'current': null},
      _ => null,
    };
