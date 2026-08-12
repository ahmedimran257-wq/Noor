-- Migration 199 retired public.user_devices in favour of the canonical
-- user_fcm_tokens registration table. Keep the archive schema stable without
-- querying the removed relation.

DO $migration$
DECLARE
  v_signature regprocedure := 'public.download_my_data(text)'::regprocedure;
  v_definition text;
  v_updated text;
  v_old text := $old$    'devices', coalesce((
      SELECT jsonb_agg(to_jsonb(ud) ORDER BY ud.created_at)
      FROM public.user_devices ud WHERE ud.user_id = v_user_id
    ), '[]'::jsonb),$old$;
  v_new text := $new$    'devices', '[]'::jsonb,$new$;
BEGIN
  SELECT replace(pg_get_functiondef(v_signature), E'\r\n', E'\n')
  INTO v_definition;

  IF position('public.user_devices' IN v_definition) > 0 THEN
    IF position(v_old IN v_definition) = 0 THEN
      RAISE EXCEPTION 'retired_device_export_anchor_not_found';
    END IF;
    v_updated := replace(v_definition, v_old, v_new);
    EXECUTE v_updated;
  END IF;
END;
$migration$;

COMMENT ON FUNCTION public.download_my_data(text) IS
  'Returns the authenticated member privacy archive. The retired device table is represented by an empty compatibility array; push registrations come from user_fcm_tokens with credentials redacted.';

NOTIFY pgrst, 'reload schema';
