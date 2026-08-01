-- Separate the permission to read an existing conversation from the
-- permission to send a new message.
--
-- Product contract:
--   * women may open active and respectfully ended conversation history;
--   * men need Premium before any message content is disclosed;
--   * closed/expired conversations are readable but remain write-protected;
--   * blocked/reported conversations stay unavailable for member safety;
--   * an unread conversation is not marked read until its history is unlocked.

CREATE OR REPLACE FUNCTION public.can_open_chat(p_match_id uuid)
RETURNS TABLE (allowed boolean, reason text)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_me uuid := auth.uid();
  v_match public.matches%rowtype;
  v_gender text;
  v_suspended_until timestamptz;
  v_status text;
BEGIN
  IF v_me IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = 'P0001';
  END IF;

  SELECT *
  INTO v_match
  FROM public.matches m
  WHERE m.id = p_match_id
    AND (m.user_a = v_me OR m.user_b = v_me);

  IF NOT FOUND THEN
    RETURN QUERY SELECT false, 'not_found'::text;
    RETURN;
  END IF;

  v_status := coalesce(v_match.status, 'active');

  -- A safety closure must never be presented as a purchase opportunity.
  IF v_status IN ('blocked', 'reported') THEN
    RETURN QUERY SELECT false, 'closed'::text;
    RETURN;
  END IF;

  SELECT u.gender, u.messaging_suspended_until
  INTO v_gender, v_suspended_until
  FROM public.users u
  WHERE u.id = v_me;

  IF v_suspended_until IS NOT NULL AND v_suspended_until > now() THEN
    RETURN QUERY SELECT false, 'suspended'::text;
    RETURN;
  END IF;

  -- Only an explicitly female account has free messaging/read access. This
  -- preserves the unknown-gender hardening from migration 130.
  IF v_gender IS DISTINCT FROM 'female'
    AND NOT public.has_active_premium(v_me) THEN
    RETURN QUERY SELECT false, 'subscription_required'::text;
    RETURN;
  END IF;

  IF v_status = 'active' THEN
    RETURN QUERY SELECT true, 'allowed'::text;
    RETURN;
  END IF;

  IF v_status IN ('closed', 'expired') THEN
    RETURN QUERY SELECT true, 'read_only'::text;
    RETURN;
  END IF;

  RETURN QUERY SELECT false, 'closed'::text;
END;
$$;

-- Add closure actor and server-computed content-lock state to the inbox. The
-- locked projection keeps even the latest-message preview from leaking before
-- Premium is active.
DROP FUNCTION IF EXISTS public.get_chat_inbox(integer, timestamptz);

CREATE FUNCTION public.get_chat_inbox(
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
  unread_count integer,
  closed_by uuid,
  content_locked boolean
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_me uuid := auth.uid();
  v_gender text;
  v_suspended_until timestamptz;
  v_content_locked boolean;
BEGIN
  IF v_me IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = 'P0001';
  END IF;

  SELECT u.gender, u.messaging_suspended_until
  INTO v_gender, v_suspended_until
  FROM public.users u
  WHERE u.id = v_me;

  v_content_locked :=
    (v_suspended_until IS NOT NULL AND v_suspended_until > now())
    OR (
      v_gender IS DISTINCT FROM 'female'
      AND NOT public.has_active_premium(v_me)
    );

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
      m.closed_by,
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
    CASE
      WHEN v_content_locked THEN NULL::text
      ELSE inbox.last_message_content
    END AS last_message_content,
    inbox.last_message_sender_id,
    inbox.last_message_created_at,
    inbox.last_message_read_at,
    inbox.unread_count,
    inbox.closed_by,
    v_content_locked
  FROM inbox
  LEFT JOIN public.profiles p ON p.user_id = inbox.other_user_id
  WHERE p_before IS NULL OR inbox.sort_at < p_before
  ORDER BY inbox.sort_at DESC, inbox.match_id DESC
  LIMIT greatest(1, least(coalesce(p_limit, 50), 100));
END;
$$;

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
  v_access record;
BEGIN
  IF v_me IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = 'P0001';
  END IF;

  SELECT *
  INTO v_access
  FROM public.can_open_chat(p_match_id);

  IF v_access.allowed IS DISTINCT FROM true THEN
    RAISE EXCEPTION '%', coalesce(v_access.reason, 'chat_unavailable')
      USING ERRCODE = 'P0001';
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
  v_access record;
BEGIN
  IF v_me IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = 'P0001';
  END IF;

  SELECT *
  INTO v_access
  FROM public.can_open_chat(p_match_id);

  IF v_access.allowed IS DISTINCT FROM true THEN
    RAISE EXCEPTION '%', coalesce(v_access.reason, 'chat_unavailable')
      USING ERRCODE = 'P0001';
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

REVOKE ALL ON FUNCTION public.can_open_chat(uuid)
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.get_chat_inbox(integer, timestamptz)
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.get_chat_messages(uuid, integer, timestamptz)
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.mark_chat_read(uuid)
  FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION public.can_open_chat(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_chat_inbox(integer, timestamptz)
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_chat_messages(uuid, integer, timestamptz)
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_chat_read(uuid) TO authenticated;

COMMENT ON FUNCTION public.can_open_chat(uuid) IS
  'Authoritative conversation-read entitlement. Closed/expired history is read-only after entitlement; blocked/reported history is unavailable.';
COMMENT ON FUNCTION public.get_chat_inbox(integer, timestamptz) IS
  'Participant inbox with Premium-safe message previews and closure actor metadata.';
COMMENT ON FUNCTION public.get_chat_messages(uuid, integer, timestamptz) IS
  'Entitlement-checked participant history; closed/expired matches remain readable but cannot be written.';
COMMENT ON FUNCTION public.mark_chat_read(uuid) IS
  'Marks participant messages read only after the same server-side entitlement used to reveal history succeeds.';
