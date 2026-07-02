-- Mandatory onboarding consent recording.
-- The legal gate is before auth, so the app stores a pending marker locally and
-- this RPC writes the real consent rows immediately after email OTP succeeds.

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
      'age_verification',
      'special_category_religious'
    )
  );

CREATE OR REPLACE FUNCTION public.record_onboarding_consents()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid := auth.uid();
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required.';
  END IF;

  INSERT INTO public.user_consents (user_id, consent_type, version)
  SELECT v_user_id, consent_type, '1.0'
  FROM (
    VALUES
      ('terms_of_service'),
      ('privacy_policy'),
      ('age_verification'),
      ('special_category_religious')
  ) AS required(consent_type)
  ON CONFLICT DO NOTHING;
END;
$$;

REVOKE ALL ON FUNCTION public.record_onboarding_consents() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.record_onboarding_consents() TO authenticated;

COMMENT ON FUNCTION public.record_onboarding_consents() IS
  'Writes all mandatory onboarding consent rows for the authenticated user. Used immediately after email OTP signup.';
