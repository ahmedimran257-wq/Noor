-- Safe rematch lifecycle and per-participant conversation deletion.
--
-- Respectfully closed/expired pairs cool down for seven days, after which they
-- may meet again through a brand-new interest and match row. Safety closures
-- (block/report) remain permanent. Deleting a closed chat is a participant-
-- scoped hide: the other participant and moderation evidence are untouched.

-- Historical accepted interests must stop excluding a respectfully closed
-- pair forever. `closed` releases the partial active-interest uniqueness rule
-- while preserving the original record and its timestamps.
ALTER TABLE public.interests
  DROP CONSTRAINT IF EXISTS interests_status_check;
ALTER TABLE public.interests
  ADD CONSTRAINT interests_status_check CHECK (
    status IN ('pending','accepted','declined','expired','withdrawn','closed')
  );

-- One active match per pair, but any number of immutable historical cycles.
DROP INDEX IF EXISTS public.uq_match_pair;
CREATE UNIQUE INDEX IF NOT EXISTS uq_active_match_pair
  ON public.matches(
    LEAST(user_a, user_b),
    GREATEST(user_a, user_b)
  )
  WHERE status = 'active';

ALTER TABLE public.matches
  ADD COLUMN IF NOT EXISTS hidden_by_a_at timestamptz,
  ADD COLUMN IF NOT EXISTS hidden_by_b_at timestamptz;

COMMENT ON COLUMN public.matches.hidden_by_a_at IS
  'Participant A removed this non-active conversation from their own inbox.';
COMMENT ON COLUMN public.matches.hidden_by_b_at IS
  'Participant B removed this non-active conversation from their own inbox.';

-- Repair existing pairs so already closed/expired matches can become eligible
-- after the same cooldown used for new closures.
UPDATE public.interests i
SET status = 'closed'
WHERE i.status = 'accepted'
  AND EXISTS (
    SELECT 1
    FROM public.matches m
    WHERE (
      (m.user_a = i.sender_id AND m.user_b = i.receiver_id)
      OR (m.user_a = i.receiver_id AND m.user_b = i.sender_id)
    )
      AND m.status IN ('closed','expired','blocked','reported')
  );

CREATE OR REPLACE FUNCTION private.close_interest_for_finished_match()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  IF OLD.status IS DISTINCT FROM NEW.status
    AND OLD.status = 'active'
    AND NEW.status IN ('closed','expired','blocked','reported') THEN
    UPDATE public.interests i
    SET status = 'closed'
    WHERE i.status = 'accepted'
      AND (
        (i.sender_id = NEW.user_a AND i.receiver_id = NEW.user_b)
        OR (i.sender_id = NEW.user_b AND i.receiver_id = NEW.user_a)
      );
  END IF;
  RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION private.close_interest_for_finished_match()
  FROM PUBLIC;

DROP TRIGGER IF EXISTS trg_close_interest_for_finished_match
  ON public.matches;
CREATE TRIGGER trg_close_interest_for_finished_match
  AFTER UPDATE OF status ON public.matches
  FOR EACH ROW
  EXECUTE FUNCTION private.close_interest_for_finished_match();

-- Multiple historical match rows require explicit creation instead of the old
-- lifetime-pair ON CONFLICT rule.
CREATE OR REPLACE FUNCTION public.create_match_on_accept()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_low uuid := LEAST(NEW.sender_id, NEW.receiver_id);
  v_high uuid := GREATEST(NEW.sender_id, NEW.receiver_id);
BEGIN
  IF NEW.status <> 'accepted' THEN
    RETURN NEW;
  END IF;

  PERFORM pg_advisory_xact_lock(
    hashtextextended(v_low::text || ':' || v_high::text, 182)
  );

  IF EXISTS (
    SELECT 1 FROM public.blocks b
    WHERE (b.blocker_id = v_low AND b.blocked_id = v_high)
       OR (b.blocker_id = v_high AND b.blocked_id = v_low)
  ) OR EXISTS (
    SELECT 1 FROM public.reports r
    WHERE (r.reporter_id = v_low AND r.reported_user_id = v_high)
       OR (r.reporter_id = v_high AND r.reported_user_id = v_low)
  ) OR EXISTS (
    SELECT 1 FROM public.matches m
    WHERE m.user_a = v_low
      AND m.user_b = v_high
      AND m.status IN ('active','blocked','reported')
  ) THEN
    RAISE EXCEPTION 'match_pair_unavailable' USING ERRCODE = 'P0001';
  END IF;

  INSERT INTO public.matches(user_a, user_b, status)
  VALUES (v_low, v_high, 'active');
  RETURN NEW;
END;
$$;

-- Direct API calls receive the same safety and cooldown rules as Discovery.
CREATE OR REPLACE FUNCTION public.send_interest(
  p_receiver_id uuid,
  p_note text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_sender uuid := private.assert_authenticated();
  v_id uuid;
  v_low uuid := LEAST(v_sender, p_receiver_id);
  v_high uuid := GREATEST(v_sender, p_receiver_id);
  v_available_at timestamptz;
BEGIN
  IF p_receiver_id = v_sender THEN
    RAISE EXCEPTION 'cannot_interest_self' USING ERRCODE = 'P0001';
  END IF;
  IF char_length(coalesce(p_note, '')) > 200 THEN
    RAISE EXCEPTION 'interest_note_too_long' USING ERRCODE = 'P0001';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.profiles p
    JOIN public.users u ON u.id = p.user_id
    WHERE p.user_id = p_receiver_id
      AND p.visibility = 'visible'
      AND u.deleted_at IS NULL
      AND coalesce(u.is_banned, false) = false
  ) THEN
    RAISE EXCEPTION 'profile_unavailable' USING ERRCODE = 'P0001';
  END IF;

  PERFORM pg_advisory_xact_lock(
    hashtextextended(v_low::text || ':' || v_high::text, 182)
  );

  IF EXISTS (
    SELECT 1 FROM public.blocks b
    WHERE (b.blocker_id = v_sender AND b.blocked_id = p_receiver_id)
       OR (b.blocker_id = p_receiver_id AND b.blocked_id = v_sender)
  ) OR EXISTS (
    SELECT 1 FROM public.reports r
    WHERE (r.reporter_id = v_sender AND r.reported_user_id = p_receiver_id)
       OR (r.reporter_id = p_receiver_id AND r.reported_user_id = v_sender)
  ) OR EXISTS (
    SELECT 1 FROM public.matches m
    WHERE m.user_a = v_low
      AND m.user_b = v_high
      AND m.status IN ('blocked','reported')
  ) THEN
    RAISE EXCEPTION 'profile_unavailable' USING ERRCODE = 'P0001';
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.matches m
    WHERE m.user_a = v_low AND m.user_b = v_high AND m.status = 'active'
  ) THEN
    RAISE EXCEPTION 'already_matched' USING ERRCODE = 'P0001';
  END IF;

  SELECT max(coalesce(m.closed_at, m.created_at) + interval '7 days')
  INTO v_available_at
  FROM public.matches m
  WHERE m.user_a = v_low
    AND m.user_b = v_high
    AND m.status IN ('closed','expired')
    AND coalesce(m.closed_at, m.created_at) + interval '7 days' > now();

  IF v_available_at IS NOT NULL THEN
    RAISE EXCEPTION 'rematch_cooldown' USING
      ERRCODE = 'P0001',
      DETAIL = json_build_object('available_at', v_available_at)::text;
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.interests i
    WHERE (
      (i.sender_id = v_sender AND i.receiver_id = p_receiver_id)
      OR (i.sender_id = p_receiver_id AND i.receiver_id = v_sender)
    )
      AND i.status IN ('pending','accepted')
  ) THEN
    RAISE EXCEPTION 'interest_already_active' USING ERRCODE = 'P0001';
  END IF;

  INSERT INTO public.interests(
    sender_id, receiver_id, status, note, created_at, expires_at
  )
  VALUES (
    v_sender, p_receiver_id, 'pending', nullif(trim(p_note), ''),
    now(), now() + interval '14 days'
  )
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;

REVOKE ALL ON FUNCTION public.send_interest(uuid, text)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.send_interest(uuid, text)
  TO authenticated;

-- Hiding is idempotent, limited to finished conversations, and also marks the
-- existing per-message participant deletion flags for consistent semantics.
CREATE OR REPLACE FUNCTION public.hide_chat_conversation(p_match_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_me uuid := private.assert_authenticated();
  v_match public.matches%rowtype;
BEGIN
  SELECT * INTO v_match
  FROM public.matches m
  WHERE m.id = p_match_id
    AND (m.user_a = v_me OR m.user_b = v_me)
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'chat_not_found' USING ERRCODE = 'P0001';
  END IF;
  IF coalesce(v_match.status, 'active') = 'active' THEN
    RAISE EXCEPTION 'end_match_before_deleting_chat' USING ERRCODE = 'P0001';
  END IF;

  IF v_match.user_a = v_me THEN
    UPDATE public.matches SET hidden_by_a_at = coalesce(hidden_by_a_at, now())
    WHERE id = p_match_id;
    UPDATE public.messages SET deleted_by_a = true
    WHERE match_id = p_match_id AND deleted_by_a = false;
  ELSE
    UPDATE public.matches SET hidden_by_b_at = coalesce(hidden_by_b_at, now())
    WHERE id = p_match_id;
    UPDATE public.messages SET deleted_by_b = true
    WHERE match_id = p_match_id AND deleted_by_b = false;
  END IF;

  PERFORM private.touch_discovery_member(v_me);
  RETURN true;
END;
$$;

REVOKE ALL ON FUNCTION public.hide_chat_conversation(uuid)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.hide_chat_conversation(uuid)
  TO authenticated;

-- Hidden conversations cannot be reopened by guessing their match id.
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
  v_gender text;
  v_suspended_until timestamptz;
  v_status text;
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

  v_status := coalesce(v_match.status, 'active');
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

-- Inbox projection now respects each participant's private hide marker.
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
    WHERE (m.user_a = v_me AND m.hidden_by_a_at IS NULL)
       OR (m.user_b = v_me AND m.hidden_by_b_at IS NULL)
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
    CASE WHEN v_content_locked THEN NULL::text
      ELSE inbox.last_message_content END,
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

REVOKE ALL ON FUNCTION public.can_open_chat(uuid)
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.get_chat_inbox(integer, timestamptz)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.can_open_chat(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_chat_inbox(integer, timestamptz)
  TO authenticated;

-- Batch prior-match metadata for the profiles already returned in one
-- Discovery page. This adds one bounded RPC, never one query per card.
CREATE OR REPLACE FUNCTION public.get_prior_match_context(
  p_candidate_user_ids uuid[]
)
RETURNS TABLE(
  candidate_user_id uuid,
  previous_match_at timestamptz,
  previous_match_ended_at timestamptz,
  prior_match_count integer
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
    history.prior_match_count
  FROM candidates c
  JOIN LATERAL (
    SELECT m.created_at, m.closed_at
    FROM public.matches m
    WHERE (
      (m.user_a = v_me AND m.user_b = c.candidate_id)
      OR (m.user_b = v_me AND m.user_a = c.candidate_id)
    )
      AND m.status IN ('closed','expired')
    ORDER BY coalesce(m.closed_at, m.created_at) DESC, m.id DESC
    LIMIT 1
  ) latest ON true
  JOIN LATERAL (
    SELECT count(*)::integer AS prior_match_count
    FROM public.matches m
    WHERE (
      (m.user_a = v_me AND m.user_b = c.candidate_id)
      OR (m.user_b = v_me AND m.user_a = c.candidate_id)
    )
      AND m.status IN ('closed','expired')
  ) history ON true;
END;
$$;

REVOKE ALL ON FUNCTION public.get_prior_match_context(uuid[])
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_prior_match_context(uuid[])
  TO authenticated;

-- Discovery excludes active/safety-closed pairs and closed/expired pairs still
-- inside the cooling-off period. Once the period ends, the pair is eligible
-- again and the batch context above explains their history to both users.
DO $migration$
DECLARE
  v_signature regprocedure :=
    'public.get_discovery_feed(uuid,double precision,uuid,integer,jsonb)'::regprocedure;
  v_definition text;
  v_updated text;
  v_needle text := $needle$      AND NOT EXISTS (
        SELECT 1 FROM public.interests i$needle$;
  v_replacement text := $replacement$      AND NOT EXISTS (
        SELECT 1 FROM public.matches rematch_guard
        WHERE (
          (rematch_guard.user_a = p_viewer_id AND rematch_guard.user_b = dp.user_id)
          OR (rematch_guard.user_b = p_viewer_id AND rematch_guard.user_a = dp.user_id)
        )
          AND (
            rematch_guard.status IN ('active','blocked','reported')
            OR (
              rematch_guard.status IN ('closed','expired')
              AND coalesce(rematch_guard.closed_at, rematch_guard.created_at)
                > now() - interval '7 days'
            )
          )
      )
      AND NOT EXISTS (
        SELECT 1 FROM public.interests i$replacement$;
BEGIN
  SELECT pg_get_functiondef(v_signature) INTO v_definition;
  IF position('FROM public.matches rematch_guard' IN v_definition) = 0 THEN
    v_updated := replace(v_definition, v_needle, v_replacement);
    IF v_updated IS NOT DISTINCT FROM v_definition THEN
      RAISE EXCEPTION 'discovery_rematch_guard_insertion_point_not_found'
        USING ERRCODE = 'P0001';
    END IF;
    EXECUTE v_updated;
  END IF;
END;
$migration$;

-- The token changes when the earliest cooling-off period expires, so the app's
-- 90-second lightweight revision check can reveal the newly eligible profile
-- without periodic full-feed refreshes.
CREATE OR REPLACE FUNCTION private.discovery_rematch_cooldown_token(
  p_user_id uuid
)
RETURNS text
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT count(*)::text || ':' || coalesce(
    extract(epoch FROM min(
      coalesce(m.closed_at, m.created_at) + interval '7 days'
    ))::bigint::text,
    '0'
  )
  FROM public.matches m
  WHERE (m.user_a = p_user_id OR m.user_b = p_user_id)
    AND m.status IN ('closed','expired')
    AND coalesce(m.closed_at, m.created_at) + interval '7 days' > now();
$$;

REVOKE ALL ON FUNCTION private.discovery_rematch_cooldown_token(uuid)
  FROM PUBLIC;

DO $migration$
DECLARE
  v_signature regprocedure :=
    'public.get_my_discovery_revision(jsonb)'::regprocedure;
  v_definition text;
  v_updated text;
  v_needle text := $needle$coalesce(v_catalog_token, 'catalog=0') || ':member=' || v_member_revision::text,$needle$;
  v_replacement text := $replacement$coalesce(v_catalog_token, 'catalog=0') || ':member=' || v_member_revision::text || ':rematch=' || private.discovery_rematch_cooldown_token(v_me),$replacement$;
BEGIN
  SELECT pg_get_functiondef(v_signature) INTO v_definition;
  IF position('private.discovery_rematch_cooldown_token(v_me)' IN v_definition) = 0 THEN
    v_updated := replace(v_definition, v_needle, v_replacement);
    IF v_updated IS NOT DISTINCT FROM v_definition THEN
      RAISE EXCEPTION 'discovery_rematch_revision_insertion_point_not_found'
        USING ERRCODE = 'P0001';
    END IF;
    EXECUTE v_updated;
  END IF;
END;
$migration$;

-- Match revision invalidation should follow lifecycle changes, not every
-- last-message timestamp or participant-private inbox hide.
DROP TRIGGER IF EXISTS trg_discovery_revision_matches ON public.matches;
CREATE TRIGGER trg_discovery_revision_matches
  AFTER INSERT OR DELETE OR UPDATE OF user_a, user_b, status, closed_by, closed_at
  ON public.matches
  FOR EACH ROW EXECUTE FUNCTION private.bump_discovery_pair_revision();

COMMENT ON FUNCTION public.hide_chat_conversation(uuid) IS
  'Hides a finished conversation only for the authenticated participant; evidence and the other participant copy remain.';
COMMENT ON FUNCTION public.get_prior_match_context(uuid[]) IS
  'Bounded prior-match context for already authorized Discovery candidates.';
