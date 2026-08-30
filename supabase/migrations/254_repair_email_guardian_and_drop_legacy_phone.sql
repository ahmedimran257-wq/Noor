-- Follow-up for environments that received migration 253 before the public.users
-- schema mismatch was detected. Fresh databases already receive the corrected
-- function from 253; this patch is therefore idempotent.

DO $migration$
DECLARE
  v_signature regprocedure :=
    'public.accept_my_guardian_invitation(text)'::regprocedure;
  v_definition text;
  v_updated text;
BEGIN
  SELECT replace(pg_get_functiondef(v_signature), E'\r\n', E'\n')
  INTO v_definition;

  v_updated := regexp_replace(
    v_definition,
    E',\\s*updated_at\\s*=\\s*now\\(\\)',
    '',
    'n'
  );

  IF v_updated IS DISTINCT FROM v_definition THEN
    EXECUTE v_updated;
  ELSIF position('updated_at = now()' IN v_definition) > 0 THEN
    RAISE EXCEPTION 'guardian_email_acceptance_repair_anchor_not_found';
  END IF;
END;
$migration$;

DROP FUNCTION IF EXISTS public.confirm_my_verified_phone();
DROP FUNCTION IF EXISTS public.confirm_my_verified_phone(text);

NOTIFY pgrst, 'reload schema';
