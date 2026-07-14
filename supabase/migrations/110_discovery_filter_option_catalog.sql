-- Canonical discovery filter options live in Supabase, not in Flutter.
-- Live candidate facets are still merged in, but small markets/test datasets
-- no longer collapse every filter to "Any".

CREATE TABLE IF NOT EXISTS public.discovery_filter_option_catalog (
  field text NOT NULL,
  value text NOT NULL,
  sort_order integer NOT NULL DEFAULT 100,
  active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (field, value),
  CONSTRAINT discovery_filter_option_catalog_field_check CHECK (
    field IN (
      'gender',
      'sect',
      'deen_level',
      'education_rank',
      'family_type',
      'marital_status',
      'living_expectation',
      'quran_memorization',
      'marriage_timeline',
      'willing_to_relocate'
    )
  )
);

CREATE OR REPLACE FUNCTION public.touch_discovery_filter_option_catalog()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_touch_discovery_filter_option_catalog
  ON public.discovery_filter_option_catalog;
CREATE TRIGGER trg_touch_discovery_filter_option_catalog
BEFORE UPDATE ON public.discovery_filter_option_catalog
FOR EACH ROW
EXECUTE FUNCTION public.touch_discovery_filter_option_catalog();

INSERT INTO public.discovery_filter_option_catalog (field, value, sort_order)
VALUES
  ('gender', 'male', 10),
  ('gender', 'female', 20),
  ('sect', 'sunni', 10),
  ('sect', 'shia', 20),
  ('sect', 'prefer_not_to_say', 90),
  ('sect', 'other', 100),
  ('deen_level', 'practicing', 10),
  ('deen_level', 'moderate', 20),
  ('deen_level', 'cultural', 30),
  ('education_rank', '1', 10),
  ('education_rank', '2', 20),
  ('education_rank', '3', 30),
  ('education_rank', '4', 40),
  ('education_rank', '5', 50),
  ('education_rank', '6', 60),
  ('education_rank', '7', 70),
  ('family_type', 'nuclear', 10),
  ('family_type', 'joint', 20),
  ('family_type', 'extended', 30),
  ('marital_status', 'no', 10),
  ('marital_status', 'divorced', 20),
  ('marital_status', 'widowed', 30),
  ('living_expectation', 'with_inlaws', 10),
  ('living_expectation', 'separate', 20),
  ('living_expectation', 'open_to_discussion', 30),
  ('quran_memorization', 'none', 10),
  ('quran_memorization', 'some_surahs', 20),
  ('quran_memorization', 'partial', 30),
  ('quran_memorization', 'hafiz', 40),
  ('marriage_timeline', 'asap', 10),
  ('marriage_timeline', '6_months', 20),
  ('marriage_timeline', '1_year', 30),
  ('marriage_timeline', '2_plus_years', 40),
  ('marriage_timeline', 'not_sure', 50),
  ('willing_to_relocate', 'yes', 10),
  ('willing_to_relocate', 'no', 20),
  ('willing_to_relocate', 'open_to_discussion', 30)
ON CONFLICT (field, value) DO UPDATE
SET sort_order = EXCLUDED.sort_order,
    active = true,
    updated_at = now();

ALTER TABLE public.discovery_filter_option_catalog ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS discovery_filter_option_catalog_read
  ON public.discovery_filter_option_catalog;
CREATE POLICY discovery_filter_option_catalog_read
ON public.discovery_filter_option_catalog
FOR SELECT
TO authenticated
USING (active = true);

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
  ),
  catalog AS (
    SELECT c.field, c.value, c.sort_order
    FROM public.discovery_filter_option_catalog AS c
    WHERE c.active = true
  )
  SELECT jsonb_build_object(
    'genders', COALESCE((
      SELECT jsonb_agg(value ORDER BY sort_order, value)
      FROM (
        SELECT DISTINCT c.value, c.sort_order
        FROM catalog AS c
        WHERE c.field = 'gender'
          AND (
            v_viewer_gender IS NULL
            OR c.value IS DISTINCT FROM v_viewer_gender
          )
      ) AS values
    ), '[]'::jsonb),
    'sects', COALESCE((
      SELECT jsonb_agg(value ORDER BY sort_order, value)
      FROM (
        SELECT DISTINCT value, min(sort_order) AS sort_order
        FROM (
          SELECT c.value, c.sort_order
          FROM catalog AS c
          WHERE c.field = 'sect'
          UNION ALL
          SELECT trim(e.sect)::text AS value, 500 AS sort_order
          FROM eligible AS e
          WHERE nullif(trim(e.sect), '') IS NOT NULL
        ) AS merged
        GROUP BY value
      ) AS values
    ), '[]'::jsonb),
    'deen_levels', COALESCE((
      SELECT jsonb_agg(value ORDER BY sort_order, value)
      FROM (
        SELECT DISTINCT value, min(sort_order) AS sort_order
        FROM (
          SELECT c.value, c.sort_order
          FROM catalog AS c
          WHERE c.field = 'deen_level'
          UNION ALL
          SELECT trim(e.deen_level)::text AS value, 500 AS sort_order
          FROM eligible AS e
          WHERE nullif(trim(e.deen_level), '') IS NOT NULL
        ) AS merged
        GROUP BY value
      ) AS values
    ), '[]'::jsonb),
    'education_ranks', COALESCE((
      SELECT jsonb_agg(value ORDER BY value)
      FROM (
        SELECT DISTINCT value::integer AS value
        FROM catalog AS c
        WHERE c.field = 'education_rank'
          AND c.value ~ '^[0-9]+$'
        UNION
        SELECT DISTINCT e.education_rank::integer AS value
        FROM eligible AS e
        WHERE e.education_rank IS NOT NULL
      ) AS values
    ), '[]'::jsonb),
    'family_types', COALESCE((
      SELECT jsonb_agg(value ORDER BY sort_order, value)
      FROM (
        SELECT DISTINCT value, min(sort_order) AS sort_order
        FROM (
          SELECT c.value, c.sort_order
          FROM catalog AS c
          WHERE c.field = 'family_type'
          UNION ALL
          SELECT trim(e.family_type)::text AS value, 500 AS sort_order
          FROM eligible AS e
          WHERE nullif(trim(e.family_type), '') IS NOT NULL
        ) AS merged
        GROUP BY value
      ) AS values
    ), '[]'::jsonb),
    'marital_statuses', COALESCE((
      SELECT jsonb_agg(value ORDER BY sort_order, value)
      FROM (
        SELECT DISTINCT value, min(sort_order) AS sort_order
        FROM (
          SELECT c.value, c.sort_order
          FROM catalog AS c
          WHERE c.field = 'marital_status'
          UNION ALL
          SELECT trim(e.previously_married)::text AS value, 500 AS sort_order
          FROM eligible AS e
          WHERE nullif(trim(e.previously_married), '') IS NOT NULL
        ) AS merged
        GROUP BY value
      ) AS values
    ), '[]'::jsonb),
    'mother_tongues', COALESCE((
      SELECT jsonb_agg(value ORDER BY lower(value))
      FROM (
        SELECT DISTINCT trim(e.mother_tongue)::text AS value
        FROM eligible AS e
        WHERE nullif(trim(e.mother_tongue), '') IS NOT NULL
      ) AS values
    ), '[]'::jsonb),
    'communities', COALESCE((
      SELECT jsonb_agg(value ORDER BY lower(value))
      FROM (
        SELECT DISTINCT trim(e.community)::text AS value
        FROM eligible AS e
        WHERE nullif(trim(e.community), '') IS NOT NULL
      ) AS values
    ), '[]'::jsonb),
    'living_expectations', COALESCE((
      SELECT jsonb_agg(value ORDER BY sort_order, value)
      FROM (
        SELECT DISTINCT value, min(sort_order) AS sort_order
        FROM (
          SELECT c.value, c.sort_order
          FROM catalog AS c
          WHERE c.field = 'living_expectation'
          UNION ALL
          SELECT trim(e.living_expectation)::text AS value, 500 AS sort_order
          FROM eligible AS e
          WHERE nullif(trim(e.living_expectation), '') IS NOT NULL
        ) AS merged
        GROUP BY value
      ) AS values
    ), '[]'::jsonb),
    'quran_memorizations', COALESCE((
      SELECT jsonb_agg(value ORDER BY sort_order, value)
      FROM (
        SELECT DISTINCT value, min(sort_order) AS sort_order
        FROM (
          SELECT c.value, c.sort_order
          FROM catalog AS c
          WHERE c.field = 'quran_memorization'
          UNION ALL
          SELECT trim(e.quran_memorization)::text AS value, 500 AS sort_order
          FROM eligible AS e
          WHERE nullif(trim(e.quran_memorization), '') IS NOT NULL
        ) AS merged
        GROUP BY value
      ) AS values
    ), '[]'::jsonb),
    'marriage_timelines', COALESCE((
      SELECT jsonb_agg(value ORDER BY sort_order, value)
      FROM (
        SELECT DISTINCT value, min(sort_order) AS sort_order
        FROM (
          SELECT c.value, c.sort_order
          FROM catalog AS c
          WHERE c.field = 'marriage_timeline'
          UNION ALL
          SELECT trim(e.marriage_timeline)::text AS value, 500 AS sort_order
          FROM eligible AS e
          WHERE nullif(trim(e.marriage_timeline), '') IS NOT NULL
        ) AS merged
        GROUP BY value
      ) AS values
    ), '[]'::jsonb),
    'willing_to_relocate_values', COALESCE((
      SELECT jsonb_agg(value ORDER BY sort_order, value)
      FROM (
        SELECT DISTINCT value, min(sort_order) AS sort_order
        FROM (
          SELECT c.value, c.sort_order
          FROM catalog AS c
          WHERE c.field = 'willing_to_relocate'
          UNION ALL
          SELECT trim(e.willing_to_relocate)::text AS value, 500 AS sort_order
          FROM eligible AS e
          WHERE nullif(trim(e.willing_to_relocate), '') IS NOT NULL
        ) AS merged
        GROUP BY value
      ) AS values
    ), '[]'::jsonb)
  )
  INTO v_result;

  RETURN COALESCE(v_result, '{}'::jsonb);
END;
$$;

REVOKE ALL ON FUNCTION public.get_discovery_filter_facets(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_discovery_filter_facets(uuid) TO authenticated;
