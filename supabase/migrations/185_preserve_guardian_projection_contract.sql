-- Preserve the established PostgREST column contract while keeping the
-- privileged row selector in the non-exposed api_private schema.

drop view if exists public.my_guardian_wards;
drop function if exists api_private.get_my_guardian_ward_rows();

create function api_private.get_my_guardian_ward_rows()
returns table (
  id uuid,
  user_id uuid,
  first_name text,
  last_name_initial text,
  visibility text
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
    left(p.last_name, 1),
    p.visibility
  from public.profiles p
  where p.guardian_user_id = (select auth.uid())
$function$;

revoke all on function api_private.get_my_guardian_ward_rows() from public;
revoke all on function api_private.get_my_guardian_ward_rows() from anon;
grant execute on function api_private.get_my_guardian_ward_rows() to authenticated;

create view public.my_guardian_wards
with (security_invoker = true, security_barrier = true)
as
select *
from api_private.get_my_guardian_ward_rows();

revoke all on public.my_guardian_wards from public;
revoke all on public.my_guardian_wards from anon;
grant select on public.my_guardian_wards to authenticated;

notify pgrst, 'reload schema';
