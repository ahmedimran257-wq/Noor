import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('RevenueCat test-store verifier checks the actual remote offering', () {
    final script =
        File('tool/verify_revenuecat_test_store.ps1').readAsStringSync();

    expect(script, contains('REVENUECAT_TEST_KEY'));
    expect(script, contains('https://api.revenuecat.com/v1/subscribers/'));
    expect(script, contains(r"'$rc_monthly'"));
    expect(script, contains(r"'$rc_annual'"));
    expect(script, isNot(contains('REVENUECAT_SECRET_KEY')));
  });
}
