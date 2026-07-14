-- Chat inbox/message scaling hardening.
-- Inbox is a single RPC, messages are paginated per match, and match closure is
-- server-controlled instead of a direct client table update.

CREATE INDEX IF NOT EXISTS idx_matches_user_a_status_created
  ON public.matches(user_a, status, created_at DESC, id DESC);

CREATE INDEX IF NOT EXISTS idx_matches_user_b_status_created
  ON public.matches(user_b, status, created_at DESC, id DESC);

CREATE INDEX IF NOT EXISTS idx_messages_match_created_desc
  ON public.messages(match_id, created_at DESC, id DESC);

CREATE INDEX IF NOT EXISTS idx_messages_match_receiver_unread_created
  ON public.messages(match_id, receiver_id, created_at DESC)
  WHERE read_at IS NULL;

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
    left(coalesce(nullif(p.last_name, ''), ''), 1) AS other_last_initial,
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

CREATE OR REPLACE FUNCTION public.close_chat_match(
  p_match_id uuid,
  p_closure_reason text
)
RETURNS void
LANGUAGE plpgsql
SECURITY INVOKER
AS $$
DECLARE
  v_me uuid := auth.uid();
  v_reason text := trim(coalesce(p_closure_reason, ''));
BEGIN
  IF v_me IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = 'P0001';
  END IF;

  IF length(v_reason) < 10 THEN
    RAISE EXCEPTION 'Closure reason is required' USING ERRCODE = 'P0001';
  END IF;

  UPDATE public.matches m
  SET status = 'closed',
      closed_by = v_me,
      closed_at = now(),
      closure_reason = v_reason
  WHERE m.id = p_match_id
    AND (m.user_a = v_me OR m.user_b = v_me)
    AND coalesce(m.status, 'active') = 'active';

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Active chat not found' USING ERRCODE = 'P0001';
  END IF;
END;
$$;

REVOKE ALL ON FUNCTION public.get_chat_inbox(int, timestamptz) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.get_chat_messages(uuid, int, timestamptz) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.close_chat_match(uuid, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_chat_inbox(int, timestamptz) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_chat_messages(uuid, int, timestamptz) TO authenticated;
GRANT EXECUTE ON FUNCTION public.close_chat_match(uuid, text) TO authenticated;
