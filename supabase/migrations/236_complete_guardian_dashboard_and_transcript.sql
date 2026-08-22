-- Complete the user-facing Guardian journey with a privacy-aware dashboard,
-- per-Guardian approval state, and an authorized paginated transcript.

CREATE OR REPLACE FUNCTION public.get_guardian_dashboard_v2(
  p_mark_seen_ward_id uuid DEFAULT NULL
)
RETURNS TABLE(
  ward_name text,
  ward_profile_id uuid,
  ward_user_id uuid,
  match_id uuid,
  other_party_user_id uuid,
  other_party_name text,
  last_message text,
  last_message_at timestamptz,
  unread_count bigint,
  guardian_mode text,
  match_status text,
  guardian_has_approved boolean,
  all_guardians_approved boolean,
  match_created_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_guardian_id uuid := private.assert_authenticated();
BEGIN
  PERFORM private.assert_active_member(v_guardian_id, false);

  IF p_mark_seen_ward_id IS NOT NULL
    AND NOT public.is_current_guardian_for_ward(p_mark_seen_ward_id, NULL) THEN
    RAISE EXCEPTION 'guardian_not_authorized' USING ERRCODE = 'P0001';
  END IF;

  RETURN QUERY
  SELECT
    coalesce(
      nullif(trim(concat_ws(' ', ward_p.first_name, ward_p.last_name)), ''),
      'Member'
    ),
    ward_p.id,
    gcm.ward_id,
    gcm.match_id,
    other_p.user_id,
    coalesce(
      nullif(trim(concat_ws(' ', other_p.first_name, other_p.last_name)), ''),
      'Member'
    ),
    (
      SELECT left(msg.content, 120)
      FROM public.messages msg
      WHERE msg.match_id = gcm.match_id
        AND CASE
          WHEN m.user_a = gcm.ward_id THEN NOT msg.deleted_by_a
          ELSE NOT msg.deleted_by_b
        END
      ORDER BY msg.created_at DESC, msg.id DESC
      LIMIT 1
    ),
    (
      SELECT msg.created_at
      FROM public.messages msg
      WHERE msg.match_id = gcm.match_id
        AND CASE
          WHEN m.user_a = gcm.ward_id THEN NOT msg.deleted_by_a
          ELSE NOT msg.deleted_by_b
        END
      ORDER BY msg.created_at DESC, msg.id DESC
      LIMIT 1
    ),
    (
      SELECT count(*)
      FROM public.messages msg
      WHERE msg.match_id = gcm.match_id
        AND msg.created_at > coalesce(
          (
            SELECT gs.last_seen_at
            FROM public.guardian_sessions gs
            WHERE gs.guardian_id = v_guardian_id
              AND gs.ward_id = gcm.ward_id
          ),
          '-infinity'::timestamptz
        )
        AND CASE
          WHEN m.user_a = gcm.ward_id THEN NOT msg.deleted_by_a
          ELSE NOT msg.deleted_by_b
        END
    ),
    gcm.mode,
    m.status,
    EXISTS (
      SELECT 1
      FROM private.guardian_match_approvals approval
      WHERE approval.match_id = gcm.match_id
        AND approval.ward_id = gcm.ward_id
        AND approval.guardian_id = v_guardian_id
    ),
    private.guardian_approvals_complete(gcm.match_id),
    m.created_at
  FROM public.guardian_chat_mirrors gcm
  JOIN public.matches m ON m.id = gcm.match_id
  JOIN public.profiles ward_p ON ward_p.user_id = gcm.ward_id
  JOIN public.profiles other_p ON other_p.user_id = CASE
    WHEN m.user_a = gcm.ward_id THEN m.user_b
    ELSE m.user_a
  END
  JOIN public.users ward_account ON ward_account.id = gcm.ward_id
  JOIN public.users other_account ON other_account.id = other_p.user_id
  WHERE gcm.guardian_id = v_guardian_id
    AND ward_p.guardian_user_id = v_guardian_id
    AND ward_p.guardian_mode = gcm.mode
    AND ward_p.guardian_mode IN ('passive', 'active')
    AND m.status IN ('active', 'pending')
    AND ward_account.deleted_at IS NULL
    AND other_account.deleted_at IS NULL
    AND coalesce(ward_account.is_banned, false) = false
    AND coalesce(other_account.is_banned, false) = false
  ORDER BY coalesce(m.last_message_at, m.created_at) DESC, m.id DESC;

  IF p_mark_seen_ward_id IS NOT NULL THEN
    INSERT INTO public.guardian_sessions(
      guardian_id, ward_id, last_seen_at, is_active
    ) VALUES (v_guardian_id, p_mark_seen_ward_id, now(), true)
    ON CONFLICT (guardian_id, ward_id) DO UPDATE
    SET last_seen_at = EXCLUDED.last_seen_at,
        is_active = true;
  END IF;
END;
$$;

REVOKE ALL ON FUNCTION public.get_guardian_dashboard_v2(uuid)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_guardian_dashboard_v2(uuid)
  TO authenticated;

CREATE OR REPLACE FUNCTION public.get_guardian_match_messages(
  p_match_id uuid,
  p_before_created_at timestamptz DEFAULT NULL,
  p_before_id uuid DEFAULT NULL,
  p_limit integer DEFAULT 50
)
RETURNS TABLE(
  message_id uuid,
  content text,
  created_at timestamptz,
  is_from_ward boolean,
  sent_by_guardian boolean,
  delivery_status text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_guardian_id uuid := private.assert_authenticated();
  v_ward_id uuid;
  v_user_a uuid;
BEGIN
  PERFORM private.assert_active_member(v_guardian_id, false);
  IF (p_before_created_at IS NULL) <> (p_before_id IS NULL) THEN
    RAISE EXCEPTION 'invalid_message_cursor' USING ERRCODE = '22023';
  END IF;

  SELECT gcm.ward_id, m.user_a
  INTO v_ward_id, v_user_a
  FROM public.guardian_chat_mirrors gcm
  JOIN public.matches m ON m.id = gcm.match_id
  WHERE gcm.match_id = p_match_id
    AND gcm.guardian_id = v_guardian_id
    AND public.is_current_guardian_for_ward(gcm.ward_id, NULL);
  IF v_ward_id IS NULL THEN
    RAISE EXCEPTION 'guardian_not_authorized' USING ERRCODE = 'P0001';
  END IF;

  RETURN QUERY
  SELECT
    msg.id,
    msg.content,
    msg.created_at,
    msg.sender_id = v_ward_id,
    coalesce(msg.sent_by_guardian, false),
    coalesce(msg.status, 'sent')
  FROM public.messages msg
  WHERE msg.match_id = p_match_id
    AND CASE
      WHEN v_user_a = v_ward_id THEN NOT msg.deleted_by_a
      ELSE NOT msg.deleted_by_b
    END
    AND (
      p_before_created_at IS NULL
      OR (msg.created_at, msg.id) < (p_before_created_at, p_before_id)
    )
  ORDER BY msg.created_at DESC, msg.id DESC
  LIMIT least(greatest(coalesce(p_limit, 50), 1), 50);
END;
$$;

REVOKE ALL ON FUNCTION public.get_guardian_match_messages(
  uuid, timestamptz, uuid, integer
) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_guardian_match_messages(
  uuid, timestamptz, uuid, integer
) TO authenticated;

NOTIFY pgrst, 'reload schema';
