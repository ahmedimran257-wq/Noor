import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('production webhook accepts sandbox events only for listed testers', () {
    final webhook = File('supabase/functions/revenuecat-webhook/index.ts')
        .readAsStringSync();
    expect(webhook, contains('Deno.env.get("REVENUECAT_SANDBOX_TESTER_IDS")'));
    expect(webhook, contains('event.environment === "SANDBOX" &&'));
    expect(webhook,
        contains('REVENUECAT_SANDBOX_TESTER_IDS.has(event.app_user_id)'));
    // Without the secret the allowlist is empty and every non-production
    // event is still rejected.
    expect(webhook, contains('?? "PRODUCTION"'));
    expect(webhook, contains('return "environment";'));
  });

  test('Play product IDs match with or without the base plan suffix', () {
    final webhook = File('supabase/functions/revenuecat-webhook/index.ts')
        .readAsStringSync();
    expect(webhook, contains('!isAllowedProduct(event.product_id)'));
    expect(webhook, contains('const subscriptionId = productId.split(":")[0];'));
    expect(webhook, contains('allowed.split(":")[0] === subscriptionId'));
  });
}
