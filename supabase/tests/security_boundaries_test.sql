begin;
create extension if not exists pgtap with schema extensions;
select extensions.plan(25);

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
  has_function_privilege(
    'authenticated',
    'public.record_onboarding_consents(text)',
    'EXECUTE'
  ),
  'authenticated consent RPC is available'
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

select * from extensions.finish();
rollback;
