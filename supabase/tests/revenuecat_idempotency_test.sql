-- Synthetic billing only: the transaction rolls back before any worker can
-- see the outbox. No payment provider or email is contacted.
begin;
create extension if not exists pgtap with schema extensions;
select extensions.plan(15);

create temporary table billing_fixture as select
  gen_random_uuid() as member_id,
  gen_random_uuid() as other_id,
  gen_random_uuid() as missing_id,
  gen_random_uuid()::text as event_id,
  (extract(epoch from now() - interval '1 minute') * 1000)::bigint as event_ms;
insert into auth.users(id) select member_id from billing_fixture
union all select other_id from billing_fixture;
insert into public.users(id, email, country_code, gender)
select id, id::text || '@staging.silarah.invalid', 'IN', 'male'
from (select member_id as id from billing_fixture
      union all select other_id from billing_fixture) members;
select set_config('request.jwt.claims', '{"role":"service_role"}', true);
set local request.jwt.claim.role = 'service_role';

select extensions.ok(not has_function_privilege('authenticated',
  'public.apply_revenuecat_subscription_event(uuid,text,text,bigint,text,timestamptz,text,text,numeric,timestamptz)',
  'EXECUTE'), 'members cannot grant themselves a paid entitlement');
select extensions.ok(not has_function_privilege('anon',
  'public.apply_revenuecat_subscription_event(uuid,text,text,bigint,text,timestamptz,text,text,numeric,timestamptz)',
  'EXECUTE'), 'anonymous callers cannot apply billing events');

select extensions.is(public.apply_revenuecat_subscription_event(
  member_id, event_id, 'INITIAL_PURCHASE', event_ms, 'active', now() + interval '1 month'
)->>'reason', 'applied', 'initial purchase applies') from billing_fixture;
select extensions.is(public.apply_revenuecat_subscription_event(
  member_id, event_id, 'INITIAL_PURCHASE', event_ms, 'active', now() + interval '1 month'
)->>'reason', 'duplicate_event', 'provider retry is an acknowledged no-op') from billing_fixture;
select extensions.is((select count(*) from public.subscription_events e
  join billing_fixture f on e.user_id = f.member_id), 1::bigint, 'retry creates one ledger entry');
select extensions.is((select count(*) from public.transactional_email_outbox e
  join billing_fixture f on e.user_id = f.member_id), 1::bigint, 'retry creates one email intent');

select extensions.is(public.apply_revenuecat_subscription_event(
  member_id, event_id || '-stale', 'EXPIRATION', event_ms - 1, 'none', null
)->>'reason', 'stale_event', 'older expiration cannot replace newer purchase') from billing_fixture;
select extensions.ok((select u.subscription_status = 'active'
  and u.subscription_expires_at = now() + interval '1 month'
  and u.last_billing_event_ts = f.event_ms
  from public.users u join billing_fixture f on u.id = f.member_id),
  'stale event preserves entitlement, expiry and watermark');

select extensions.is(public.apply_revenuecat_subscription_event(
  member_id, event_id || '-expiry', 'EXPIRATION', event_ms + 1, 'none', null
)->>'reason', 'applied', 'newer expiration applies') from billing_fixture;
select extensions.ok((select u.subscription_status = 'none'
  and u.subscription_expires_at is null and u.last_billing_event_ts = f.event_ms + 1
  from public.users u join billing_fixture f on u.id = f.member_id),
  'expiration removes the paid entitlement and advances watermark');
select extensions.is((select count(*) from public.transactional_email_outbox e
  join billing_fixture f on e.user_id = f.member_id), 2::bigint,
  'stale event creates no email intent; newer expiration creates one');

select extensions.is(public.apply_revenuecat_subscription_event(
  other_id, event_id, 'INITIAL_PURCHASE', event_ms, 'active', now() + interval '1 month'
)->>'reason', 'duplicate_event', 'same provider event cannot grant a second account') from billing_fixture;
select extensions.ok((select u.subscription_status = 'none'
  and u.subscription_expires_at is null and u.last_billing_event_ts = 0
  from public.users u join billing_fixture f on u.id = f.other_id),
  'cross-account duplicate leaves other member unchanged');
select extensions.is(public.apply_revenuecat_subscription_event(
  missing_id, event_id || '-missing', 'INITIAL_PURCHASE', event_ms, 'active', now() + interval '1 month'
)->>'reason', 'user_not_found', 'unknown identity never creates a subscriber') from billing_fixture;
select extensions.is((select count(*) from public.subscription_events e
  join billing_fixture f on e.user_id = f.member_id), 3::bigint,
  'purchase, stale event and expiration retain exactly three audit entries');

select * from extensions.finish();
rollback;
