-- Return complete public profile names on member-facing surfaces.
--
-- The transport column names remain unchanged for rolling compatibility with
-- already installed clients, but their surname value is no longer truncated.

CREATE OR REPLACE VIEW public.live_discovery_pool
WITH (security_invoker = true)
AS
SELECT
  p.id AS profile_id,
  p.user_id,
  p.gender,
  p.first_name,
  p.last_name AS last_name_initial,
  extract(year FROM age(p.date_of_birth))::integer AS age,
  c.name AS city_name,
  p.country_code,
  p.city_id,
  p.sect::text AS sect,
  p.deen_level::text AS deen_level,
  p.profession,
  p.bio,
  CASE WHEN p.photo_privacy = 'public' THEN primary_photo.storage_path END
    AS photo_url,
  photo_totals.photo_count,
  p.photo_privacy::text AS photo_privacy,
  p.is_verified,
  p.location,
  p.static_rank_score AS rank_score,
  p.marriage_timeline,
  p.height_cm,
  p.complexion,
  p.mother_tongue,
  p.smoking_habit,
  p.community,
  p.diet_type,
  p.living_expectation,
  p.quran_memorization,
  p.religious_education,
  p.willing_to_relocate,
  p.previously_married,
  p.family_type,
  p.children_count,
  p.education_rank,
  prefs.preferred_age_min,
  prefs.preferred_age_max,
  p.last_active_at,
  CASE WHEN p.photo_privacy = 'public' THEN primary_photo.blurhash END
    AS blurhash
FROM public.profiles p
LEFT JOIN public.cities c ON c.id = p.city_id
JOIN public.profile_preferences prefs ON prefs.profile_id = p.id
JOIN LATERAL (
  SELECT count(*)::integer AS photo_count
  FROM public.photos ph
  WHERE ph.profile_id = p.id
    AND ph.admin_approved = true
    AND ph.nsfw_cleared = true
) photo_totals ON photo_totals.photo_count > 0
LEFT JOIN LATERAL (
  SELECT ph.storage_path, ph.blurhash
  FROM public.photos ph
  WHERE ph.profile_id = p.id
    AND ph.order_index = 0
    AND ph.admin_approved = true
    AND ph.nsfw_cleared = true
  ORDER BY ph.created_at DESC
  LIMIT 1
) primary_photo ON true
WHERE p.visibility = 'visible'
  AND p.onboarding_completed = true
  AND p.approved_at IS NOT NULL;

REVOKE ALL ON public.live_discovery_pool FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.get_chat_inbox(
  p_limit int DEFAULT 50,
  p_before timestamptz DEFAULT NULL
)
RETURNS TABLE (
  match_id uuid,
  other_user_id uuid,
  other_first_name text,
  other_last_initial text,
  match_status text,
  closure_reason text,
  match_created_at timestamptz,
  last_message_id uuid,
  last_message_content text,
  last_message_sender_id uuid,
  last_message_created_at timestamptz,
  last_message_read_at timestamptz,
  unread_count int
)
LANGUAGE plpgsql
SECURITY INVOKER
AS $$
DECLARE
  v_me uuid := auth.uid();
BEGIN
  IF v_me IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = 'P0001';
  END IF;

  RETURN QUERY
  WITH visible_matches AS (
    SELECT m.*
    FROM public.matches m
    WHERE m.user_a = v_me OR m.user_b = v_me
  ), inbox AS (
    SELECT
      m.id AS match_id,
      CASE WHEN m.user_a = v_me THEN m.user_b ELSE m.user_a END AS other_user_id,
      m.status AS match_status,
      m.closure_reason,
      m.created_at AS match_created_at,
      lm.id AS last_message_id,
      lm.content AS last_message_content,
      lm.sender_id AS last_message_sender_id,
      lm.created_at AS last_message_created_at,
      lm.read_at AS last_message_read_at,
      coalesce(uc.unread_count, 0)::int AS unread_count,
      coalesce(lm.created_at, m.created_at) AS sort_at
    FROM visible_matches m
    LEFT JOIN LATERAL (
      SELECT msg.id, msg.content, msg.sender_id, msg.created_at, msg.read_at
      FROM public.messages msg
      WHERE msg.match_id = m.id
      ORDER BY msg.created_at DESC, msg.id DESC
      LIMIT 1
    ) lm ON true
    LEFT JOIN LATERAL (
      SELECT count(*)::int AS unread_count
      FROM public.messages msg
      WHERE msg.match_id = m.id
        AND msg.receiver_id = v_me
        AND msg.read_at IS NULL
    ) uc ON true
  )
  SELECT
    inbox.match_id,
    inbox.other_user_id,
    coalesce(nullif(p.first_name, ''), 'Member') AS other_first_name,
    coalesce(nullif(p.last_name, ''), '') AS other_last_initial,
    inbox.match_status,
    inbox.closure_reason,
    inbox.match_created_at,
    inbox.last_message_id,
    inbox.last_message_content,
    inbox.last_message_sender_id,
    inbox.last_message_created_at,
    inbox.last_message_read_at,
    inbox.unread_count
  FROM inbox
  LEFT JOIN public.profiles p ON p.user_id = inbox.other_user_id
  WHERE p_before IS NULL OR inbox.sort_at < p_before
  ORDER BY inbox.sort_at DESC, inbox.match_id DESC
  LIMIT greatest(1, least(coalesce(p_limit, 50), 100));
END;
$$;

CREATE OR REPLACE FUNCTION public.get_incoming_photo_access_requests()
RETURNS TABLE (
  request_id uuid,
  requester_id uuid,
  first_name text,
  last_name_initial text,
  status text,
  created_at timestamptz,
  responded_at timestamptz
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT
    par.id,
    par.requester_id,
    coalesce(p.first_name, 'Member'),
    coalesce(p.last_name, ''),
    par.status,
    par.created_at,
    par.responded_at
  FROM public.photo_access_requests par
  LEFT JOIN public.profiles p ON p.user_id = par.requester_id
  WHERE par.owner_id = auth.uid()
  ORDER BY
    CASE par.status WHEN 'pending' THEN 0 WHEN 'granted' THEN 1 ELSE 2 END,
    par.created_at DESC;
$$;

REVOKE ALL ON FUNCTION public.get_chat_inbox(integer, timestamptz) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_chat_inbox(integer, timestamptz)
  TO authenticated;
REVOKE ALL ON FUNCTION public.get_incoming_photo_access_requests() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_incoming_photo_access_requests()
  TO authenticated;

COMMENT ON VIEW public.live_discovery_pool IS
  'Canonical live discovery source with complete public profile surnames.';
COMMENT ON FUNCTION public.get_chat_inbox(integer, timestamptz) IS
  'Bounded chat inbox returning complete participant names and unread counts.';
