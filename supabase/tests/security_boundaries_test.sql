begin;
create extension if not exists pgtap with schema extensions;
select extensions.plan(43);

select extensions.ok(
  not has_table_privilege('authenticated', 'public.users', 'INSERT,UPDATE,DELETE'),
  'members have no raw users DML'
);
select extensions.ok(
  not has_table_privilege('authenticated', 'public.profiles', 'INSERT,UPDATE,DELETE'),
  'members have no raw profiles DML'
);
select extensions.ok(
  not has_table_privilege('authenticated', 'public.photos', 'INSERT,UPDATE,DELETE'),
  'members have no raw photos DML'
);
select extensions.ok(
  not has_table_privilege('authenticated', 'public.photo_access_requests', 'INSERT,UPDATE,DELETE'),
  'members cannot self-grant photo access'
);
select extensions.ok(
  not has_table_privilege('authenticated', 'public.interests', 'INSERT,UPDATE,DELETE'),
  'interest state is RPC-only'
);
select extensions.ok(
  not has_table_privilege('authenticated', 'public.messages', 'INSERT,UPDATE,DELETE'),
  'message state is RPC-only'
);
select extensions.ok(
  not has_table_privilege('authenticated', 'public.reports', 'INSERT,UPDATE,DELETE'),
  'report state is RPC-only'
);
select extensions.ok(
  not has_table_privilege('authenticated', 'public.message_reports', 'INSERT,UPDATE,DELETE'),
  'message report state is RPC-only'
);
select extensions.ok(
  not has_table_privilege('authenticated', 'public.user_consents', 'INSERT,UPDATE,DELETE'),
  'consent evidence is RPC-only'
);
select extensions.ok(
  not has_table_privilege('authenticated', 'public.admin_memberships', 'INSERT,UPDATE,DELETE'),
  'staff governance is RPC-only'
);
select extensions.ok(
  not has_table_privilege('anon', 'public.profiles', 'SELECT'),
  'anonymous callers cannot read base profiles'
);
select extensions.ok(
  not has_table_privilege('authenticated', 'public.profiles', 'SELECT'),
  'members cannot read base profiles'
);
select extensions.ok(
  not has_table_privilege('authenticated', 'public.matches', 'SELECT'),
  'members cannot read raw matches'
);
select extensions.ok(
  not has_table_privilege('authenticated', 'public.discovery_pool', 'SELECT'),
  'members cannot bypass discovery RPCs'
);
select extensions.ok(
  not has_table_privilege('authenticated', 'public.recommendations', 'SELECT,INSERT,UPDATE,DELETE'),
  'recommendations are server-owned'
);
select extensions.ok(
  not has_function_privilege(
    'authenticated',
    'public.record_onboarding_consents(text)',
    'EXECUTE'
  ),
  'legacy bundled consent RPC is unavailable'
);
select extensions.ok(
  has_function_privilege(
    'authenticated',
    'public.get_chat_inbox(integer,timestamp with time zone)',
    'EXECUTE'
  ),
  'authenticated participant chat inbox is available'
);
select extensions.ok(
  has_function_privilege(
    'authenticated',
    'public.get_my_matches(integer)',
    'EXECUTE'
  ),
  'authenticated participant match projection is available'
);
select extensions.ok(
  has_function_privilege(
    'service_role',
    'public.get_authorized_photo_gallery_paths(uuid,uuid)',
    'EXECUTE'
  )
  and not has_function_privilege(
    'authenticated',
    'public.get_authorized_photo_gallery_paths(uuid,uuid)',
    'EXECUTE'
  ),
  'gallery path projection is service-only'
);
select extensions.ok(
  (
    select bool_and(p.prosecdef)
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname in (
        'get_chat_inbox',
        'get_chat_messages',
        'mark_chat_read',
        'report_chat_message',
        'block_chat_user',
        'close_chat_match'
      )
  ),
  'chat RPCs use checked definer boundaries after raw table grants are removed'
);
select extensions.ok(
  not has_function_privilege(
    'public',
    'public.finalize_profile_photo_upload(uuid,text,text,integer,text,numeric)',
    'EXECUTE'
  ),
  'photo finalization is not public'
);
select extensions.ok(
  has_function_privilege(
    'service_role',
    'public.finalize_profile_photo_upload(uuid,text,text,integer,text,numeric)',
    'EXECUTE'
  ),
  'service photo finalization is available'
);
select extensions.is(
  (
    select count(*)::bigint
    from pg_policies
    where schemaname = 'storage'
      and tablename = 'objects'
      and policyname in ('Allow authenticated uploads', 'Allow user read')
  ),
  0::bigint,
  'legacy selfie policies are absent'
);
select extensions.ok(
  to_regprocedure(
    'public.apply_revenuecat_subscription_event(uuid,text,bigint,text,timestamptz,text,text,numeric,timestamptz)'
  ) is null,
  'weak RevenueCat overload is removed'
);
select extensions.ok(
  to_regprocedure(
    'public.apply_revenuecat_subscription_event(uuid,text,text,bigint,text,timestamptz,text,text,numeric,timestamptz)'
  ) is not null,
  'provider-ID RevenueCat RPC exists'
);
select extensions.ok(
  not has_function_privilege(
    'anon',
    'public.record_chat_safety_violation(uuid,text,text)',
    'EXECUTE'
  )
  and not has_function_privilege(
    'authenticated',
    'public.record_chat_safety_violation(uuid,text,text)',
    'EXECUTE'
  ),
  'chat safety recording is internal'
);
select extensions.ok(
  not has_function_privilege(
    'authenticated',
    'public.queue_notification(uuid,text,text,text,text)',
    'EXECUTE'
  )
  and has_function_privilege(
    'service_role',
    'public.queue_notification(uuid,text,text,text,text)',
    'EXECUTE'
  ),
  'notification queueing is service-only'
);
select extensions.ok(
  (
    select bool_and(
      not has_function_privilege('authenticated', p.oid, 'EXECUTE')
      and not has_function_privilege('anon', p.oid, 'EXECUTE')
    )
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname in (
        'compute_casual_penalties',
        'compute_creep_scores',
        'compute_glicko2_batch',
        'compute_glicko_tiers',
        'compute_global_rank_scores',
        'expire_stale_matches',
        'hide_inactive_profiles'
      )
  ),
  'ranking and maintenance routines are unavailable to API members'
);
select extensions.ok(
  not has_function_privilege(
    'anon',
    'public.get_new_arrivals(text,uuid)',
    'EXECUTE'
  )
  and not has_function_privilege(
    'authenticated',
    'public.get_new_arrivals(text,uuid)',
    'EXECUTE'
  ),
  'new-arrivals projection is not anonymous'
);
select extensions.ok(
  not has_table_privilege(
    'authenticated',
    'public.user_glicko_ratings',
    'SELECT,INSERT,UPDATE,DELETE'
  )
  and not has_table_privilege(
    'authenticated',
    'public.glicko_interactions',
    'SELECT,INSERT,UPDATE,DELETE'
  ),
  'ranking ledgers are server-owned'
);
select extensions.ok(
  not has_table_privilege(
    'authenticated',
    'public.subscription_events',
    'SELECT,INSERT,UPDATE,DELETE'
  )
  and not has_table_privilege(
    'authenticated',
    'public.storage_cleanup_queue',
    'SELECT,INSERT,UPDATE,DELETE'
  ),
  'billing and storage cleanup ledgers are server-owned'
);
select extensions.ok(
  exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'blocks'
      and policyname = 'blocks_select'
      and qual like '%blocker_id%auth.uid()%'
      and qual not like '%blocked_id%'
  ),
  'blocked members cannot discover who blocked them'
);
select extensions.ok(
  not has_function_privilege(
    'anon',
    'public.email_registration_status(text)',
    'EXECUTE'
  )
  and not has_function_privilege(
    'anon',
    'public.email_is_registered(text)',
    'EXECUTE'
  ),
  'email registration oracles are unavailable'
);
select extensions.ok(
  not has_function_privilege(
    'authenticated',
    'public.get_or_create_city(character varying,character varying,character varying,character varying,numeric,numeric)',
    'EXECUTE'
  )
  and has_function_privilege(
    'service_role',
    'public.get_or_create_city(character varying,character varying,character varying,character varying,numeric,numeric)',
    'EXECUTE'
  ),
  'city catalogue resolution is service-only'
);
select extensions.ok(
  not has_table_privilege(
    'authenticated',
    'public.guardian_sessions',
    'SELECT,INSERT,UPDATE,DELETE'
  ),
  'guardian presence sessions cannot be forged or read directly'
);
select extensions.ok(
  not has_table_privilege(
    'authenticated',
    'public.guardian_chat_mirrors',
    'INSERT,UPDATE,DELETE'
  ),
  'guardian chat mirrors cannot be forged'
);
select extensions.ok(
  has_function_privilege(
    'anon',
    'public.begin_signup_consent_transaction(text,jsonb)',
    'EXECUTE'
  )
  and has_function_privilege(
    'anon',
    'public.bind_signup_consent_transaction(uuid,text)',
    'EXECUTE'
  ),
  'anonymous signup can create and bind an expiring consent transaction'
);
select extensions.ok(
  has_function_privilege(
    'authenticated',
    'public.finalize_signup_consents(uuid)',
    'EXECUTE'
  )
  and not has_function_privilege(
    'anon',
    'public.finalize_signup_consents(uuid)',
    'EXECUTE'
  ),
  'only a verified authenticated identity can finalize signup consent'
);
select extensions.ok(
  (
    select count(*) = 4
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'profiles'
      and column_name in (
        'guardian_invitation_expires_at',
        'guardian_invitation_consumed_at',
        'guardian_invitation_attempts',
        'guardian_invitation_locked_until'
      )
  ),
  'guardian invitations have expiry, consumption, attempt and lock state'
);
select extensions.ok(
  has_function_privilege(
    'service_role',
    'public.checkout_kyc_document_purges(integer)',
    'EXECUTE'
  )
  and not has_function_privilege(
    'authenticated',
    'public.checkout_kyc_document_purges(integer)',
    'EXECUTE'
  ),
  'KYC purge checkout is service-only'
);
select extensions.ok(
  has_function_privilege(
    'service_role',
    'public.record_kyc_purge_object_result(uuid,text,boolean,text)',
    'EXECUTE'
  )
  and has_function_privilege(
    'service_role',
    'public.finish_kyc_document_purge(uuid)',
    'EXECUTE'
  )
  and not has_function_privilege(
    'authenticated',
    'public.finish_kyc_document_purge(uuid)',
    'EXECUTE'
  ),
  'KYC purge progress and completion are service-only'
);
select extensions.ok(
  exists (
    select 1
    from pg_constraint c
    join pg_class r on r.oid = c.conrelid
    join pg_namespace n on n.oid = r.relnamespace
    where n.nspname = 'public'
      and r.relname = 'notifications'
      and c.conname = 'notifications_deep_link_allowlist_check'
      and not c.convalidated
  ),
  'new notification deep links are constrained by the allowlist'
);
select extensions.ok(
  (
    select p.prosecdef
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.oid = 'public.apply_referral_code(text)'::regprocedure
  ),
  'referral application uses the idempotent checked definer boundary'
);

select * from extensions.finish();
rollback;
