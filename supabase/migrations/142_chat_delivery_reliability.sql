-- Chat delivery must be atomic and independent of optional push delivery.
-- The RPC performs explicit participant/access checks and runs with definer
-- privileges so table-grant drift cannot make valid messages disappear.

CREATE OR REPLACE FUNCTION public.send_chat_message(
  p_match_id uuid,
  p_content text
)
RETURNS TABLE (
  message_id uuid,
  created_at timestamptz,
  safety_status text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_me uuid := auth.uid();
  v_match public.matches%rowtype;
  v_receiver uuid;
  v_access record;
  v_check record;
  v_message public.messages%rowtype;
  v_sender_name text;
  v_receiver_wants_push boolean;
BEGIN
  IF v_me IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = 'P0001';
  END IF;

  SELECT * INTO v_match
  FROM public.matches
  WHERE id = p_match_id
  FOR UPDATE;

  IF NOT FOUND OR NOT (v_match.user_a = v_me OR v_match.user_b = v_me) THEN
    RAISE EXCEPTION 'Chat not found' USING ERRCODE = 'P0001';
  END IF;

  IF coalesce(v_match.status, 'active') <> 'active' THEN
    RAISE EXCEPTION 'This chat is closed' USING ERRCODE = 'P0001';
  END IF;

  SELECT * INTO v_access FROM public.can_open_chat(p_match_id);
  IF v_access.allowed IS DISTINCT FROM true THEN
    RAISE EXCEPTION '%', coalesce(v_access.reason, 'messaging_unavailable')
      USING ERRCODE = 'P0001';
  END IF;

  v_receiver := CASE
    WHEN v_match.user_a = v_me THEN v_match.user_b
    ELSE v_match.user_a
  END;

  IF EXISTS (
    SELECT 1 FROM public.blocks b
    WHERE (b.blocker_id = v_me AND b.blocked_id = v_receiver)
       OR (b.blocker_id = v_receiver AND b.blocked_id = v_me)
  ) THEN
    RAISE EXCEPTION 'This chat is unavailable' USING ERRCODE = 'P0001';
  END IF;

  SELECT * INTO v_check FROM public.chat_safety_check(p_content);
  IF v_check.safety_status = 'blocked' THEN
    PERFORM public.record_chat_safety_violation(
      v_me,
      v_check.safety_reason,
      p_content
    );
    RAISE EXCEPTION 'Message blocked by safety rules: %', v_check.safety_reason
      USING ERRCODE = 'P0001';
  END IF;

  INSERT INTO public.messages (
    match_id,
    sender_id,
    receiver_id,
    content,
    status,
    safety_status,
    safety_reason
  )
  VALUES (
    p_match_id,
    v_me,
    v_receiver,
    v_check.sanitized_content,
    'sent',
    v_check.safety_status,
    v_check.safety_reason
  )
  RETURNING * INTO v_message;

  -- Push is best-effort. Realtime/database delivery is authoritative and must
  -- remain committed even if a preference row or notification worker fails.
  BEGIN
    SELECT coalesce(np.new_message, true)
    INTO v_receiver_wants_push
    FROM public.users u
    LEFT JOIN public.notification_prefs np ON np.user_id = u.id
    WHERE u.id = v_receiver;

    IF coalesce(v_receiver_wants_push, true) THEN
      SELECT coalesce(nullif(p.first_name, ''), 'Silarah member')
      INTO v_sender_name
      FROM public.profiles p
      WHERE p.user_id = v_me;

      PERFORM public.queue_notification(
        v_receiver,
        'new_message',
        'New message',
        coalesce(v_sender_name, 'A Silarah member') || ' sent you a message.',
        '/chat/' || p_match_id::text
      );
    END IF;
  EXCEPTION WHEN OTHERS THEN
    RAISE WARNING 'Message % committed without push enqueue: %',
      v_message.id, SQLERRM;
  END;

  RETURN QUERY
  SELECT v_message.id, v_message.created_at, v_message.safety_status;
END;
$$;

REVOKE ALL ON FUNCTION public.send_chat_message(uuid, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.send_chat_message(uuid, text) TO authenticated;

COMMENT ON FUNCTION public.send_chat_message(uuid, text) IS
  'Authoritative participant-checked chat write. Notification enqueue failure never rolls back message delivery.';
