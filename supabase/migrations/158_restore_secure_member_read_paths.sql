-- Restore member read paths after the base profile and match tables were
-- removed from direct PostgREST access. These projections preserve the
-- hardened write/read boundary while exposing only participant-authorized
-- records required by the app.

CREATE OR REPLACE FUNCTION public.get_chat_inbox(
  p_limit integer DEFAULT 50,
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
  unread_count integer
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
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = 'P0001';
  END IF;

  RETURN QUERY
  WITH visible_matches AS (
    SELECT m.*
    FROM public.matches m
    WHERE m.user_a = v_me OR m.user_b = v_me
  ),
  inbox AS (
    SELECT
      m.id AS match_id,
      CASE WHEN m.user_a = v_me THEN m.user_b ELSE m.user_a END
        AS other_user_id,
      m.status::text AS match_status,
      m.closure_reason,
      m.created_at AS match_created_at,
      lm.id AS last_message_id,
      lm.content AS last_message_content,
      lm.sender_id AS last_message_sender_id,
      lm.created_at AS last_message_created_at,
      lm.read_at AS last_message_read_at,
      coalesce(uc.unread_count, 0)::integer AS unread_count,
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
      SELECT count(*)::integer AS unread_count
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

REVOKE ALL ON FUNCTION public.get_chat_inbox(integer, timestamptz)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.get_chat_inbox(integer, timestamptz)
  TO authenticated;

CREATE OR REPLACE FUNCTION public.get_my_matches(
  p_limit integer DEFAULT 100
)
RETURNS TABLE (
  id uuid,
  user_a uuid,
  user_b uuid,
  status text,
  created_at timestamptz
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT
    m.id,
    m.user_a,
    m.user_b,
    m.status::text,
    m.created_at
  FROM public.matches m
  WHERE auth.uid() IS NOT NULL
    AND (m.user_a = auth.uid() OR m.user_b = auth.uid())
  ORDER BY m.created_at DESC, m.id DESC
  LIMIT greatest(1, least(coalesce(p_limit, 100), 100));
$$;

REVOKE ALL ON FUNCTION public.get_my_matches(integer)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.get_my_matches(integer)
  TO authenticated;

CREATE OR REPLACE FUNCTION public.get_authorized_photo_gallery_paths(
  p_viewer_user_id uuid,
  p_owner_user_id uuid
)
RETURNS TABLE (
  order_index integer,
  storage_path text
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT
    slot.order_index,
    authorized.storage_path
  FROM generate_series(0, 3) AS slot(order_index)
  CROSS JOIN LATERAL public.get_authorized_photo_paths(
    p_viewer_user_id,
    ARRAY[p_owner_user_id],
    slot.order_index
  ) authorized
  WHERE auth.role() = 'service_role'
  ORDER BY slot.order_index;
$$;

REVOKE ALL ON FUNCTION public.get_authorized_photo_gallery_paths(uuid, uuid)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.get_authorized_photo_gallery_paths(uuid, uuid)
  TO service_role;

COMMENT ON FUNCTION public.get_chat_inbox(integer, timestamptz) IS
  'Participant-scoped chat inbox that can safely read private profile names.';
COMMENT ON FUNCTION public.get_my_matches(integer) IS
  'Bounded participant-only match projection for member connection history.';
COMMENT ON FUNCTION public.get_authorized_photo_gallery_paths(uuid, uuid) IS
  'Service-only ordered gallery paths after relationship and privacy checks.';
