-- Complete the chat RPC transition after authenticated base-table privileges
-- were removed. Every operation performs its own participant/ownership check
-- before using definer privileges; members never regain raw table access.

CREATE OR REPLACE FUNCTION public.get_chat_messages(
  p_match_id uuid,
  p_limit integer DEFAULT 50,
  p_before timestamptz DEFAULT NULL
)
RETURNS TABLE (
  id uuid,
  sender_id uuid,
  receiver_id uuid,
  content text,
  created_at timestamptz,
  read_at timestamptz,
  delivered_at timestamptz,
  status text,
  sent_by_guardian boolean,
  translations jsonb
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_me uuid := auth.uid();
BEGIN
  IF v_me IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = 'P0001';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.matches m
    WHERE m.id = p_match_id
      AND (m.user_a = v_me OR m.user_b = v_me)
  ) THEN
    RAISE EXCEPTION 'Chat not found' USING ERRCODE = 'P0001';
  END IF;

  UPDATE public.messages msg
  SET delivered_at = coalesce(msg.delivered_at, now()),
      status = CASE
        WHEN msg.status = 'sent' THEN 'delivered'
        ELSE msg.status
      END
  WHERE msg.match_id = p_match_id
    AND msg.receiver_id = v_me
    AND msg.delivered_at IS NULL;

  RETURN QUERY
  SELECT page.*
  FROM (
    SELECT
      msg.id,
      msg.sender_id,
      msg.receiver_id,
      msg.content,
      msg.created_at,
      msg.read_at,
      msg.delivered_at,
      msg.status::text,
      coalesce(msg.sent_by_guardian, false),
      coalesce(msg.translations, '{}'::jsonb)
    FROM public.messages msg
    WHERE msg.match_id = p_match_id
      AND (p_before IS NULL OR msg.created_at < p_before)
    ORDER BY msg.created_at DESC, msg.id DESC
    LIMIT greatest(1, least(coalesce(p_limit, 50), 100))
  ) page
  ORDER BY page.created_at ASC, page.id ASC;
END;
$$;

CREATE OR REPLACE FUNCTION public.mark_chat_read(p_match_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_me uuid := auth.uid();
BEGIN
  IF v_me IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = 'P0001';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.matches m
    WHERE m.id = p_match_id
      AND (m.user_a = v_me OR m.user_b = v_me)
  ) THEN
    RAISE EXCEPTION 'Chat not found' USING ERRCODE = 'P0001';
  END IF;

  UPDATE public.messages msg
  SET read_at = coalesce(msg.read_at, now()),
      delivered_at = coalesce(msg.delivered_at, now()),
      status = 'read'
  WHERE msg.match_id = p_match_id
    AND msg.receiver_id = v_me
    AND msg.read_at IS NULL;
END;
$$;

CREATE OR REPLACE FUNCTION public.report_chat_message(
  p_message_id uuid,
  p_reason text,
  p_description text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_me uuid := auth.uid();
  v_msg public.messages%rowtype;
  v_reason text := lower(coalesce(p_reason, 'other'));
BEGIN
  IF v_me IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = 'P0001';
  END IF;

  SELECT *
  INTO v_msg
  FROM public.messages
  WHERE id = p_message_id;

  IF NOT FOUND OR NOT (v_msg.sender_id = v_me OR v_msg.receiver_id = v_me) THEN
    RAISE EXCEPTION 'Message not found' USING ERRCODE = 'P0001';
  END IF;

  IF v_msg.sender_id = v_me THEN
    RAISE EXCEPTION 'You cannot report your own message' USING ERRCODE = 'P0001';
  END IF;

  IF v_reason NOT IN (
    'harassment',
    'inappropriate',
    'scam',
    'contact_sharing',
    'other'
  ) THEN
    v_reason := 'other';
  END IF;

  INSERT INTO public.message_reports (
    message_id,
    match_id,
    reporter_id,
    reported_user_id,
    reason,
    description
  )
  VALUES (
    v_msg.id,
    v_msg.match_id,
    v_me,
    v_msg.sender_id,
    v_reason,
    nullif(left(coalesce(p_description, ''), 1000), '')
  )
  ON CONFLICT (message_id, reporter_id) DO UPDATE
  SET reason = excluded.reason,
      description = excluded.description,
      status = 'pending',
      created_at = now();
END;
$$;

CREATE OR REPLACE FUNCTION public.block_chat_user(
  p_user_id uuid,
  p_reason text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_me uuid := auth.uid();
BEGIN
  IF v_me IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = 'P0001';
  END IF;

  IF p_user_id IS NULL OR p_user_id = v_me THEN
    RAISE EXCEPTION 'Invalid block target' USING ERRCODE = 'P0001';
  END IF;

  INSERT INTO public.blocks(blocker_id, blocked_id, reason)
  VALUES (
    v_me,
    p_user_id,
    nullif(left(coalesce(p_reason, ''), 500), '')
  )
  ON CONFLICT (blocker_id, blocked_id) DO NOTHING;
END;
$$;

CREATE OR REPLACE FUNCTION public.close_chat_match(
  p_match_id uuid,
  p_closure_reason text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
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

REVOKE ALL ON FUNCTION public.get_chat_messages(uuid, integer, timestamptz)
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.mark_chat_read(uuid)
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.report_chat_message(uuid, text, text)
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.block_chat_user(uuid, text)
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.close_chat_match(uuid, text)
  FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION public.get_chat_messages(uuid, integer, timestamptz)
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_chat_read(uuid)
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.report_chat_message(uuid, text, text)
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.block_chat_user(uuid, text)
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.close_chat_match(uuid, text)
  TO authenticated;

COMMENT ON FUNCTION public.get_chat_messages(uuid, integer, timestamptz) IS
  'Participant-scoped message history with delivery acknowledgement.';
COMMENT ON FUNCTION public.mark_chat_read(uuid) IS
  'Participant-scoped read acknowledgement without raw message DML grants.';
COMMENT ON FUNCTION public.report_chat_message(uuid, text, text) IS
  'Recipient-only message report operation with explicit ownership checks.';
COMMENT ON FUNCTION public.block_chat_user(uuid, text) IS
  'Authenticated self-scoped block operation without raw block-table writes.';
COMMENT ON FUNCTION public.close_chat_match(uuid, text) IS
  'Participant-scoped match closure without raw match-table writes.';
