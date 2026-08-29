-- Align legal consent and reminder boundaries with policy 2.4.0.
--
-- The new notice documents private shortlist metadata, explainable
-- compatibility processing and the exact scope of Incognito Discovery.
-- Existing consent evidence remains immutable. Existing members see the
-- normal server-authoritative policy reminder because their acknowledged
-- version no longer equals the current version.

DO $migration$
DECLARE
  v_signature_text text;
  v_signature regprocedure;
  v_definition text;
  v_updated text;
  v_signatures constant text[] := ARRAY[
    'public.begin_signup_consent_transaction(text,jsonb)',
    'public.finalize_signup_consents(uuid)',
    'public.get_my_policy_reminder_state()',
    'public.acknowledge_policy_reminder(text)',
    'public.finalize_signup_and_provision_my_user(uuid,text)',
    'public.download_my_data(text)'
  ];
BEGIN
  FOREACH v_signature_text IN ARRAY v_signatures LOOP
    v_signature := to_regprocedure(v_signature_text);
    IF v_signature IS NULL THEN
      RAISE EXCEPTION 'policy_240_function_missing:%', v_signature_text;
    END IF;

    SELECT replace(pg_get_functiondef(v_signature), E'\r\n', E'\n')
    INTO v_definition;
    v_updated := replace(v_definition, '2.3.0', '2.4.0');

    IF v_updated IS NOT DISTINCT FROM v_definition THEN
      RAISE EXCEPTION 'policy_240_anchor_missing:%', v_signature_text;
    END IF;

    EXECUTE v_updated;

    SELECT replace(pg_get_functiondef(v_signature), E'\r\n', E'\n')
    INTO v_definition;
    IF position('2.3.0' IN v_definition) > 0
       OR position('2.4.0' IN v_definition) = 0 THEN
      RAISE EXCEPTION 'policy_240_patch_failed:%', v_signature_text;
    END IF;
  END LOOP;
END;
$migration$;

COMMENT ON FUNCTION public.begin_signup_consent_transaction(text, jsonb) IS
  'Rate-limited pre-auth consent transaction for the current 2.4.0 policy bundle.';
COMMENT ON FUNCTION public.get_my_policy_reminder_state() IS
  'Server-authoritative current-policy acknowledgement and periodic reminder state.';

NOTIFY pgrst, 'reload schema';
