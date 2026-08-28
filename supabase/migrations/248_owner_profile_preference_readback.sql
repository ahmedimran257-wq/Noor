-- Profile preferences are private member state. Authenticated table reads are
-- deliberately unavailable after the member-write security boundary, and the
-- historical RLS policy cannot evaluate its profiles ownership subquery once
-- direct profiles access is revoked. Keep both tables private and expose only
-- the signed-in member's preference row through this narrow read boundary.

CREATE OR REPLACE FUNCTION public.get_my_profile_preferences()
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_user_id uuid := private.assert_authenticated();
  v_preferences jsonb;
BEGIN
  SELECT jsonb_build_object(
    'preferred_age_min', prefs.preferred_age_min,
    'preferred_age_max', prefs.preferred_age_max,
    'location_preference', prefs.location_preference,
    'diaspora_mode', prefs.diaspora_mode,
    'sect_preference', prefs.sect_preference,
    'deen_preference', prefs.deen_preference,
    'min_education_rank', prefs.min_education_rank,
    'open_to_divorced', prefs.open_to_divorced,
    'open_to_widowed', prefs.open_to_widowed,
    'open_to_has_children', prefs.open_to_has_children,
    'open_to_diaspora', prefs.open_to_diaspora,
    'preferred_living_expectation', prefs.preferred_living_expectation
  )
  INTO v_preferences
  FROM public.profiles AS profile
  JOIN public.profile_preferences AS prefs
    ON prefs.profile_id = profile.id
  WHERE profile.user_id = v_user_id;

  RETURN coalesce(v_preferences, '{}'::jsonb);
END;
$$;

REVOKE ALL ON FUNCTION public.get_my_profile_preferences()
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_my_profile_preferences()
  TO authenticated;

COMMENT ON FUNCTION public.get_my_profile_preferences() IS
  'Returns only the authenticated member private preference row without granting direct profiles or profile_preferences table access.';
