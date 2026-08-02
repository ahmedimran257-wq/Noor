-- Keep SECURITY DEFINER helpers out of PostgREST's exposed public schema.
-- The public views remain SECURITY INVOKER and are the only API surface;
-- callers cannot invoke helpers in api_private through /rest/v1/rpc.

create schema if not exists api_private authorization postgres;
revoke all on schema api_private from public;
revoke all on schema api_private from anon;
grant usage on schema api_private to authenticated;

drop view if exists public.my_profile_private;
drop view if exists public.my_guardian_wards;

create or replace function api_private.get_my_profile_private_rows()
returns setof public.profiles
language sql
stable
security definer
set search_path = ''
as $function$
  select p.*
  from public.profiles p
  where p.user_id = (select auth.uid())
$function$;

create or replace function api_private.get_my_guardian_ward_rows()
returns table (
  id uuid,
  user_id uuid,
  first_name text,
  onboarding_completed boolean,
  onboarding_step integer,
  guardian_user_id uuid,
  guardian_mode text,
  guardian_relationship text,
  guardian_authority_scope text,
  created_at timestamptz,
  updated_at timestamptz
)
language sql
stable
security definer
set search_path = ''
as $function$
  select
    p.id,
    p.user_id,
    p.first_name,
    p.onboarding_completed,
    p.onboarding_step,
    p.guardian_user_id,
    p.guardian_mode,
    p.guardian_relationship,
    p.guardian_authority_scope,
    p.created_at,
    p.updated_at
  from public.profiles p
  where p.guardian_user_id = (select auth.uid())
$function$;

revoke all on function api_private.get_my_profile_private_rows() from public;
revoke all on function api_private.get_my_profile_private_rows() from anon;
grant execute on function api_private.get_my_profile_private_rows() to authenticated;

revoke all on function api_private.get_my_guardian_ward_rows() from public;
revoke all on function api_private.get_my_guardian_ward_rows() from anon;
grant execute on function api_private.get_my_guardian_ward_rows() to authenticated;

create view public.my_profile_private
with (security_invoker = true, security_barrier = true)
as
select *
from api_private.get_my_profile_private_rows();

create view public.my_guardian_wards
with (security_invoker = true, security_barrier = true)
as
select *
from api_private.get_my_guardian_ward_rows();

revoke all on public.my_profile_private from public;
revoke all on public.my_profile_private from anon;
grant select on public.my_profile_private to authenticated;

revoke all on public.my_guardian_wards from public;
revoke all on public.my_guardian_wards from anon;
grant select on public.my_guardian_wards to authenticated;

drop function if exists public.get_my_profile_private_rows();
drop function if exists public.get_my_guardian_ward_rows();

notify pgrst, 'reload schema';
