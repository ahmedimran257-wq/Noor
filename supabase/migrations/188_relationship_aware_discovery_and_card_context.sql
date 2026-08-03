-- Relationship-aware Discovery keeps healthy profiles browsable throughout
-- pending, matched and respectful rematch-cooldown states. Only safety,
-- privacy, moderation and the viewer's filters remove a candidate.

DO $migration$
DECLARE
  v_signature regprocedure :=
    'public.get_discovery_feed(uuid,double precision,uuid,integer,jsonb)'::regprocedure;
  v_definition text;
  v_updated text;
  v_interest_guard text := $guard$      AND NOT EXISTS (
        SELECT 1 FROM public.interests i
        WHERE (
          (i.sender_id = p_viewer_id AND i.receiver_id = dp.user_id)
          OR (i.sender_id = dp.user_id AND i.receiver_id = p_viewer_id)
        )
        AND i.status = 'accepted'
      )$guard$;
BEGIN
  SELECT pg_get_functiondef(v_signature) INTO v_definition;
  v_updated := replace(v_definition, v_interest_guard, '');
  v_updated := replace(
    v_updated,
    'rematch_guard.status IN (''active'',''blocked'',''reported'')',
    'rematch_guard.status IN (''blocked'',''reported'')'
  );

  IF position('i.status = ''accepted''' IN v_updated) > 0
    OR position(
      'rematch_guard.status IN (''active'',''blocked'',''reported'')'
      IN v_updated
    ) > 0
    OR position(
      'rematch_guard.status IN (''blocked'',''reported'')'
      IN v_updated
    ) = 0 THEN
    RAISE EXCEPTION 'relationship_aware_discovery_rewrite_failed'
      USING ERRCODE = 'P0001';
  END IF;

  IF v_updated IS DISTINCT FROM v_definition THEN
    EXECUTE v_updated;
  END IF;
END;
$migration$;

-- One bounded RPC now returns every piece of context required by a card. This
-- replaces the former relationship RPC plus compatibility-preferences RPC.
DROP FUNCTION IF EXISTS public.get_prior_match_context(uuid[]);
CREATE FUNCTION public.get_prior_match_context(
  p_candidate_user_ids uuid[]
)
RETURNS TABLE(
  candidate_user_id uuid,
  profile_id uuid,
  previous_match_at timestamptz,
  previous_match_ended_at timestamptz,
  prior_match_count integer,
  rematch_available_at timestamptz,
  relationship_state text,
  sect_preference text,
  deen_preference text,
  min_education_rank integer
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_me uuid := auth.uid();
BEGIN
  IF v_me IS NULL THEN
    RAISE EXCEPTION 'authentication_required' USING ERRCODE = '42501';
  END IF;
  IF coalesce(cardinality(p_candidate_user_ids), 0) > 50 THEN
    RAISE EXCEPTION 'too_many_candidate_ids' USING ERRCODE = '22023';
  END IF;

  RETURN QUERY
  WITH candidates AS (
    SELECT DISTINCT candidate.candidate_id
    FROM unnest(coalesce(p_candidate_user_ids, ARRAY[]::uuid[]))
      AS candidate(candidate_id)
    WHERE candidate.candidate_id IS NOT NULL
      AND candidate.candidate_id <> v_me
  )
  SELECT
    c.candidate_id,
    candidate_profile.id,
    latest.created_at,
    latest.closed_at,
    history.prior_match_count,
    CASE
      WHEN latest.ended_at + interval '7 days' > now()
        THEN latest.ended_at + interval '7 days'
      ELSE NULL
    END,
    CASE
      WHEN active_match.match_id IS NOT NULL THEN 'matched'
      WHEN pending.direction IS NOT NULL THEN pending.direction
      WHEN latest.ended_at + interval '7 days' > now() THEN 'rematch_cooldown'
      ELSE 'none'
    END,
    preferences.sect_preference,
    preferences.deen_preference,
    preferences.min_education_rank
  FROM candidates c
  JOIN public.profiles candidate_profile
    ON candidate_profile.user_id = c.candidate_id
  LEFT JOIN public.profile_preferences preferences
    ON preferences.profile_id = candidate_profile.id
  LEFT JOIN LATERAL (
    SELECT m.id AS match_id
    FROM public.matches m
    WHERE (
      (m.user_a = v_me AND m.user_b = c.candidate_id)
      OR (m.user_b = v_me AND m.user_a = c.candidate_id)
    )
      AND m.status = 'active'
    ORDER BY m.created_at DESC, m.id DESC
    LIMIT 1
  ) active_match ON true
  LEFT JOIN LATERAL (
    SELECT
      m.created_at,
      m.closed_at,
      coalesce(m.closed_at, m.created_at) AS ended_at
    FROM public.matches m
    WHERE (
      (m.user_a = v_me AND m.user_b = c.candidate_id)
      OR (m.user_b = v_me AND m.user_a = c.candidate_id)
    )
      AND m.status IN ('closed','expired')
    ORDER BY coalesce(m.closed_at, m.created_at) DESC, m.id DESC
    LIMIT 1
  ) latest ON true
  LEFT JOIN LATERAL (
    SELECT count(*)::integer AS prior_match_count
    FROM public.matches m
    WHERE (
      (m.user_a = v_me AND m.user_b = c.candidate_id)
      OR (m.user_b = v_me AND m.user_a = c.candidate_id)
    )
      AND m.status IN ('closed','expired')
  ) history ON true
  LEFT JOIN LATERAL (
    SELECT CASE
      WHEN i.sender_id = v_me THEN 'pending_sent'
      ELSE 'pending_received'
    END AS direction
    FROM public.interests i
    WHERE (
      (i.sender_id = v_me AND i.receiver_id = c.candidate_id)
      OR (i.sender_id = c.candidate_id AND i.receiver_id = v_me)
    )
      AND i.status = 'pending'
    ORDER BY i.created_at DESC, i.id DESC
    LIMIT 1
  ) pending ON true
  WHERE candidate_profile.visibility = 'visible'
    AND candidate_profile.onboarding_completed = true
    AND NOT EXISTS (
      SELECT 1 FROM public.blocks b
      WHERE (b.blocker_id = v_me AND b.blocked_id = c.candidate_id)
         OR (b.blocker_id = c.candidate_id AND b.blocked_id = v_me)
    )
    AND NOT EXISTS (
      SELECT 1 FROM public.reports r
      WHERE r.reporter_id = v_me
        AND r.reported_user_id = c.candidate_id
    )
    AND NOT EXISTS (
      SELECT 1 FROM public.matches unsafe_match
      WHERE (
        (unsafe_match.user_a = v_me AND unsafe_match.user_b = c.candidate_id)
        OR (unsafe_match.user_b = v_me AND unsafe_match.user_a = c.candidate_id)
      )
        AND unsafe_match.status IN ('blocked','reported')
    );
END;
$$;

REVOKE ALL ON FUNCTION public.get_prior_match_context(uuid[])
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_prior_match_context(uuid[])
  TO authenticated;

COMMENT ON FUNCTION public.get_prior_match_context(uuid[]) IS
  'Batch relationship and compatibility context for authorized Discovery cards, including active matches.';

-- Interests no longer change feed membership. Their card state is refreshed by
-- InterestsCubit/push reconciliation, so invalidating and re-signing Discovery
-- after every send or withdrawal would be wasteful.
DROP TRIGGER IF EXISTS trg_discovery_revision_interests ON public.interests;

-- Keep the legacy internal search contract aligned with Discovery. Active and
-- historical relationships remain visible; safety relationships remain hidden.
CREATE OR REPLACE FUNCTION public.search_profiles_by_name_city(
  p_viewer_id uuid,
  p_first_name text,
  p_city_id integer DEFAULT NULL
)
RETURNS TABLE(
  profile_id uuid,
  first_name text,
  last_name_initial text,
  city_name text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  IF auth.uid() IS DISTINCT FROM p_viewer_id THEN
    RAISE EXCEPTION 'unauthorized_profile_search' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  SELECT
    p.id,
    p.first_name,
    left(coalesce(p.last_name, ''), 1),
    coalesce(city.name, '')
  FROM public.profiles p
  JOIN public.users account ON account.id = p.user_id
  LEFT JOIN public.cities city ON city.id = p.city_id
  WHERE p.visibility = 'visible'
    AND p.onboarding_completed = true
    AND p.approved_at IS NOT NULL
    AND account.deleted_at IS NULL
    AND coalesce(account.is_banned, false) = false
    AND coalesce(account.is_shadowbanned, false) = false
    AND p.user_id <> p_viewer_id
    AND p.first_name ILIKE p_first_name || '%'
    AND (p_city_id IS NULL OR p.city_id = p_city_id)
    AND EXISTS (
      SELECT 1 FROM public.photos ph
      WHERE ph.profile_id = p.id
        AND ph.order_index = 0
        AND ph.status = 'active'
        AND ph.admin_approved = true
        AND ph.nsfw_cleared = true
    )
    AND NOT EXISTS (
      SELECT 1 FROM public.blocks b
      WHERE (b.blocker_id = p_viewer_id AND b.blocked_id = p.user_id)
         OR (b.blocker_id = p.user_id AND b.blocked_id = p_viewer_id)
    )
    AND NOT EXISTS (
      SELECT 1 FROM public.reports r
      WHERE r.reporter_id = p_viewer_id
        AND r.reported_user_id = p.user_id
    )
    AND NOT EXISTS (
      SELECT 1 FROM public.matches m
      WHERE (
        (m.user_a = p_viewer_id AND m.user_b = p.user_id)
        OR (m.user_b = p_viewer_id AND m.user_a = p.user_id)
      )
        AND m.status IN ('blocked','reported')
    )
  ORDER BY p.first_name, p.id
  LIMIT 20;
END;
$$;

REVOKE ALL ON FUNCTION public.search_profiles_by_name_city(
  uuid, text, integer
) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.search_profiles_by_name_city(
  uuid, text, integer
) TO authenticated;
