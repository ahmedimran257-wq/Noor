-- ============================================================
-- MITHAQ — Chat scaling, read receipts, and server-side safety
-- ============================================================

ALTER TABLE messages
  ADD COLUMN IF NOT EXISTS delivered_at timestamptz,
  ADD COLUMN IF NOT EXISTS safety_status text NOT NULL DEFAULT 'clean',
  ADD COLUMN IF NOT EXISTS safety_reason text;

ALTER TABLE blocks
  ADD COLUMN IF NOT EXISTS reason text;

ALTER TABLE messages
  DROP CONSTRAINT IF EXISTS messages_safety_status_check;

ALTER TABLE messages
  ADD CONSTRAINT messages_safety_status_check
  CHECK (safety_status IN ('clean', 'blocked', 'flagged'));

CREATE INDEX IF NOT EXISTS idx_messages_match_created_id
  ON messages(match_id, created_at DESC, id DESC);

CREATE INDEX IF NOT EXISTS idx_messages_match_receiver_unread
  ON messages(match_id, receiver_id, created_at DESC)
  WHERE read_at IS NULL;

ALTER TABLE content_violations
  DROP CONSTRAINT IF EXISTS content_violations_violation_type_check;

ALTER TABLE content_violations
  ADD CONSTRAINT content_violations_violation_type_check
  CHECK (violation_type IN (
    'phone_number',
    'social_media',
    'url',
    'email',
    'harassment',
    'blocked_term'
  ));

CREATE TABLE IF NOT EXISTS chat_blocked_terms (
  term        text PRIMARY KEY,
  severity    text NOT NULL DEFAULT 'block'
              CHECK (severity IN ('block', 'flag')),
  reason      text NOT NULL DEFAULT 'blocked_term',
  created_at  timestamptz NOT NULL DEFAULT now()
);

INSERT INTO chat_blocked_terms (term, severity, reason) VALUES
  ('send nudes', 'block', 'harassment'),
  ('nudes', 'block', 'harassment'),
  ('nude pic', 'block', 'harassment'),
  ('sex chat', 'block', 'harassment'),
  ('whatsapp', 'block', 'social_media'),
  ('telegram', 'block', 'social_media'),
  ('snapchat', 'block', 'social_media'),
  ('instagram', 'block', 'social_media')
ON CONFLICT (term) DO NOTHING;

ALTER TABLE chat_blocked_terms ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS chat_blocked_terms_admin_select ON chat_blocked_terms;
CREATE POLICY chat_blocked_terms_admin_select ON chat_blocked_terms
FOR SELECT USING (public.is_active_admin());

CREATE TABLE IF NOT EXISTS message_reports (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  message_id       uuid NOT NULL REFERENCES messages(id) ON DELETE CASCADE,
  match_id         uuid NOT NULL REFERENCES matches(id) ON DELETE CASCADE,
  reporter_id      uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  reported_user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  reason           text NOT NULL CHECK (
    reason IN ('harassment', 'inappropriate', 'scam', 'contact_sharing', 'other')
  ),
  description      text,
  status           text NOT NULL DEFAULT 'pending'
                   CHECK (status IN ('pending', 'reviewed', 'dismissed', 'actioned')),
  created_at       timestamptz NOT NULL DEFAULT now(),
  UNIQUE (message_id, reporter_id)
);

ALTER TABLE message_reports ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS message_reports_select_own ON message_reports;
CREATE POLICY message_reports_select_own ON message_reports
FOR SELECT USING (reporter_id = auth.uid() OR public.is_active_admin());

DROP POLICY IF EXISTS message_reports_insert_own ON message_reports;
CREATE POLICY message_reports_insert_own ON message_reports
FOR INSERT WITH CHECK (reporter_id = auth.uid());

CREATE INDEX IF NOT EXISTS idx_message_reports_status
  ON message_reports(status, created_at DESC);

CREATE OR REPLACE FUNCTION public.chat_safety_check(p_content text)
RETURNS TABLE (
  safety_status text,
  safety_reason text,
  sanitized_content text
)
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
  v_content text := btrim(coalesce(p_content, ''));
  v_term record;
BEGIN
  IF char_length(v_content) = 0 THEN
    RETURN QUERY SELECT 'blocked'::text, 'empty'::text, v_content;
    RETURN;
  END IF;

  IF char_length(v_content) > 2000 THEN
    RETURN QUERY SELECT 'blocked'::text, 'too_long'::text, left(v_content, 2000);
    RETURN;
  END IF;

  IF v_content ~* '(^|[^\d])(?:\+?\d[\d\s().-]{7,}\d)([^\d]|$)' THEN
    RETURN QUERY SELECT 'blocked'::text, 'phone_number'::text, v_content;
    RETURN;
  END IF;

  IF v_content ~* '[A-Z0-9._%+\-]+@[A-Z0-9.\-]+\.[A-Z]{2,}' THEN
    RETURN QUERY SELECT 'blocked'::text, 'email'::text, v_content;
    RETURN;
  END IF;

  IF v_content ~* '((https?://|www\.)\S+|[a-z0-9-]+\.(com|net|org|io|in|co|me|app)\b)' THEN
    RETURN QUERY SELECT 'blocked'::text, 'url'::text, v_content;
    RETURN;
  END IF;

  FOR v_term IN
    SELECT term, severity, reason
    FROM chat_blocked_terms
    WHERE position(lower(term) in lower(v_content)) > 0
    ORDER BY CASE severity WHEN 'block' THEN 0 ELSE 1 END
  LOOP
    RETURN QUERY SELECT
      CASE WHEN v_term.severity = 'block' THEN 'blocked' ELSE 'flagged' END::text,
      v_term.reason::text,
      v_content;
    RETURN;
  END LOOP;

  RETURN QUERY SELECT 'clean'::text, NULL::text, v_content;
END;
$$;

CREATE OR REPLACE FUNCTION public.record_chat_safety_violation(
  p_user_id uuid,
  p_reason text,
  p_content text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_type text;
  v_recent_count int;
BEGIN
  v_type := CASE p_reason
    WHEN 'phone_number' THEN 'phone_number'
    WHEN 'email' THEN 'email'
    WHEN 'url' THEN 'url'
    WHEN 'social_media' THEN 'social_media'
    WHEN 'harassment' THEN 'harassment'
    ELSE 'blocked_term'
  END;

  INSERT INTO content_violations(user_id, violation_type, original_content)
  VALUES (p_user_id, v_type, left(coalesce(p_content, ''), 500));

  SELECT count(*) INTO v_recent_count
  FROM content_violations
  WHERE user_id = p_user_id
    AND created_at >= now() - interval '24 hours';

  IF v_recent_count >= 3 THEN
    UPDATE users
    SET messaging_suspended_until = greatest(
      coalesce(messaging_suspended_until, now()),
      now() + interval '24 hours'
    )
    WHERE id = p_user_id;
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public.enforce_chat_message_safety()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_check record;
BEGIN
  SELECT * INTO v_check FROM chat_safety_check(NEW.content);

  NEW.content := v_check.sanitized_content;
  NEW.safety_status := v_check.safety_status;
  NEW.safety_reason := v_check.safety_reason;

  IF v_check.safety_status = 'blocked' THEN
    PERFORM record_chat_safety_violation(NEW.sender_id, v_check.safety_reason, NEW.content);
    RAISE EXCEPTION 'Message blocked by safety rules: %', v_check.safety_reason
      USING ERRCODE = 'P0001';
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_enforce_chat_message_safety ON messages;
CREATE TRIGGER trg_enforce_chat_message_safety
  BEFORE INSERT ON messages
  FOR EACH ROW
  EXECUTE FUNCTION enforce_chat_message_safety();

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
    FROM matches m
    WHERE (m.user_a = v_me OR m.user_b = v_me)
      AND (
        p_before IS NULL OR
        coalesce((
          SELECT max(msg.created_at) FROM messages msg WHERE msg.match_id = m.id
        ), m.created_at) < p_before
      )
  )
  SELECT
    m.id,
    CASE WHEN m.user_a = v_me THEN m.user_b ELSE m.user_a END AS other_user_id,
    coalesce(nullif(p.first_name, ''), 'Member') AS other_first_name,
    left(coalesce(nullif(p.last_name, ''), ''), 1) AS other_last_initial,
    m.status,
    m.closure_reason,
    m.created_at,
    lm.id,
    lm.content,
    lm.sender_id,
    lm.created_at,
    lm.read_at,
    coalesce(uc.unread_count, 0)::int
  FROM visible_matches m
  LEFT JOIN profiles p
    ON p.user_id = CASE WHEN m.user_a = v_me THEN m.user_b ELSE m.user_a END
  LEFT JOIN LATERAL (
    SELECT msg.id, msg.content, msg.sender_id, msg.created_at, msg.read_at
    FROM messages msg
    WHERE msg.match_id = m.id
    ORDER BY msg.created_at DESC, msg.id DESC
    LIMIT 1
  ) lm ON true
  LEFT JOIN LATERAL (
    SELECT count(*)::int AS unread_count
    FROM messages msg
    WHERE msg.match_id = m.id
      AND msg.receiver_id = v_me
      AND msg.read_at IS NULL
  ) uc ON true
  ORDER BY coalesce(lm.created_at, m.created_at) DESC, m.id DESC
  LIMIT greatest(1, least(coalesce(p_limit, 50), 100));
END;
$$;

CREATE OR REPLACE FUNCTION public.get_chat_messages(
  p_match_id uuid,
  p_limit int DEFAULT 50,
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
SECURITY INVOKER
AS $$
DECLARE
  v_me uuid := auth.uid();
BEGIN
  IF v_me IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = 'P0001';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM matches m
    WHERE m.id = p_match_id
      AND (m.user_a = v_me OR m.user_b = v_me)
  ) THEN
    RAISE EXCEPTION 'Chat not found' USING ERRCODE = 'P0001';
  END IF;

  UPDATE messages msg
  SET delivered_at = coalesce(msg.delivered_at, now()),
      status = CASE WHEN msg.status = 'sent' THEN 'delivered' ELSE msg.status END
  WHERE msg.match_id = p_match_id
    AND msg.receiver_id = v_me
    AND msg.delivered_at IS NULL;

  RETURN QUERY
  SELECT *
  FROM (
    SELECT
      msg.id,
      msg.sender_id,
      msg.receiver_id,
      msg.content,
      msg.created_at,
      msg.read_at,
      msg.delivered_at,
      msg.status,
      coalesce(msg.sent_by_guardian, false),
      coalesce(msg.translations, '{}'::jsonb)
    FROM messages msg
    WHERE msg.match_id = p_match_id
      AND (p_before IS NULL OR msg.created_at < p_before)
    ORDER BY msg.created_at DESC, msg.id DESC
    LIMIT greatest(1, least(coalesce(p_limit, 50), 100))
  ) page
  ORDER BY page.created_at ASC, page.id ASC;
END;
$$;

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
SECURITY INVOKER
AS $$
DECLARE
  v_me uuid := auth.uid();
  v_match matches%rowtype;
  v_receiver uuid;
  v_check record;
  v_message messages%rowtype;
BEGIN
  IF v_me IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = 'P0001';
  END IF;

  SELECT * INTO v_match
  FROM matches
  WHERE id = p_match_id
  FOR UPDATE;

  IF NOT FOUND OR NOT (v_match.user_a = v_me OR v_match.user_b = v_me) THEN
    RAISE EXCEPTION 'Chat not found' USING ERRCODE = 'P0001';
  END IF;

  IF coalesce(v_match.status, 'active') <> 'active' THEN
    RAISE EXCEPTION 'This chat is closed' USING ERRCODE = 'P0001';
  END IF;

  v_receiver := CASE WHEN v_match.user_a = v_me THEN v_match.user_b ELSE v_match.user_a END;

  IF EXISTS (
    SELECT 1 FROM blocks b
    WHERE (b.blocker_id = v_me AND b.blocked_id = v_receiver)
       OR (b.blocker_id = v_receiver AND b.blocked_id = v_me)
  ) THEN
    RAISE EXCEPTION 'This chat is unavailable' USING ERRCODE = 'P0001';
  END IF;

  SELECT * INTO v_check FROM chat_safety_check(p_content);
  IF v_check.safety_status = 'blocked' THEN
    PERFORM record_chat_safety_violation(v_me, v_check.safety_reason, p_content);
    RAISE EXCEPTION 'Message blocked by safety rules: %', v_check.safety_reason
      USING ERRCODE = 'P0001';
  END IF;

  INSERT INTO messages (
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

  RETURN QUERY SELECT v_message.id, v_message.created_at, v_message.safety_status;
END;
$$;

CREATE OR REPLACE FUNCTION public.mark_chat_read(p_match_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY INVOKER
AS $$
DECLARE
  v_me uuid := auth.uid();
BEGIN
  IF v_me IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = 'P0001';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM matches m
    WHERE m.id = p_match_id
      AND (m.user_a = v_me OR m.user_b = v_me)
  ) THEN
    RAISE EXCEPTION 'Chat not found' USING ERRCODE = 'P0001';
  END IF;

  UPDATE messages msg
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
SECURITY INVOKER
AS $$
DECLARE
  v_me uuid := auth.uid();
  v_msg messages%rowtype;
  v_reason text := lower(coalesce(p_reason, 'other'));
BEGIN
  IF v_me IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = 'P0001';
  END IF;

  SELECT * INTO v_msg
  FROM messages
  WHERE id = p_message_id;

  IF NOT FOUND OR NOT (v_msg.sender_id = v_me OR v_msg.receiver_id = v_me) THEN
    RAISE EXCEPTION 'Message not found' USING ERRCODE = 'P0001';
  END IF;

  IF v_msg.sender_id = v_me THEN
    RAISE EXCEPTION 'You cannot report your own message' USING ERRCODE = 'P0001';
  END IF;

  IF v_reason NOT IN ('harassment', 'inappropriate', 'scam', 'contact_sharing', 'other') THEN
    v_reason := 'other';
  END IF;

  INSERT INTO message_reports (
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
SECURITY INVOKER
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

  INSERT INTO blocks(blocker_id, blocked_id, reason)
  VALUES (v_me, p_user_id, nullif(left(coalesce(p_reason, ''), 500), ''))
  ON CONFLICT (blocker_id, blocked_id) DO NOTHING;
END;
$$;

REVOKE ALL ON FUNCTION public.chat_safety_check(text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.send_chat_message(uuid, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.get_chat_inbox(int, timestamptz) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.get_chat_messages(uuid, int, timestamptz) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.mark_chat_read(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.report_chat_message(uuid, text, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.block_chat_user(uuid, text) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.chat_safety_check(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.send_chat_message(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_chat_inbox(int, timestamptz) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_chat_messages(uuid, int, timestamptz) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_chat_read(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.report_chat_message(uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.block_chat_user(uuid, text) TO authenticated;
