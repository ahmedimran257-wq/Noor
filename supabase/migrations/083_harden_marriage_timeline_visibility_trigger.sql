-- The fast-start onboarding flow does not ask for marriage_timeline.
-- Enforce it only when a profile is actually being made discoverable.

CREATE OR REPLACE FUNCTION public.enforce_marriage_timeline()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.visibility IS DISTINCT FROM 'visible' THEN
    RETURN NEW;
  END IF;

  IF COALESCE(NEW.onboarding_completed, false) IS DISTINCT FROM true THEN
    RETURN NEW;
  END IF;

  IF NEW.marriage_timeline IS NULL THEN
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
  EXECUTE FUNCTION public.enforce_marriage_timeline();

COMMENT ON FUNCTION public.enforce_marriage_timeline IS
  'Requires marriage_timeline only for completed profiles that are being made visible; onboarding drafts and paused profiles can save partial data.';
