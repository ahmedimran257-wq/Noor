-- Fast-start onboarding no longer asks marriage_timeline during mandatory
-- signup. Keep the seriousness gate for discoverability, but do not block
-- saving an incomplete onboarding profile row.

CREATE OR REPLACE FUNCTION public.enforce_marriage_timeline()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.visibility = 'visible'
      AND coalesce(NEW.onboarding_completed, false) = true
      AND NEW.marriage_timeline IS NULL THEN
    RAISE EXCEPTION
      'Marriage timeline is required before your profile can go live. '
      'Please set your marriage readiness timeline in your profile settings.';
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_enforce_marriage_timeline ON public.profiles;
CREATE TRIGGER trg_enforce_marriage_timeline
  BEFORE INSERT OR UPDATE OF visibility, onboarding_completed, marriage_timeline
  ON public.profiles
  FOR EACH ROW
  WHEN (NEW.visibility = 'visible')
  EXECUTE FUNCTION public.enforce_marriage_timeline();

COMMENT ON FUNCTION public.enforce_marriage_timeline IS
  'Blocks discoverable completed profiles without marriage_timeline, but allows fast-start onboarding rows to save before deferred readiness fields are completed.';

CREATE OR REPLACE FUNCTION public.complete_onboarding_profile()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid := auth.uid();
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required.' USING ERRCODE = '42501';
  END IF;

  UPDATE public.profiles
  SET
    onboarding_completed = true,
    onboarding_flow_version = 3,
    onboarding_step = greatest(coalesce(onboarding_step, 0), 5),
    visibility = CASE
      WHEN marriage_timeline IS NULL THEN 'paused'
      ELSE 'visible'
    END
  WHERE user_id = v_user_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Profile row missing.' USING ERRCODE = '23503';
  END IF;

  UPDATE public.users
  SET
    onboarding_completed = true,
    onboarding_step = greatest(coalesce(onboarding_step, 0), 5)
  WHERE id = v_user_id;
END;
$$;

REVOKE ALL ON FUNCTION public.complete_onboarding_profile() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.complete_onboarding_profile() TO authenticated;
