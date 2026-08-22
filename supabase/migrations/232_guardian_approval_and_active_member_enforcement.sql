-- Central standing assertion for relationship and messaging writes. Safety
-- actions (block/report) deliberately remain available to restricted users.
CREATE OR REPLACE FUNCTION private.assert_active_member(
  p_user_id uuid,
  p_require_discoverable boolean DEFAULT false
)
RETURNS void
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  IF p_user_id IS NULL OR NOT EXISTS (
    SELECT 1 FROM public.users u
    WHERE u.id = p_user_id
      AND u.deleted_at IS NULL
      AND coalesce(u.is_banned, false) = false
  ) THEN
    RAISE EXCEPTION 'account_restricted' USING ERRCODE = 'P0001';
  END IF;

  IF p_require_discoverable AND NOT EXISTS (
    SELECT 1 FROM public.profiles p
    WHERE p.user_id = p_user_id
      AND p.onboarding_completed = true
      AND p.visibility = 'visible'
  ) THEN
    RAISE EXCEPTION 'profile_unavailable' USING ERRCODE = 'P0001';
  END IF;
END;
$$;

REVOKE ALL ON FUNCTION private.assert_active_member(uuid, boolean)
  FROM PUBLIC, anon, authenticated;

-- Approval belongs to each actively supervised ward. A single boolean on the
-- match cannot represent two participants who both have active Guardians.
CREATE TABLE IF NOT EXISTS private.guardian_match_approvals (
  match_id uuid NOT NULL REFERENCES public.matches(id) ON DELETE CASCADE,
  ward_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  guardian_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  approved_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (match_id, ward_id)
);

REVOKE ALL ON private.guardian_match_approvals
  FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION private.guardian_approvals_complete(
  p_match_id uuid
)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT EXISTS (SELECT 1 FROM public.matches m WHERE m.id = p_match_id)
    AND NOT EXISTS (
      SELECT 1
      FROM public.matches m
      CROSS JOIN LATERAL (
        VALUES (m.user_a), (m.user_b)
      ) participant(user_id)
      JOIN public.profiles p ON p.user_id = participant.user_id
      WHERE m.id = p_match_id
        AND p.guardian_mode = 'active'
        AND p.guardian_user_id IS NOT NULL
        AND NOT EXISTS (
          SELECT 1
          FROM private.guardian_match_approvals approval
          WHERE approval.match_id = m.id
            AND approval.ward_id = participant.user_id
            AND approval.guardian_id = p.guardian_user_id
        )
    );
$$;

REVOKE ALL ON FUNCTION private.guardian_approvals_complete(uuid)
  FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.guardian_approve_match(p_match_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_guardian_id uuid := private.assert_authenticated();
  v_ward_id uuid;
BEGIN
  PERFORM private.assert_active_member(v_guardian_id, false);

  SELECT gcm.ward_id INTO v_ward_id
  FROM public.guardian_chat_mirrors gcm
  WHERE gcm.match_id = p_match_id
    AND gcm.guardian_id = v_guardian_id
    AND gcm.mode = 'active'
    AND public.is_current_guardian_for_ward(gcm.ward_id, 'active')
  FOR UPDATE;

  IF v_ward_id IS NULL THEN
    RAISE EXCEPTION 'guardian_not_authorized' USING ERRCODE = 'P0001';
  END IF;

  INSERT INTO private.guardian_match_approvals(
    match_id, ward_id, guardian_id, approved_at
  ) VALUES (p_match_id, v_ward_id, v_guardian_id, now())
  ON CONFLICT (match_id, ward_id) DO UPDATE
  SET guardian_id = EXCLUDED.guardian_id,
      approved_at = EXCLUDED.approved_at;

  -- Compatibility projection for the existing dashboard. It becomes true
  -- only when every active Guardian on this match has approved.
  UPDATE public.matches
  SET guardian_approved = private.guardian_approvals_complete(p_match_id),
      guardian_approved_at = CASE
        WHEN private.guardian_approvals_complete(p_match_id) THEN now()
        ELSE NULL
      END,
      guardian_approved_by = CASE
        WHEN private.guardian_approvals_complete(p_match_id)
          THEN v_guardian_id
        ELSE NULL
      END
  WHERE id = p_match_id;
END;
$$;

REVOKE ALL ON FUNCTION public.guardian_approve_match(uuid)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.guardian_approve_match(uuid)
  TO authenticated;

-- Member chat authorization now enforces account standing and every active
-- Guardian approval before any transcript can be opened or message sent.
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
  v_is_banned boolean;
  v_deleted_at timestamptz;
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

  IF v_is_banned OR v_deleted_at IS NOT NULL THEN
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

-- Preserve trigger-level defence, including the one narrowly authorized
-- active-Guardian path. The ward's entitlement and suspension still apply.
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
      SELECT 1
      FROM public.guardian_chat_mirrors gcm
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

  SELECT u.messaging_suspended_until
  INTO v_suspended_until
  FROM public.users u
  WHERE u.id = NEW.sender_id;

  IF v_suspended_until IS NOT NULL AND v_suspended_until > now() THEN
    RAISE EXCEPTION 'messaging_suspended'
      USING ERRCODE = 'P0001',
            DETAIL = json_build_object('until', v_suspended_until)::text;
  END IF;

  PERFORM private.assert_outgoing_chat_entitlement(NEW.sender_id);
  RETURN NEW;
END;
$$;

-- Relationship writes are rejected immediately after ban/deletion. Expiry
-- workers have no auth.uid() and remain able to perform lifecycle updates.
CREATE OR REPLACE FUNCTION private.guard_interest_actor_standing()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE v_actor uuid := auth.uid();
BEGIN
  IF v_actor IS NOT NULL THEN
    PERFORM private.assert_active_member(
      v_actor,
      TG_OP = 'INSERT' AND v_actor = NEW.sender_id
    );
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_guard_interest_actor_standing
  ON public.interests;
CREATE TRIGGER trg_guard_interest_actor_standing
BEFORE INSERT OR UPDATE ON public.interests
FOR EACH ROW EXECUTE FUNCTION private.guard_interest_actor_standing();

REVOKE ALL ON FUNCTION private.guard_interest_actor_standing()
  FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.send_guardian_chat_message(
  p_match_id uuid,
  p_content text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_guardian uuid := private.assert_authenticated();
  v_match public.matches%ROWTYPE;
  v_ward uuid;
  v_receiver uuid;
  v_message_id uuid;
  v_check record;
BEGIN
  PERFORM private.assert_active_member(v_guardian, false);
  IF char_length(trim(coalesce(p_content, ''))) NOT BETWEEN 1 AND 4000 THEN
    RAISE EXCEPTION 'invalid_message' USING ERRCODE = 'P0001';
  END IF;

  SELECT * INTO v_match
  FROM public.matches
  WHERE id = p_match_id
  FOR UPDATE;
  IF NOT FOUND OR coalesce(v_match.status, 'active') <> 'active' THEN
    RAISE EXCEPTION 'chat_unavailable' USING ERRCODE = 'P0001';
  END IF;

  SELECT gcm.ward_id INTO v_ward
  FROM public.guardian_chat_mirrors gcm
  WHERE gcm.match_id = p_match_id
    AND gcm.guardian_id = v_guardian
    AND gcm.mode = 'active'
    AND public.is_current_guardian_for_ward(gcm.ward_id, 'active')
  FOR UPDATE;
  IF v_ward IS NULL OR v_ward NOT IN (v_match.user_a, v_match.user_b) THEN
    RAISE EXCEPTION 'guardian_not_authorized' USING ERRCODE = 'P0001';
  END IF;
  IF NOT private.guardian_approvals_complete(p_match_id) THEN
    RAISE EXCEPTION 'guardian_approval_required' USING ERRCODE = 'P0001';
  END IF;

  SELECT * INTO v_check FROM public.chat_safety_check(p_content);
  IF v_check.safety_status = 'blocked' THEN
    PERFORM public.record_chat_safety_violation(
      v_guardian,
      v_check.safety_reason,
      p_content
    );
    RAISE EXCEPTION 'Message blocked by safety rules: %', v_check.safety_reason
      USING ERRCODE = 'P0001';
  END IF;

  v_receiver := CASE
    WHEN v_match.user_a = v_ward THEN v_match.user_b
    ELSE v_match.user_a
  END;
  INSERT INTO public.messages(
    match_id, sender_id, receiver_id, content, sent_by_guardian,
    status, safety_status, safety_reason
  )
  VALUES (
    p_match_id, v_ward, v_receiver, v_check.sanitized_content, true,
    'sent', v_check.safety_status, v_check.safety_reason
  )
  RETURNING id INTO v_message_id;
  RETURN v_message_id;
END;
$$;

REVOKE ALL ON FUNCTION public.send_guardian_chat_message(uuid, text)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.send_guardian_chat_message(uuid, text)
  TO authenticated;

NOTIFY pgrst, 'reload schema';
