-- Live discovery filter facets. The app must not ship hardcoded language or
-- community lists; filter choices are derived from currently eligible profiles.

CREATE OR REPLACE FUNCTION public.get_discovery_filter_facets(
  p_viewer_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_viewer_gender text;
  v_result jsonb;
BEGIN
  IF auth.uid() IS DISTINCT FROM p_viewer_id THEN
    RAISE EXCEPTION 'Discovery filters can only be requested for the signed-in user.';
  END IF;

  SELECT p.gender
  INTO v_viewer_gender
  FROM public.profiles AS p
  WHERE p.user_id = p_viewer_id;

  WITH eligible AS (
    SELECT p.*
    FROM public.profiles AS p
    WHERE p.user_id IS DISTINCT FROM p_viewer_id
      AND p.visibility = 'visible'
      AND COALESCE(p.onboarding_completed, false) = true
      AND p.approved_at IS NOT NULL
      AND p.gender IS NOT NULL
      AND (v_viewer_gender IS NULL OR p.gender IS DISTINCT FROM v_viewer_gender)
      AND EXISTS (
        SELECT 1
        FROM public.photos AS ph
        WHERE ph.profile_id = p.id
          AND ph.admin_approved = true
          AND ph.nsfw_cleared = true
      )
  )
  SELECT jsonb_build_object(
    'genders', COALESCE((
      SELECT jsonb_agg(value ORDER BY value)
      FROM (
        SELECT DISTINCT trim(gender)::text AS value
        FROM eligible
        WHERE nullif(trim(gender), '') IS NOT NULL
      ) AS values
    ), '[]'::jsonb),
    'sects', COALESCE((
      SELECT jsonb_agg(value ORDER BY value)
      FROM (
        SELECT DISTINCT trim(sect)::text AS value
        FROM eligible
        WHERE nullif(trim(sect), '') IS NOT NULL
      ) AS values
    ), '[]'::jsonb),
    'deen_levels', COALESCE((
      SELECT jsonb_agg(value ORDER BY value)
      FROM (
        SELECT DISTINCT trim(deen_level)::text AS value
        FROM eligible
        WHERE nullif(trim(deen_level), '') IS NOT NULL
      ) AS values
    ), '[]'::jsonb),
    'education_ranks', COALESCE((
      SELECT jsonb_agg(value ORDER BY value)
      FROM (
        SELECT DISTINCT education_rank::integer AS value
        FROM eligible
        WHERE education_rank IS NOT NULL
      ) AS values
    ), '[]'::jsonb),
    'family_types', COALESCE((
      SELECT jsonb_agg(value ORDER BY value)
      FROM (
        SELECT DISTINCT trim(family_type)::text AS value
        FROM eligible
        WHERE nullif(trim(family_type), '') IS NOT NULL
      ) AS values
    ), '[]'::jsonb),
    'marital_statuses', COALESCE((
      SELECT jsonb_agg(value ORDER BY value)
      FROM (
        SELECT DISTINCT trim(previously_married)::text AS value
        FROM eligible
        WHERE nullif(trim(previously_married), '') IS NOT NULL
      ) AS values
    ), '[]'::jsonb),
    'mother_tongues', COALESCE((
      SELECT jsonb_agg(value ORDER BY lower(value))
      FROM (
        SELECT DISTINCT trim(mother_tongue)::text AS value
        FROM eligible
        WHERE nullif(trim(mother_tongue), '') IS NOT NULL
      ) AS values
    ), '[]'::jsonb),
    'communities', COALESCE((
      SELECT jsonb_agg(value ORDER BY lower(value))
      FROM (
        SELECT DISTINCT trim(community)::text AS value
        FROM eligible
        WHERE nullif(trim(community), '') IS NOT NULL
      ) AS values
    ), '[]'::jsonb),
    'living_expectations', COALESCE((
      SELECT jsonb_agg(value ORDER BY value)
      FROM (
        SELECT DISTINCT trim(living_expectation)::text AS value
        FROM eligible
        WHERE nullif(trim(living_expectation), '') IS NOT NULL
      ) AS values
    ), '[]'::jsonb),
    'quran_memorizations', COALESCE((
      SELECT jsonb_agg(value ORDER BY value)
      FROM (
        SELECT DISTINCT trim(quran_memorization)::text AS value
        FROM eligible
        WHERE nullif(trim(quran_memorization), '') IS NOT NULL
      ) AS values
    ), '[]'::jsonb),
    'marriage_timelines', COALESCE((
      SELECT jsonb_agg(value ORDER BY value)
      FROM (
        SELECT DISTINCT trim(marriage_timeline)::text AS value
        FROM eligible
        WHERE nullif(trim(marriage_timeline), '') IS NOT NULL
      ) AS values
    ), '[]'::jsonb),
    'willing_to_relocate_values', COALESCE((
      SELECT jsonb_agg(value ORDER BY value)
      FROM (
        SELECT DISTINCT trim(willing_to_relocate)::text AS value
        FROM eligible
        WHERE nullif(trim(willing_to_relocate), '') IS NOT NULL
      ) AS values
    ), '[]'::jsonb)
  )
  INTO v_result;

  RETURN COALESCE(v_result, '{}'::jsonb);
END;
$$;

REVOKE ALL ON FUNCTION public.get_discovery_filter_facets(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_discovery_filter_facets(uuid) TO authenticated;
