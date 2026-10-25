-- Photo policy v4: the app now blocks NSFW scores above 0.85 on the device and
-- holds 0.50-0.85 for staff review. Lower the server hold threshold to match,
-- so a revealing photo (or a modified client) cannot publish instantly.
-- Modest dress (hijab, niqab, burqa) scores near zero and is unaffected.
-- Queue categories are unchanged; reviewers see the stored score.

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
    replace(
      v_definition,
      'v_flagged := v_score > 0.85;',
      'v_flagged := v_score > 0.50;'
    ),
    'coalesce(v_existing.nsfw_score, v_score) > 0.85',
    'coalesce(v_existing.nsfw_score, v_score) > 0.50'
  );

  IF v_repaired = v_definition OR position('> 0.85' IN v_repaired) > 0 THEN
    RAISE EXCEPTION 'photo_review_threshold_anchor_not_found'
      USING ERRCODE = 'P0001';
  END IF;

  EXECUTE v_repaired;
END;
$migration$;

COMMENT ON FUNCTION public.finalize_profile_photo_upload(
  uuid, text, text, integer, text, numeric
) IS 'Atomic service-only photo finalization; scores above 0.50 are held for staff review (photo policy v4).';
