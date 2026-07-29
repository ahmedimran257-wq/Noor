-- Second audit: guardian ownership proof, expiring invitations and revocation.

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS guardian_invitation_expires_at timestamptz,
  ADD COLUMN IF NOT EXISTS guardian_invitation_consumed_at timestamptz,
  ADD COLUMN IF NOT EXISTS guardian_invitation_attempts integer NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS guardian_invitation_locked_until timestamptz;

CREATE OR REPLACE FUNCTION public.set_guardian_phone(
  p_profile_id uuid,
  p_phone text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_user_id uuid := private.assert_authenticated();
  v_secret text;
  v_phone text := regexp_replace(coalesce(p_phone, ''), '[^0-9+]', '', 'g');
BEGIN
  IF char_length(v_phone) < 8 OR char_length(v_phone) > 18 THEN
    RAISE EXCEPTION 'invalid_guardian_phone' USING ERRCODE = 'P0001';
  END IF;

  SELECT decrypted_secret INTO v_secret
  FROM vault.decrypted_secrets
  WHERE name = 'guardian_key_v1';
  IF v_secret IS NULL THEN
    RAISE EXCEPTION 'guardian_phone_encryption_unavailable'
      USING ERRCODE = 'P0001';
  END IF;

  UPDATE public.profiles
  SET guardian_phone_encrypted = extensions.pgp_sym_encrypt(v_phone, v_secret),
      guardian_key_version = 'v1',
      guardian_invitation_expires_at = now() + interval '7 days',
      guardian_invitation_consumed_at = NULL,
      guardian_invitation_attempts = 0,
      guardian_invitation_locked_until = NULL
  WHERE id = p_profile_id
    AND user_id = v_user_id
    AND guardian_mode IN ('passive', 'active')
    AND guardian_user_id IS NULL;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'guardian_invitation_unavailable'
      USING ERRCODE = 'P0001';
  END IF;
END;
$$;
REVOKE ALL ON FUNCTION public.set_guardian_phone(uuid, text)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.set_guardian_phone(uuid, text)
  TO authenticated;

-- Every authorization read re-checks the current profile relationship. A stale
-- mirror row can no longer become an access token.
CREATE OR REPLACE FUNCTION public.is_current_guardian_for_ward(
  p_ward_id uuid,
  p_required_mode text DEFAULT NULL
)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.profiles p
    WHERE p.user_id = p_ward_id
      AND p.guardian_user_id = auth.uid()
      AND p.guardian_mode IN ('passive', 'active')
      AND (
        p_required_mode IS NULL
        OR p.guardian_mode = p_required_mode
      )
  );
$$;
REVOKE ALL ON FUNCTION public.is_current_guardian_for_ward(uuid, text)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.is_current_guardian_for_ward(uuid, text)
  TO authenticated;

CREATE OR REPLACE FUNCTION private.sync_guardian_authorization()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  IF NEW.guardian_user_id IS NULL OR NEW.guardian_mode = 'none' THEN
    DELETE FROM public.guardian_chat_mirrors
    WHERE ward_id = NEW.user_id;
    DELETE FROM public.guardian_sessions
    WHERE ward_id = NEW.user_id;
  ELSE
    DELETE FROM public.guardian_chat_mirrors
    WHERE ward_id = NEW.user_id
      AND guardian_id <> NEW.guardian_user_id;
    DELETE FROM public.guardian_sessions
    WHERE ward_id = NEW.user_id
      AND guardian_id <> NEW.guardian_user_id;
    UPDATE public.guardian_chat_mirrors
    SET mode = NEW.guardian_mode
    WHERE ward_id = NEW.user_id
      AND guardian_id = NEW.guardian_user_id
      AND mode IS DISTINCT FROM NEW.guardian_mode;
  END IF;
  RETURN NEW;
END;
$$;
REVOKE ALL ON FUNCTION private.sync_guardian_authorization()
  FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS trg_sync_guardian_authorization ON public.profiles;
CREATE TRIGGER trg_sync_guardian_authorization
  AFTER UPDATE OF guardian_user_id, guardian_mode ON public.profiles
  FOR EACH ROW
  WHEN (
    OLD.guardian_user_id IS DISTINCT FROM NEW.guardian_user_id
    OR OLD.guardian_mode IS DISTINCT FROM NEW.guardian_mode
  )
  EXECUTE FUNCTION private.sync_guardian_authorization();

CREATE OR REPLACE FUNCTION public.set_my_guardian_settings(
  p_enabled boolean,
  p_can_reply boolean DEFAULT false,
  p_name text DEFAULT NULL,
  p_relationship text DEFAULT NULL,
  p_phone_country_code text DEFAULT NULL,
  p_email text DEFAULT NULL,
  p_authority_scope text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_user_id uuid := private.assert_authenticated();
  v_profile public.profiles%ROWTYPE;
  v_mode text := CASE
    WHEN NOT p_enabled THEN 'none'
    WHEN p_can_reply THEN 'active'
    ELSE 'passive'
  END;
BEGIN
  IF p_enabled AND (
    nullif(trim(p_name), '') IS NULL
    OR p_relationship NOT IN (
      'father','mother','brother','sister','uncle','aunt','other'
    )
  ) THEN
    RAISE EXCEPTION 'invalid_guardian_details' USING ERRCODE = 'P0001';
  END IF;

  SELECT * INTO v_profile
  FROM public.profiles
  WHERE user_id = v_user_id
  FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'profile_not_found' USING ERRCODE = 'P0001';
  END IF;

  UPDATE public.profiles
  SET guardian_name = CASE WHEN p_enabled THEN trim(p_name) ELSE NULL END,
      guardian_relationship =
        CASE WHEN p_enabled THEN p_relationship ELSE NULL END,
      guardian_mode = v_mode,
      guardian_phone_country_code =
        CASE WHEN p_enabled
          THEN nullif(trim(p_phone_country_code), '')
          ELSE NULL
        END,
      guardian_email =
        CASE WHEN p_enabled
          THEN nullif(lower(trim(p_email)), '')
          ELSE NULL
        END,
      guardian_authority_scope =
        CASE WHEN p_enabled
          THEN coalesce(nullif(trim(p_authority_scope), ''), 'full')
          ELSE NULL
        END,
      guardian_user_id =
        CASE WHEN p_enabled THEN guardian_user_id ELSE NULL END,
      guardian_phone_encrypted =
        CASE WHEN p_enabled THEN guardian_phone_encrypted ELSE NULL END,
      guardian_invitation_expires_at =
        CASE WHEN p_enabled THEN guardian_invitation_expires_at ELSE NULL END,
      guardian_invitation_consumed_at =
        CASE WHEN p_enabled THEN guardian_invitation_consumed_at ELSE NULL END,
      guardian_invitation_attempts =
        CASE WHEN p_enabled THEN guardian_invitation_attempts ELSE 0 END,
      guardian_invitation_locked_until =
        CASE WHEN p_enabled THEN guardian_invitation_locked_until ELSE NULL END
  WHERE id = v_profile.id;

  INSERT INTO public.admin_audit_log(
    admin_id, action_type, target_user_id, details
  )
  VALUES (
    v_user_id,
    CASE WHEN p_enabled
      THEN 'guardian_settings_updated'
      ELSE 'guardian_revoked'
    END,
    v_user_id,
    jsonb_build_object(
      'previous_mode', v_profile.guardian_mode,
      'new_mode', v_mode,
      'had_linked_guardian', v_profile.guardian_user_id IS NOT NULL
    )
  );
END;
$$;
REVOKE ALL ON FUNCTION public.set_my_guardian_settings(
  boolean, boolean, text, text, text, text, text
) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.set_my_guardian_settings(
  boolean, boolean, text, text, text, text, text
) TO authenticated;

CREATE OR REPLACE FUNCTION public.activate_guardian(
  p_ward_profile_id uuid,
  p_guardian_phone text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_guardian_id uuid := private.assert_authenticated();
  v_verified_phone text;
  v_phone_confirmed_at timestamptz;
  v_stored_phone text;
  v_vault_key text;
  v_profile public.profiles%ROWTYPE;
BEGIN
  -- The caller-supplied phone is deliberately ignored for authorization. It is
  -- retained only to keep old clients wire-compatible while they upgrade.
  PERFORM p_guardian_phone;

  SELECT
    regexp_replace(coalesce(phone, ''), '[^0-9+]', '', 'g'),
    phone_confirmed_at
  INTO v_verified_phone, v_phone_confirmed_at
  FROM auth.users
  WHERE id = v_guardian_id;
  IF v_phone_confirmed_at IS NULL
    OR char_length(v_verified_phone) NOT BETWEEN 8 AND 18 THEN
    RAISE EXCEPTION 'verified_guardian_phone_required'
      USING ERRCODE = 'P0001';
  END IF;

  SELECT decrypted_secret INTO v_vault_key
  FROM vault.decrypted_secrets
  WHERE name = 'guardian_key_v1';
  IF v_vault_key IS NULL THEN
    RAISE EXCEPTION 'guardian_phone_encryption_unavailable'
      USING ERRCODE = 'P0001';
  END IF;

  SELECT * INTO v_profile
  FROM public.profiles
  WHERE id = p_ward_profile_id
  FOR UPDATE;

  IF NOT FOUND
    OR v_profile.guardian_mode NOT IN ('passive', 'active')
    OR v_profile.guardian_phone_encrypted IS NULL
    OR v_profile.guardian_invitation_consumed_at IS NOT NULL
    OR v_profile.guardian_invitation_expires_at <= now()
    OR v_profile.guardian_invitation_locked_until > now()
    OR (
      v_profile.guardian_user_id IS NOT NULL
      AND v_profile.guardian_user_id <> v_guardian_id
    ) THEN
    RAISE EXCEPTION 'guardian_invitation_unavailable'
      USING ERRCODE = 'P0001';
  END IF;
  IF v_profile.user_id = v_guardian_id THEN
    RAISE EXCEPTION 'guardian_self_link_forbidden'
      USING ERRCODE = 'P0001';
  END IF;

  v_stored_phone := regexp_replace(
    extensions.pgp_sym_decrypt(
      v_profile.guardian_phone_encrypted,
      v_vault_key
    ),
    '[^0-9+]',
    '',
    'g'
  );
  IF v_stored_phone IS DISTINCT FROM v_verified_phone THEN
    UPDATE public.profiles
    SET guardian_invitation_attempts = guardian_invitation_attempts + 1,
        guardian_invitation_locked_until = CASE
          WHEN guardian_invitation_attempts + 1 >= 5
            THEN now() + interval '24 hours'
          ELSE guardian_invitation_locked_until
        END
    WHERE id = v_profile.id;
    RETURN jsonb_build_object('status', 'invitation_unavailable');
  END IF;

  UPDATE public.profiles
  SET guardian_user_id = v_guardian_id,
      guardian_invitation_consumed_at = now(),
      guardian_invitation_attempts = 0,
      guardian_invitation_locked_until = NULL
  WHERE id = v_profile.id
    AND guardian_user_id IS NULL;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'guardian_invitation_unavailable'
      USING ERRCODE = 'P0001';
  END IF;

  INSERT INTO public.guardian_chat_mirrors(
    match_id, guardian_id, ward_id, mode
  )
  SELECT m.id, v_guardian_id, v_profile.user_id, v_profile.guardian_mode
  FROM public.matches m
  WHERE v_profile.user_id IN (m.user_a, m.user_b)
    AND m.status = 'active'
  ON CONFLICT (match_id, guardian_id) DO UPDATE
  SET ward_id = EXCLUDED.ward_id,
      mode = EXCLUDED.mode;

  INSERT INTO public.admin_audit_log(
    admin_id, action_type, target_user_id, details
  )
  VALUES (
    v_guardian_id, 'guardian_activated', v_profile.user_id,
    jsonb_build_object(
      'ward_profile_id', v_profile.id,
      'guardian_mode', v_profile.guardian_mode,
      'verified_phone_ownership', true
    )
  );

  RETURN jsonb_build_object(
    'status', 'activated',
    'ward_user_id', v_profile.user_id,
    'mode', v_profile.guardian_mode
  );
END;
$$;
REVOKE ALL ON FUNCTION public.activate_guardian(uuid, text)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.activate_guardian(uuid, text)
  TO authenticated;

-- Purge pre-existing stale authorization before installing stricter policies.
DELETE FROM public.guardian_chat_mirrors gcm
USING public.profiles p
WHERE p.user_id = gcm.ward_id
  AND (
    p.guardian_user_id IS DISTINCT FROM gcm.guardian_id
    OR p.guardian_mode = 'none'
    OR p.guardian_mode IS DISTINCT FROM gcm.mode
  );
DELETE FROM public.guardian_sessions gs
USING public.profiles p
WHERE p.user_id = gs.ward_id
  AND (
    p.guardian_user_id IS DISTINCT FROM gs.guardian_id
    OR p.guardian_mode = 'none'
  );

REVOKE INSERT, UPDATE, DELETE ON public.guardian_chat_mirrors
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON public.guardian_sessions
  FROM PUBLIC, anon, authenticated;

DROP POLICY IF EXISTS guardian_mirrors_select
  ON public.guardian_chat_mirrors;
CREATE POLICY guardian_mirrors_select ON public.guardian_chat_mirrors
  FOR SELECT TO authenticated
  USING (
    ward_id = auth.uid()
    OR public.is_current_guardian_for_ward(ward_id, mode)
  );

DROP POLICY IF EXISTS messages_select ON public.messages;
CREATE POLICY messages_select ON public.messages
  FOR SELECT TO authenticated
  USING (
    sender_id = auth.uid()
    OR receiver_id = auth.uid()
    OR EXISTS (
      SELECT 1
      FROM public.guardian_chat_mirrors gcm
      WHERE gcm.match_id = messages.match_id
        AND gcm.guardian_id = auth.uid()
        AND public.is_current_guardian_for_ward(gcm.ward_id, gcm.mode)
    )
  );

CREATE OR REPLACE FUNCTION public.update_guardian_last_seen(
  p_ward_id uuid
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_guardian_id uuid := private.assert_authenticated();
BEGIN
  IF NOT public.is_current_guardian_for_ward(p_ward_id, NULL) THEN
    RAISE EXCEPTION 'guardian_not_authorized' USING ERRCODE = 'P0001';
  END IF;
  INSERT INTO public.guardian_sessions(
    guardian_id, ward_id, last_seen_at, is_active
  )
  VALUES (v_guardian_id, p_ward_id, now(), true)
  ON CONFLICT (guardian_id, ward_id) DO UPDATE
  SET last_seen_at = EXCLUDED.last_seen_at,
      is_active = true;
END;
$$;
REVOKE ALL ON FUNCTION public.update_guardian_last_seen(uuid)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.update_guardian_last_seen(uuid)
  TO authenticated;

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
BEGIN
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

  v_receiver := CASE
    WHEN v_match.user_a = v_ward THEN v_match.user_b
    ELSE v_match.user_a
  END;
  INSERT INTO public.messages(
    match_id, sender_id, receiver_id, content, sent_by_guardian
  )
  VALUES (
    p_match_id, v_ward, v_receiver, trim(p_content), true
  )
  RETURNING id INTO v_message_id;
  RETURN v_message_id;
END;
$$;
REVOKE ALL ON FUNCTION public.send_guardian_chat_message(uuid, text)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.send_guardian_chat_message(uuid, text)
  TO authenticated;

CREATE OR REPLACE FUNCTION public.guardian_approve_match(p_match_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_guardian_id uuid := private.assert_authenticated();
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM public.guardian_chat_mirrors gcm
    WHERE gcm.match_id = p_match_id
      AND gcm.guardian_id = v_guardian_id
      AND gcm.mode = 'active'
      AND public.is_current_guardian_for_ward(gcm.ward_id, 'active')
  ) THEN
    RAISE EXCEPTION 'guardian_not_authorized' USING ERRCODE = 'P0001';
  END IF;

  UPDATE public.matches
  SET guardian_approved = true,
      guardian_approved_at = now(),
      guardian_approved_by = v_guardian_id
  WHERE id = p_match_id;
END;
$$;
REVOKE ALL ON FUNCTION public.guardian_approve_match(uuid)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.guardian_approve_match(uuid)
  TO authenticated;

CREATE OR REPLACE FUNCTION public.get_guardian_dashboard()
RETURNS TABLE(
  ward_name text,
  ward_profile_id uuid,
  ward_user_id uuid,
  match_id uuid,
  other_party_name text,
  other_party_photo text,
  last_message text,
  last_message_at timestamptz,
  unread_count bigint,
  guardian_mode text,
  match_status text,
  guardian_approved boolean,
  match_created_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_guardian_id uuid := private.assert_authenticated();
BEGIN
  RETURN QUERY
  SELECT
    ward_p.first_name,
    ward_p.id,
    gcm.ward_id,
    gcm.match_id,
    other_p.first_name,
    CASE
      WHEN other_p.photo_privacy = 'public' THEN (
        SELECT ph.storage_path
        FROM public.photos ph
        WHERE ph.profile_id = other_p.id
          AND ph.order_index = 0
          AND ph.admin_approved = true
          AND ph.nsfw_cleared = true
        LIMIT 1
      )
      ELSE NULL
    END,
    (
      SELECT left(msg.content, 120)
      FROM public.messages msg
      WHERE msg.match_id = gcm.match_id
      ORDER BY msg.created_at DESC
      LIMIT 1
    ),
    m.last_message_at,
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
          '1970-01-01'::timestamptz
        )
    ),
    gcm.mode,
    m.status,
    m.guardian_approved,
    m.created_at
  FROM public.guardian_chat_mirrors gcm
  JOIN public.matches m ON m.id = gcm.match_id
  JOIN public.profiles ward_p ON ward_p.user_id = gcm.ward_id
  JOIN public.profiles other_p ON other_p.user_id = CASE
    WHEN m.user_a = gcm.ward_id THEN m.user_b
    ELSE m.user_a
  END
  WHERE gcm.guardian_id = v_guardian_id
    AND ward_p.guardian_user_id = v_guardian_id
    AND ward_p.guardian_mode = gcm.mode
    AND ward_p.guardian_mode IN ('passive', 'active')
    AND m.status IN ('active', 'pending')
  ORDER BY m.last_message_at DESC NULLS LAST, m.created_at DESC;
END;
$$;
REVOKE ALL ON FUNCTION public.get_guardian_dashboard()
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_guardian_dashboard()
  TO authenticated;
