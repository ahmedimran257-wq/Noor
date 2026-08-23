-- A moderation decision is private. The affected member may see their own
-- account standing, but the other participant must never receive a ban reason
-- or a named "X was banned" disclosure. Preserve already-authorized history
-- as read-only and neutralize the unavailable member in inbox projections.

CREATE OR REPLACE FUNCTION public.can_open_chat(p_match_id uuid)
RETURNS TABLE(allowed boolean, reason text)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_me uuid := auth.uid();
  v_match public.matches%rowtype;
  v_other uuid;
  v_gender text;
  v_suspended_until timestamptz;
  v_status text;
  v_is_banned boolean;
  v_deleted_at timestamptz;
  v_other_unavailable boolean;
BEGIN
  IF v_me IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = 'P0001';
  END IF;

  SELECT * INTO v_match
  FROM public.matches m
  WHERE m.id = p_match_id
    AND (m.user_a = v_me OR m.user_b = v_me);

  IF NOT FOUND
    OR (v_match.user_a = v_me AND v_match.hidden_by_a_at IS NOT NULL)
    OR (v_match.user_b = v_me AND v_match.hidden_by_b_at IS NOT NULL) THEN
    RETURN QUERY SELECT false, 'not_found'::text;
    RETURN;
  END IF;

  SELECT u.gender, u.messaging_suspended_until,
         coalesce(u.is_banned, false), u.deleted_at
  INTO v_gender, v_suspended_until, v_is_banned, v_deleted_at
  FROM public.users u
  WHERE u.id = v_me;

  IF NOT FOUND OR v_is_banned OR v_deleted_at IS NOT NULL THEN
    RETURN QUERY SELECT false, 'account_restricted'::text;
    RETURN;
  END IF;

  v_status := coalesce(v_match.status, 'active');
  IF v_status IN ('blocked', 'reported') THEN
    RETURN QUERY SELECT false, 'closed'::text;
    RETURN;
  END IF;
  IF v_suspended_until IS NOT NULL AND v_suspended_until > now() THEN
    RETURN QUERY SELECT false, 'suspended'::text;
    RETURN;
  END IF;
  IF v_gender IS DISTINCT FROM 'female'
    AND NOT public.has_active_premium(v_me) THEN
    RETURN QUERY SELECT false, 'subscription_required'::text;
    RETURN;
  END IF;

  v_other := CASE WHEN v_match.user_a = v_me
    THEN v_match.user_b ELSE v_match.user_a END;
  SELECT NOT (
    u.id IS NOT NULL
    AND u.deleted_at IS NULL
    AND coalesce(u.is_banned, false) = false
    AND coalesce(p.visibility, 'deactivated') NOT IN ('suspended', 'deactivated')
  )
  INTO v_other_unavailable
  FROM (SELECT v_other AS id) target
  LEFT JOIN public.users u ON u.id = target.id
  LEFT JOIN public.profiles p ON p.user_id = target.id;

  IF coalesce(v_other_unavailable, true) THEN
    RETURN QUERY SELECT true, 'member_unavailable_read_only'::text;
    RETURN;
  END IF;
  IF v_status = 'active'
    AND NOT private.guardian_approvals_complete(p_match_id) THEN
    RETURN QUERY SELECT false, 'guardian_approval_required'::text;
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
  content_locked boolean,
  member_unavailable boolean
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_me uuid := private.assert_authenticated();
  v_gender text;
  v_suspended_until timestamptz;
  v_content_locked boolean;
BEGIN
  PERFORM private.assert_active_member(v_me, false);
  SELECT u.gender, u.messaging_suspended_until
  INTO v_gender, v_suspended_until
  FROM public.users u
  WHERE u.id = v_me;

  v_content_locked :=
    (v_suspended_until IS NOT NULL AND v_suspended_until > now())
    OR (v_gender IS DISTINCT FROM 'female' AND NOT public.has_active_premium(v_me));

  RETURN QUERY
  WITH visible_matches AS (
    SELECT m.*,
      CASE WHEN m.user_a = v_me THEN m.user_b ELSE m.user_a END AS other_id
    FROM public.matches m
    WHERE (m.user_a = v_me AND m.hidden_by_a_at IS NULL)
       OR (m.user_b = v_me AND m.hidden_by_b_at IS NULL)
  ),
  inbox AS (
    SELECT
      m.id AS match_id,
      m.other_id,
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
      coalesce(lm.created_at, m.created_at) AS sort_at,
      NOT (
        ou.id IS NOT NULL
        AND ou.deleted_at IS NULL
        AND coalesce(ou.is_banned, false) = false
        AND coalesce(op.visibility, 'deactivated') NOT IN ('suspended', 'deactivated')
      ) AS member_unavailable,
      op.first_name,
      op.last_name
    FROM visible_matches m
    LEFT JOIN public.users ou ON ou.id = m.other_id
    LEFT JOIN public.profiles op ON op.user_id = m.other_id
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
    CASE WHEN inbox.member_unavailable THEN NULL ELSE inbox.other_id END,
    CASE WHEN inbox.member_unavailable THEN 'Silarah member'
      ELSE coalesce(nullif(inbox.first_name, ''), 'Member') END,
    CASE WHEN inbox.member_unavailable THEN ''
      ELSE coalesce(nullif(inbox.last_name, ''), '') END,
    inbox.match_status,
    CASE WHEN inbox.member_unavailable THEN NULL ELSE inbox.closure_reason END,
    inbox.match_created_at,
    inbox.last_message_id,
    CASE WHEN v_content_locked THEN NULL::text ELSE inbox.last_message_content END,
    inbox.last_message_sender_id,
    inbox.last_message_created_at,
    inbox.last_message_read_at,
    inbox.unread_count,
    CASE WHEN inbox.member_unavailable THEN NULL ELSE inbox.closed_by END,
    v_content_locked,
    inbox.member_unavailable
  FROM inbox
  WHERE p_before IS NULL OR inbox.sort_at < p_before
  ORDER BY inbox.sort_at DESC, inbox.match_id DESC
  LIMIT greatest(1, least(coalesce(p_limit, 50), 100));
END;
$$;

-- The read decision above intentionally permits old history. A write must be
-- stricter and only accept the literal active-chat decision.
CREATE OR REPLACE FUNCTION public.send_chat_message(
  p_match_id uuid,
  p_content text
)
RETURNS TABLE (message_id uuid, created_at timestamptz, safety_status text)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_me uuid := private.assert_authenticated();
  v_match public.matches%rowtype;
  v_receiver uuid;
  v_access record;
  v_check record;
  v_message public.messages%rowtype;
  v_sender_name text;
  v_receiver_wants_push boolean;
BEGIN
  SELECT * INTO v_match FROM public.matches
  WHERE id = p_match_id FOR UPDATE;
  IF NOT FOUND OR NOT (v_match.user_a = v_me OR v_match.user_b = v_me) THEN
    RAISE EXCEPTION 'Chat not found' USING ERRCODE = 'P0001';
  END IF;
  IF coalesce(v_match.status, 'active') <> 'active' THEN
    RAISE EXCEPTION 'This chat is closed' USING ERRCODE = 'P0001';
  END IF;

  SELECT * INTO v_access FROM public.can_open_chat(p_match_id);
  IF v_access.allowed IS DISTINCT FROM true OR v_access.reason <> 'allowed' THEN
    RAISE EXCEPTION '%', coalesce(v_access.reason, 'messaging_unavailable')
      USING ERRCODE = 'P0001';
  END IF;

  v_receiver := CASE WHEN v_match.user_a = v_me
    THEN v_match.user_b ELSE v_match.user_a END;
  PERFORM private.assert_active_member(v_receiver, false);
  IF EXISTS (
    SELECT 1 FROM public.blocks b
    WHERE (b.blocker_id = v_me AND b.blocked_id = v_receiver)
       OR (b.blocker_id = v_receiver AND b.blocked_id = v_me)
  ) THEN
    RAISE EXCEPTION 'This chat is unavailable' USING ERRCODE = 'P0001';
  END IF;

  SELECT * INTO v_check FROM public.chat_safety_check(p_content);
  IF v_check.safety_status = 'blocked' THEN
    PERFORM public.record_chat_safety_violation(v_me, v_check.safety_reason, p_content);
    RAISE EXCEPTION 'Message blocked by safety rules: %', v_check.safety_reason
      USING ERRCODE = 'P0001';
  END IF;

  INSERT INTO public.messages(
    match_id, sender_id, receiver_id, content, status, safety_status, safety_reason
  ) VALUES (
    p_match_id, v_me, v_receiver, v_check.sanitized_content, 'sent',
    v_check.safety_status, v_check.safety_reason
  ) RETURNING * INTO v_message;

  BEGIN
    SELECT coalesce(np.new_message, true) INTO v_receiver_wants_push
    FROM public.users u
    LEFT JOIN public.notification_prefs np ON np.user_id = u.id
    WHERE u.id = v_receiver;
    IF coalesce(v_receiver_wants_push, true) THEN
      SELECT coalesce(nullif(p.first_name, ''), 'Silarah member')
      INTO v_sender_name FROM public.profiles p WHERE p.user_id = v_me;
      PERFORM public.queue_notification(
        v_receiver, 'new_message', 'New message',
        coalesce(v_sender_name, 'A Silarah member') || ' sent you a message.',
        '/chat/' || p_match_id::text
      );
    END IF;
  EXCEPTION WHEN OTHERS THEN
    RAISE WARNING 'Message % committed without push enqueue: %', v_message.id, SQLERRM;
  END;

  RETURN QUERY SELECT v_message.id, v_message.created_at, v_message.safety_status;
END;
$$;

CREATE OR REPLACE FUNCTION public.assert_messaging_allowed()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_actor uuid := auth.uid();
  v_suspended_until timestamptz;
BEGIN
  IF v_actor IS NOT NULL AND NEW.sender_id <> v_actor THEN
    IF NEW.sent_by_guardian IS DISTINCT FROM true OR NOT EXISTS (
      SELECT 1 FROM public.guardian_chat_mirrors gcm
      WHERE gcm.match_id = NEW.match_id
        AND gcm.guardian_id = v_actor
        AND gcm.ward_id = NEW.sender_id
        AND gcm.mode = 'active'
        AND public.is_current_guardian_for_ward(gcm.ward_id, 'active')
    ) THEN
      RAISE EXCEPTION 'You cannot send a message for another member.'
        USING ERRCODE = '42501';
    END IF;
  END IF;
  IF v_actor IS NOT NULL THEN
    PERFORM private.assert_active_member(v_actor, false);
  END IF;
  PERFORM private.assert_active_member(NEW.sender_id, false);
  PERFORM private.assert_active_member(NEW.receiver_id, false);
  SELECT u.messaging_suspended_until INTO v_suspended_until
  FROM public.users u WHERE u.id = NEW.sender_id;
  IF v_suspended_until IS NOT NULL AND v_suspended_until > now() THEN
    RAISE EXCEPTION 'messaging_suspended' USING ERRCODE = 'P0001',
      DETAIL = json_build_object('until', v_suspended_until)::text;
  END IF;
  PERFORM private.assert_outgoing_chat_entitlement(NEW.sender_id);
  RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION public.can_open_chat(uuid)
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.get_chat_inbox(integer, timestamptz)
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.send_chat_message(uuid, text)
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.assert_messaging_allowed()
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.can_open_chat(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_chat_inbox(integer, timestamptz) TO authenticated;
GRANT EXECUTE ON FUNCTION public.send_chat_message(uuid, text) TO authenticated;

COMMENT ON FUNCTION public.can_open_chat(uuid) IS
  'Participant chat authorization with private neutral read-only state for unavailable peers.';
COMMENT ON FUNCTION public.get_chat_inbox(integer, timestamptz) IS
  'Participant-only inbox; unavailable peers are neutralized without disclosing moderation state.';

NOTIFY pgrst, 'reload schema';
