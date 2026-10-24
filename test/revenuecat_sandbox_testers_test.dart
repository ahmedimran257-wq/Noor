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
    expect(
        webhook, contains('const subscriptionId = productId.split(":")[0];'));
    expect(webhook, contains('allowed.split(":")[0] === subscriptionId'));
  });

  test('store refunds are recorded as refunds, not renewal cancellations', () {
    final webhook = File('supabase/functions/revenuecat-webhook/index.ts')
        .readAsStringSync();
    expect(webhook, contains('event.cancel_reason === "CUSTOMER_SUPPORT"'));
    expect(webhook, contains('switch (eventType)'));
    expect(webhook, contains('p_event_type: eventType,'));
    expect(
        webhook,
        contains(
            'queueSubscriptionNotification(supabase, supabaseUserId, eventType)'));
    // A revoked refund must not leave the member marked active.
    expect(webhook, contains('Date.parse(expiresAt) > Date.now()'));
  });

  test('a cancellation after access ended revokes without an access promise',
      () {
    final webhook = File('supabase/functions/revenuecat-webhook/index.ts')
        .readAsStringSync();
    expect(webhook,
        contains('event.expiration_at_ms <= event.event_timestamp_ms!'));
    expect(webhook, contains('? "REVOCATION"'));
    expect(webhook, contains('case "REVOCATION":'));
    // No notification copy and no outbox email exist for a revocation; the
    // following EXPIRATION carries the member-facing message.
    expect(webhook, isNot(contains('REVOCATION: [')));
    // Refund events carry a negative price and must not be rejected.
    expect(webhook, isNot(contains('event.price >= 0')));
  });
}
