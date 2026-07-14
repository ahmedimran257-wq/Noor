-- Atomic profile pause/unpause endpoint. The app should not update
-- profiles.visibility directly from settings because visibility changes have
-- server-side safety gates and need clear user-facing failures.

CREATE OR REPLACE FUNCTION public.set_profile_pause(p_paused boolean)
RETURNS TABLE (
  is_paused boolean,
  visibility text,
  message text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_profile public.profiles%ROWTYPE;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Please sign in again to update profile visibility.';
  END IF;

  SELECT *
  INTO v_profile
  FROM public.profiles
  WHERE user_id = auth.uid()
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Complete your profile before changing visibility.';
  END IF;

  IF v_profile.visibility IN ('suspended', 'deactivated') THEN
    RAISE EXCEPTION 'This profile cannot be made visible from settings.';
  END IF;

  IF COALESCE(p_paused, false) THEN
    UPDATE public.profiles
    SET visibility = 'paused',
        updated_at = now()
    WHERE id = v_profile.id;

    RETURN QUERY SELECT true, 'paused'::text, 'Your profile is hidden.'::text;
    RETURN;
  END IF;

  IF COALESCE(v_profile.onboarding_completed, false) IS DISTINCT FROM true THEN
    RAISE EXCEPTION 'Complete onboarding before making your profile visible.';
  END IF;

  IF v_profile.approved_at IS NULL THEN
    RAISE EXCEPTION 'Your profile is waiting for approval before it can be visible.';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.photos AS ph
    WHERE ph.profile_id = v_profile.id
      AND ph.admin_approved = true
      AND ph.nsfw_cleared = true
  ) THEN
    RAISE EXCEPTION 'Add an approved profile photo before making your profile visible.';
  END IF;

  UPDATE public.profiles
  SET visibility = 'visible',
      updated_at = now()
  WHERE id = v_profile.id;

  RETURN QUERY SELECT false, 'visible'::text, 'Your profile is visible.'::text;
END;
$$;

REVOKE ALL ON FUNCTION public.set_profile_pause(boolean) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.set_profile_pause(boolean) TO authenticated;
