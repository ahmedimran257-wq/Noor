-- Version all launch-policy consents against the public/app legal catalogue.

DO $$
DECLARE
  constraint_record record;
BEGIN
  FOR constraint_record IN
    SELECT conname
    FROM pg_constraint
    WHERE conrelid = 'public.user_consents'::regclass
      AND contype = 'c'
      AND pg_get_constraintdef(oid) ILIKE '%consent_type%'
  LOOP
    EXECUTE format(
      'ALTER TABLE public.user_consents DROP CONSTRAINT IF EXISTS %I',
      constraint_record.conname
    );
  END LOOP;
END $$;

ALTER TABLE public.user_consents
  ADD CONSTRAINT user_consents_consent_type_check
  CHECK (
    consent_type IN (
      'terms_of_service',
      'privacy_policy',
      'community_guidelines',
      'age_verification',
      'special_category_religious'
    )
  );

DROP FUNCTION IF EXISTS public.record_onboarding_consents();

CREATE FUNCTION public.record_onboarding_consents(
  p_policy_version text DEFAULT '2.0.0'
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_version text := trim(coalesce(p_policy_version, ''));
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required.';
  END IF;
  IF v_version !~ '^[0-9]+\.[0-9]+\.[0-9]+$' THEN
    RAISE EXCEPTION 'A semantic policy version is required.';
  END IF;

  INSERT INTO public.user_consents (user_id, consent_type, version)
  SELECT v_user_id, consent_type, v_version
  FROM (
    VALUES
      ('terms_of_service'),
      ('privacy_policy'),
      ('community_guidelines'),
      ('age_verification'),
      ('special_category_religious')
  ) AS required(consent_type)
  ON CONFLICT DO NOTHING;
END;
$$;

REVOKE ALL ON FUNCTION public.record_onboarding_consents(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.record_onboarding_consents(text) TO authenticated;

COMMENT ON FUNCTION public.record_onboarding_consents(text) IS
  'Records the exact launch-policy bundle accepted at the pre-auth legal gate.';
