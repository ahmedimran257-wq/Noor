-- finalize_profile_photo_upload returns a column named photo_id and also
-- updates a table containing photo_id. Qualify that table reference inside the
-- already-deployed function definition without requiring a superuser-only
-- global PL/pgSQL conflict setting.

DO $migration$
DECLARE
  v_definition text;
  v_repaired text;
BEGIN
  SELECT pg_get_functiondef(
    'public.finalize_profile_photo_upload(uuid,text,text,integer,text,numeric)'
      ::regprocedure
  )
  INTO v_definition;

  v_repaired := replace(
    v_definition,
    'WHERE photo_id = v_replaced.id',
    'WHERE photo_moderation_queue.photo_id = v_replaced.id'
  );

  IF v_repaired = v_definition THEN
    RAISE EXCEPTION 'photo_finalizer_conflict_target_not_found'
      USING ERRCODE = 'P0001';
  END IF;

  EXECUTE v_repaired;
END;
$migration$;

COMMENT ON FUNCTION public.finalize_profile_photo_upload(
  uuid, text, text, integer, text, numeric
) IS 'Atomic service-only photo finalization with qualified table-column resolution for its photo_id result name.';
