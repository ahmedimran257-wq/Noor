-- Expose only the stated preferences needed to calculate compatibility for
-- candidates that are already eligible for authenticated discovery.
CREATE OR REPLACE FUNCTION public.get_discovery_compatibility_preferences(
  p_profile_ids uuid[]
)
RETURNS TABLE (
  profile_id uuid,
  sect_preference text,
  deen_preference text,
  min_education_rank integer
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT
    p.id,
    pr.sect_preference,
    pr.deen_preference,
    pr.min_education_rank
  FROM public.profiles p
  JOIN public.profile_preferences pr ON pr.profile_id = p.id
  WHERE auth.uid() IS NOT NULL
    AND p.id = ANY(COALESCE(p_profile_ids, ARRAY[]::uuid[]))
    AND p.user_id <> auth.uid()
    AND p.visibility = 'visible'
    AND p.onboarding_completed = true;
$$;

REVOKE ALL ON FUNCTION public.get_discovery_compatibility_preferences(uuid[])
  FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_discovery_compatibility_preferences(uuid[])
  TO authenticated;
