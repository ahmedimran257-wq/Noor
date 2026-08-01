-- Migration 160 hardened notification destinations to registered Silarah
-- deep links. Reinstall the three photo/profile functions from migration 170
-- with a compliant profile destination.
DO $$
DECLARE
  v_signature regprocedure;
  v_definition text;
  v_updated text;
BEGIN
  FOREACH v_signature IN ARRAY ARRAY[
    'public.finalize_profile_photo_upload(uuid,text,text,integer,text,numeric)'::regprocedure,
    'public.complete_onboarding_profile()'::regprocedure,
    'public.admin_review_photo(uuid,text,text)'::regprocedure
  ]
  LOOP
    SELECT pg_get_functiondef(v_signature) INTO v_definition;
    v_updated := replace(
      v_definition,
      '''/home?tab=3''',
      '''silarah://profile'''
    );

    IF v_updated = v_definition THEN
      RAISE EXCEPTION
        'Expected legacy profile deep link was not found in %',
        v_signature;
    END IF;

    EXECUTE v_updated;
  END LOOP;
END;
$$;
