-- Keep non-actionable relationship profiles visible without weakening safety.
--
-- Pending interests remain in Discovery with a relationship-aware action.
-- Respectfully closed/expired matches remain visible during the seven-day
-- rematch cooldown, while send_interest() continues to enforce the cooldown.
-- Active matches, accepted interests, blocks, reports and moderation/privacy
-- exclusions remain unavailable.

DO $migration$
DECLARE
  v_signature regprocedure :=
    'public.get_discovery_feed(uuid,double precision,uuid,integer,jsonb)'::regprocedure;
  v_definition text;
  v_updated text;
  v_old_guard text := $old$          AND (
            rematch_guard.status IN ('active','blocked','reported')
            OR (
              rematch_guard.status IN ('closed','expired')
              AND coalesce(rematch_guard.closed_at, rematch_guard.created_at)
                > now() - interval '7 days'
            )
          )$old$;
  v_new_guard text := $new$          AND rematch_guard.status IN ('active','blocked','reported')$new$;
BEGIN
  SELECT pg_get_functiondef(v_signature) INTO v_definition;
  v_updated := v_definition;

  -- Accepted interests belong to an active match and remain outside Discover.
  -- Pending interests are visible and the client renders their current state.
  IF position('i.status IN (''pending'', ''accepted'')' IN v_updated) > 0 THEN
    v_updated := replace(
      v_updated,
      'i.status IN (''pending'', ''accepted'')',
      'i.status = ''accepted'''
    );
  ELSIF position('i.status IN (''pending'',''accepted'')' IN v_updated) > 0 THEN
    v_updated := replace(
      v_updated,
      'i.status IN (''pending'',''accepted'')',
      'i.status = ''accepted'''
    );
  END IF;

  IF position('i.status = ''accepted''' IN v_updated) = 0 THEN
    RAISE EXCEPTION 'discovery_pending_interest_visibility_anchor_not_found'
      USING ERRCODE = 'P0001';
  END IF;

  IF position('rematch_guard.status IN (''closed'',''expired'')' IN v_updated) > 0 THEN
    v_updated := replace(v_updated, v_old_guard, v_new_guard);
  END IF;

  IF position('rematch_guard.status IN (''closed'',''expired'')' IN v_updated) > 0
    OR position(
      'rematch_guard.status IN (''active'',''blocked'',''reported'')'
      IN v_updated
    ) = 0 THEN
    RAISE EXCEPTION 'discovery_visible_cooldown_guard_rewrite_failed'
      USING ERRCODE = 'P0001';
  END IF;

  IF v_updated IS DISTINCT FROM v_definition THEN
    EXECUTE v_updated;
  END IF;
END;
$migration$;

-- One bounded relationship projection enriches the candidates already returned
-- by a Discovery page. It returns every safe candidate so the client can show
-- pending and cooldown states without an N+1 query or trusting local flags.
DROP FUNCTION IF EXISTS public.get_prior_match_context(uuid[]);
CREATE FUNCTION public.get_prior_match_context(
  p_candidate_user_ids uuid[]
)
RETURNS TABLE(
  candidate_user_id uuid,
  previous_match_at timestamptz,
  previous_match_ended_at timestamptz,
  prior_match_count integer,
  rematch_available_at timestamptz,
  relationship_state text
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
    latest.created_at,
    latest.closed_at,
    history.prior_match_count,
    CASE
      WHEN latest.ended_at + interval '7 days' > now()
        THEN latest.ended_at + interval '7 days'
      ELSE NULL
    END,
    CASE
      WHEN pending.direction IS NOT NULL THEN pending.direction
      WHEN latest.ended_at + interval '7 days' > now() THEN 'rematch_cooldown'
      ELSE 'none'
    END
  FROM candidates c
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
  WHERE NOT EXISTS (
    SELECT 1 FROM public.blocks b
    WHERE (b.blocker_id = v_me AND b.blocked_id = c.candidate_id)
       OR (b.blocker_id = c.candidate_id AND b.blocked_id = v_me)
  )
    AND NOT EXISTS (
      SELECT 1 FROM public.reports r
      WHERE r.reporter_id = v_me
        AND r.reported_user_id = c.candidate_id
    );
END;
$$;

REVOKE ALL ON FUNCTION public.get_prior_match_context(uuid[])
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_prior_match_context(uuid[])
  TO authenticated;

COMMENT ON FUNCTION public.get_prior_match_context(uuid[]) IS
  'Batch prior-match, pending-interest and active rematch-cooldown context for safe Discovery candidates.';

-- The legacy profile-search RPC has no Flutter surface, but keep its backend
-- eligibility consistent for internal/future callers: pending interests and
-- respectful cooldowns are visible; active/safety relationships are not.
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
SET search_path = public
AS $$
BEGIN
  IF auth.uid() IS DISTINCT FROM p_viewer_id THEN
    RAISE EXCEPTION 'Profile search can only be requested for the signed-in user.';
  END IF;

  RETURN QUERY
  SELECT p.id, p.first_name, left(p.last_name, 1), c.name::text
  FROM public.profiles p
  JOIN public.users account ON account.id = p.user_id
  LEFT JOIN public.cities c ON p.city_id = c.id
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
        AND m.status IN ('active','blocked','reported')
    )
    AND NOT EXISTS (
      SELECT 1 FROM public.interests i
      WHERE (
        (i.sender_id = p_viewer_id AND i.receiver_id = p.user_id)
        OR (i.sender_id = p.user_id AND i.receiver_id = p_viewer_id)
      )
        AND i.status = 'accepted'
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
