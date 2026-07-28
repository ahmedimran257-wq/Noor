-- Audit 1 containment: make server-owned member state RPC-only.
-- Every mutating function derives the actor from auth.uid(), validates an
-- explicit allowlist/transition and runs in one database transaction.

CREATE SCHEMA IF NOT EXISTS private;
REVOKE ALL ON SCHEMA private FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION private.assert_authenticated()
RETURNS uuid
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_user_id uuid := auth.uid();
BEGIN
  IF v_user_id IS NULL OR auth.role() <> 'authenticated' THEN
    RAISE EXCEPTION 'authentication_required' USING ERRCODE = 'P0001';
  END IF;
  RETURN v_user_id;
END;
$$;

CREATE OR REPLACE FUNCTION private.assert_jsonb_keys(
  p_value jsonb,
  p_allowed text[]
)
RETURNS void
LANGUAGE plpgsql
IMMUTABLE
SET search_path = ''
AS $$
DECLARE
  v_key text;
BEGIN
  IF p_value IS NULL OR jsonb_typeof(p_value) <> 'object' THEN
    RAISE EXCEPTION 'invalid_patch' USING ERRCODE = 'P0001';
  END IF;
  FOR v_key IN SELECT jsonb_object_keys(p_value)
  LOOP
    IF NOT (v_key = ANY (p_allowed)) THEN
      RAISE EXCEPTION 'field_not_permitted:%', v_key USING ERRCODE = 'P0001';
    END IF;
  END LOOP;
END;
$$;

CREATE OR REPLACE FUNCTION public.sync_my_user(
  p_country_code text DEFAULT NULL,
  p_gender text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_user_id uuid := private.assert_authenticated();
  v_auth auth.users%ROWTYPE;
  v_row public.users%ROWTYPE;
  v_gender text := lower(nullif(trim(p_gender), ''));
  v_country text := upper(nullif(trim(p_country_code), ''));
BEGIN
  IF v_gender IS NOT NULL AND v_gender NOT IN ('male', 'female') THEN
    RAISE EXCEPTION 'invalid_gender' USING ERRCODE = 'P0001';
  END IF;

  SELECT * INTO v_auth FROM auth.users WHERE id = v_user_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'authentication_required' USING ERRCODE = 'P0001';
  END IF;

  INSERT INTO public.users (id, email, phone, country_code, gender)
  VALUES (
    v_user_id,
    v_auth.email,
    nullif(v_auth.phone, ''),
    v_country,
    v_gender
  )
  ON CONFLICT (id) DO UPDATE SET
    email = EXCLUDED.email,
    phone = coalesce(nullif(EXCLUDED.phone, ''), public.users.phone),
    country_code = coalesce(EXCLUDED.country_code, public.users.country_code),
    gender = CASE
      WHEN public.users.onboarding_completed IS TRUE
        AND public.users.gender IS DISTINCT FROM EXCLUDED.gender
        AND EXCLUDED.gender IS NOT NULL
        THEN public.users.gender
      ELSE coalesce(EXCLUDED.gender, public.users.gender)
    END
  RETURNING * INTO v_row;

  RETURN to_jsonb(v_row)
    - ARRAY[
      'last_billing_event_ts', 'ban_reason', 'moderation_reason',
      'shadow_banned_at', 'moderated_by'
    ];
END;
$$;

CREATE OR REPLACE FUNCTION public.patch_my_user(p_fields jsonb)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_user_id uuid := private.assert_authenticated();
  v_key text;
  v_assignments text;
  v_row public.users%ROWTYPE;
  v_current public.users%ROWTYPE;
  v_allowed constant text[] := ARRAY[
    'preferred_language', 'timezone', 'country_code', 'gender',
    'is_guardian_path', 'profile_owner_type', 'onboarding_step',
    'onboarding_completed', 'onboarding_profile_for',
    'onboarding_profile_creator_relation', 'onboarding_city_id',
    'onboarding_city_name', 'onboarding_state_name',
    'onboarding_postal_code', 'onboarding_lat', 'onboarding_lng'
  ];
BEGIN
  PERFORM private.assert_jsonb_keys(p_fields, v_allowed);
  SELECT * INTO v_current
  FROM public.users
  WHERE id = v_user_id
  FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'user_not_found' USING ERRCODE = 'P0001';
  END IF;

  IF p_fields ? 'gender'
    AND v_current.onboarding_completed IS TRUE
    AND lower(p_fields->>'gender') IS DISTINCT FROM v_current.gender THEN
    RAISE EXCEPTION 'gender_change_locked' USING ERRCODE = 'P0001';
  END IF;

  SELECT string_agg(
    format(
      '%1$I = (jsonb_populate_record(NULL::public.users, $1)).%1$I',
      v_key
    ),
    ', '
  )
  INTO v_assignments
  FROM jsonb_object_keys(p_fields) AS keys(v_key);

  IF v_assignments IS NULL THEN
    RETURN to_jsonb(v_current);
  END IF;

  EXECUTE format(
    'UPDATE public.users SET %s WHERE id = $2 RETURNING *',
    v_assignments
  )
  INTO v_row
  USING p_fields, v_user_id;

  RETURN to_jsonb(v_row)
    - ARRAY[
      'last_billing_event_ts', 'ban_reason', 'moderation_reason',
      'shadow_banned_at', 'moderated_by'
    ];
END;
$$;

CREATE OR REPLACE FUNCTION public.patch_my_profile(p_fields jsonb)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_user_id uuid := private.assert_authenticated();
  v_key text;
  v_assignments text;
  v_row public.profiles%ROWTYPE;
  v_allowed constant text[] := ARRAY[
    'first_name', 'last_name', 'date_of_birth', 'gender',
    'country_code', 'city_id', 'sect', 'sub_sect', 'deen_level',
    'prays_five_daily', 'hijab', 'beard', 'education_level',
    'education_rank', 'field_of_study', 'profession', 'employment_status',
    'income_bracket', 'income_visibility', 'family_type', 'parents_status',
    'previously_married', 'children_count', 'is_eldest_child',
    'sibling_count', 'bio', 'languages', 'interests', 'height_cm',
    'mother_tongue', 'community', 'residency_status', 'complexion',
    'diet_type', 'smoking_habit', 'vaping_habit', 'hookah_habit',
    'living_expectation', 'quran_memorization', 'religious_education',
    'marriage_timeline', 'willing_to_relocate', 'niqab_preference',
    'mahr_expectation', 'willing_to_work_after_marriage', 'mahr_budget',
    'can_provide_housing', 'can_provide_maintenance', 'debt_status',
    'religious_leadership', 'is_revert', 'polygamy_status',
    'polygamy_acceptance', 'special_needs'
  ];
BEGIN
  PERFORM private.assert_jsonb_keys(p_fields, v_allowed);

  SELECT string_agg(
    format(
      '%1$I = (jsonb_populate_record(NULL::public.profiles, $1)).%1$I',
      v_key
    ),
    ', '
  )
  INTO v_assignments
  FROM jsonb_object_keys(p_fields) AS keys(v_key);

  IF v_assignments IS NULL THEN
    SELECT * INTO v_row FROM public.profiles WHERE user_id = v_user_id;
    RETURN to_jsonb(v_row);
  END IF;

  EXECUTE format(
    'UPDATE public.profiles SET %s WHERE user_id = $2 RETURNING *',
    v_assignments
  )
  INTO v_row
  USING p_fields, v_user_id;

  IF v_row.id IS NULL THEN
    RAISE EXCEPTION 'profile_not_found' USING ERRCODE = 'P0001';
  END IF;

  RETURN to_jsonb(v_row)
    - ARRAY[
      'guardian_phone_encrypted', 'kyc_document_path', 'kyc_selfie_path',
      'suspended_reason', 'static_rank_score'
    ];
END;
$$;

CREATE OR REPLACE FUNCTION public.save_my_profile_bundle(
  p_profile_fields jsonb DEFAULT '{}'::jsonb,
  p_preference_fields jsonb DEFAULT '{}'::jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_user_id uuid := private.assert_authenticated();
  v_profile jsonb;
  v_profile_id uuid;
  v_key text;
  v_assignments text;
  v_pref_allowed constant text[] := ARRAY[
    'preferred_age_min', 'preferred_age_max', 'location_preference',
    'diaspora_mode', 'sect_preference', 'deen_preference',
    'min_education_rank', 'open_to_divorced', 'open_to_widowed',
    'open_to_has_children', 'open_to_diaspora',
    'preferred_living_expectation', 'preferred_country_codes',
    'preferred_city_ids', 'max_distance_km'
  ];
BEGIN
  v_profile := public.patch_my_profile(coalesce(p_profile_fields, '{}'::jsonb));
  SELECT id INTO v_profile_id
  FROM public.profiles
  WHERE user_id = v_user_id
  FOR UPDATE;

  PERFORM private.assert_jsonb_keys(
    coalesce(p_preference_fields, '{}'::jsonb),
    v_pref_allowed
  );

  IF p_preference_fields <> '{}'::jsonb THEN
    INSERT INTO public.profile_preferences(profile_id)
    VALUES (v_profile_id)
    ON CONFLICT (profile_id) DO NOTHING;

    SELECT string_agg(
      format(
        '%1$I = (jsonb_populate_record(NULL::public.profile_preferences, $1)).%1$I',
        v_key
      ),
      ', '
    )
    INTO v_assignments
    FROM jsonb_object_keys(p_preference_fields) AS keys(v_key);

    EXECUTE format(
      'UPDATE public.profile_preferences SET %s WHERE profile_id = $2',
      v_assignments
    )
    USING p_preference_fields, v_profile_id;
  END IF;

  RETURN v_profile;
END;
$$;

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
BEGIN
  IF p_enabled AND (
    nullif(trim(p_name), '') IS NULL
    OR p_relationship NOT IN ('father','mother','brother','sister','uncle','aunt','other')
  ) THEN
    RAISE EXCEPTION 'invalid_guardian_details' USING ERRCODE = 'P0001';
  END IF;

  UPDATE public.profiles
  SET guardian_name = CASE WHEN p_enabled THEN trim(p_name) ELSE NULL END,
      guardian_relationship = CASE WHEN p_enabled THEN p_relationship ELSE NULL END,
      guardian_mode = CASE
        WHEN NOT p_enabled THEN 'none'
        WHEN p_can_reply THEN 'active'
        ELSE 'passive'
      END,
      guardian_phone_country_code =
        CASE WHEN p_enabled THEN nullif(trim(p_phone_country_code), '') ELSE NULL END,
      guardian_email =
        CASE WHEN p_enabled THEN nullif(lower(trim(p_email)), '') ELSE NULL END,
      guardian_authority_scope =
        CASE WHEN p_enabled THEN coalesce(nullif(trim(p_authority_scope), ''), 'full') ELSE NULL END,
      -- A member cannot appoint a guardian account. That requires a separate
      -- invitation/acceptance flow.
      guardian_user_id = CASE WHEN p_enabled THEN guardian_user_id ELSE NULL END
  WHERE user_id = v_user_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.set_my_photo_privacy(p_privacy text)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_user_id uuid := private.assert_authenticated();
BEGIN
  IF p_privacy NOT IN ('public', 'mutual_only', 'request_only') THEN
    RAISE EXCEPTION 'invalid_photo_privacy' USING ERRCODE = 'P0001';
  END IF;
  UPDATE public.profiles SET photo_privacy = p_privacy WHERE user_id = v_user_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'profile_not_found' USING ERRCODE = 'P0001'; END IF;
  RETURN p_privacy;
END;
$$;

CREATE OR REPLACE FUNCTION public.set_my_onboarding_step_for_back(p_step integer)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_user_id uuid := private.assert_authenticated();
BEGIN
  IF p_step < 0 OR p_step > 20 THEN
    RAISE EXCEPTION 'invalid_onboarding_step' USING ERRCODE = 'P0001';
  END IF;
  UPDATE public.profiles SET onboarding_step = p_step WHERE user_id = v_user_id;
  UPDATE public.users SET onboarding_step = p_step WHERE id = v_user_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.submit_user_report(
  p_reported_user_id uuid,
  p_reason text,
  p_description text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_reporter uuid := private.assert_authenticated();
  v_id uuid;
BEGIN
  IF p_reported_user_id = v_reporter THEN
    RAISE EXCEPTION 'cannot_report_self' USING ERRCODE = 'P0001';
  END IF;
  IF p_reason NOT IN (
    'fake_profile','inappropriate_photos','harassment','scam','underage',
    'already_married','offensive_bio','other'
  ) THEN
    RAISE EXCEPTION 'invalid_report_reason' USING ERRCODE = 'P0001';
  END IF;
  IF char_length(coalesce(p_description, '')) > 1000 THEN
    RAISE EXCEPTION 'report_description_too_long' USING ERRCODE = 'P0001';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.users
    WHERE id = p_reported_user_id AND deleted_at IS NULL
  ) THEN
    RAISE EXCEPTION 'reported_user_unavailable' USING ERRCODE = 'P0001';
  END IF;

  PERFORM pg_advisory_xact_lock(hashtextextended(v_reporter::text, 71));
  IF (
    SELECT count(*) FROM public.reports
    WHERE reporter_id = v_reporter
      AND created_at >= now() - interval '24 hours'
  ) >= 20 THEN
    RAISE EXCEPTION 'report_rate_limit' USING ERRCODE = 'P0001';
  END IF;

  INSERT INTO public.reports(
    reporter_id, reported_user_id, reason, description, status, created_at,
    reporter_trust_score
  )
  VALUES (
    v_reporter, p_reported_user_id, p_reason,
    nullif(trim(p_description), ''), 'pending', now(),
    public.compute_reporter_trust_score(v_reporter)
  )
  ON CONFLICT (reporter_id, reported_user_id)
    WHERE status = 'pending'
  DO UPDATE SET
    reason = EXCLUDED.reason,
    description = EXCLUDED.description
  RETURNING id INTO v_id;

  INSERT INTO public.admin_notifications(type, message, related_user_id)
  VALUES (
    'member_report_received',
    'A member report requires moderation review.',
    p_reported_user_id
  );
  RETURN v_id;
END;
$$;

-- Reports may prioritize a queue, but never autonomously change account state.
CREATE OR REPLACE FUNCTION public.check_report_threshold()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_reporter_count integer;
BEGIN
  NEW.reporter_trust_score :=
    public.compute_reporter_trust_score(NEW.reporter_id);
  SELECT count(DISTINCT reporter_id) INTO v_reporter_count
  FROM public.reports
  WHERE reported_user_id = NEW.reported_user_id
    AND status = 'pending';
  IF v_reporter_count >= 3 THEN
    INSERT INTO public.admin_notifications(type, message, related_user_id)
    VALUES (
      'review_required',
      format('%s distinct members reported this account. Manual review is required.', v_reporter_count),
      NEW.reported_user_id
    );
  END IF;
  RETURN NEW;
END;
$$;

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
  IF EXISTS (
    SELECT 1 FROM public.blocks
    WHERE (blocker_id = v_sender AND blocked_id = p_receiver_id)
       OR (blocker_id = p_receiver_id AND blocked_id = v_sender)
  ) THEN
    RAISE EXCEPTION 'profile_unavailable' USING ERRCODE = 'P0001';
  END IF;

  PERFORM pg_advisory_xact_lock(hashtextextended(v_sender::text, 72));
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

CREATE OR REPLACE FUNCTION public.respond_to_interest(
  p_interest_id uuid,
  p_decision text
)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_receiver uuid := private.assert_authenticated();
  v_status text;
BEGIN
  IF p_decision NOT IN ('accepted', 'declined') THEN
    RAISE EXCEPTION 'invalid_interest_decision' USING ERRCODE = 'P0001';
  END IF;
  UPDATE public.interests
  SET status = p_decision
  WHERE id = p_interest_id
    AND receiver_id = v_receiver
    AND status = 'pending'
    AND expires_at > now()
  RETURNING status INTO v_status;
  IF v_status IS NULL THEN
    RAISE EXCEPTION 'interest_unavailable' USING ERRCODE = 'P0001';
  END IF;
  RETURN v_status;
END;
$$;

CREATE OR REPLACE FUNCTION public.withdraw_interest(p_interest_id uuid)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_sender uuid := private.assert_authenticated();
  v_status text;
BEGIN
  UPDATE public.interests
  SET status = 'withdrawn'
  WHERE id = p_interest_id
    AND sender_id = v_sender
    AND status = 'pending'
  RETURNING status INTO v_status;
  IF v_status IS NULL THEN
    RAISE EXCEPTION 'interest_unavailable' USING ERRCODE = 'P0001';
  END IF;
  RETURN v_status;
END;
$$;

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
  SELECT * INTO v_match FROM public.matches WHERE id = p_match_id FOR UPDATE;
  IF NOT FOUND OR coalesce(v_match.status, 'active') <> 'active' THEN
    RAISE EXCEPTION 'chat_unavailable' USING ERRCODE = 'P0001';
  END IF;
  SELECT ward_id INTO v_ward
  FROM public.guardian_chat_mirrors
  WHERE match_id = p_match_id
    AND guardian_id = v_guardian
    AND mode = 'active'
  FOR UPDATE;
  IF v_ward IS NULL OR v_ward NOT IN (v_match.user_a, v_match.user_b) THEN
    RAISE EXCEPTION 'guardian_not_authorized' USING ERRCODE = 'P0001';
  END IF;
  v_receiver := CASE WHEN v_match.user_a = v_ward THEN v_match.user_b ELSE v_match.user_a END;
  INSERT INTO public.messages(
    match_id, sender_id, receiver_id, content, sent_by_guardian
  )
  VALUES (p_match_id, v_ward, v_receiver, p_content, true)
  RETURNING id INTO v_message_id;
  RETURN v_message_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.store_message_translation(
  p_message_id uuid,
  p_target_lang text,
  p_translation text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_user_id uuid := private.assert_authenticated();
  v_translations jsonb;
BEGIN
  IF p_target_lang !~ '^[a-z]{2,3}(-[A-Z]{2})?$'
    OR char_length(p_translation) NOT BETWEEN 1 AND 4000 THEN
    RAISE EXCEPTION 'invalid_translation' USING ERRCODE = 'P0001';
  END IF;
  UPDATE public.messages
  SET translations = jsonb_set(
    coalesce(translations, '{}'::jsonb),
    ARRAY[p_target_lang],
    to_jsonb(p_translation),
    true
  )
  WHERE id = p_message_id
    AND (sender_id = v_user_id OR receiver_id = v_user_id)
  RETURNING translations INTO v_translations;
  IF v_translations IS NULL THEN
    RAISE EXCEPTION 'message_unavailable' USING ERRCODE = 'P0001';
  END IF;
  RETURN v_translations;
END;
$$;

CREATE OR REPLACE FUNCTION public.mark_notification_read(p_notification_id uuid)
RETURNS void
LANGUAGE sql
SECURITY DEFINER
SET search_path = ''
AS $$
  UPDATE public.notifications
  SET read_at = coalesce(read_at, now())
  WHERE id = p_notification_id AND user_id = auth.uid();
$$;

CREATE OR REPLACE FUNCTION public.mark_all_notifications_read()
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE v_count integer;
BEGIN
  PERFORM private.assert_authenticated();
  UPDATE public.notifications SET read_at = now()
  WHERE user_id = auth.uid() AND read_at IS NULL;
  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count;
END;
$$;

CREATE OR REPLACE FUNCTION public.delete_my_notification(p_notification_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  PERFORM private.assert_authenticated();
  DELETE FROM public.notifications
  WHERE id = p_notification_id AND user_id = auth.uid();
  RETURN FOUND;
END;
$$;

CREATE OR REPLACE FUNCTION public.clear_my_notifications()
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE v_count integer;
BEGIN
  PERFORM private.assert_authenticated();
  DELETE FROM public.notifications WHERE user_id = auth.uid();
  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count;
END;
$$;

CREATE UNIQUE INDEX IF NOT EXISTS user_fcm_tokens_token_unique
  ON public.user_fcm_tokens(fcm_token);

CREATE OR REPLACE FUNCTION public.register_my_fcm_token(
  p_device_id text,
  p_fcm_token text,
  p_platform text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_user_id uuid := private.assert_authenticated();
BEGIN
  IF char_length(p_device_id) NOT BETWEEN 16 AND 160
    OR char_length(p_fcm_token) NOT BETWEEN 32 AND 4096
    OR p_platform NOT IN ('android', 'ios') THEN
    RAISE EXCEPTION 'invalid_device_token' USING ERRCODE = 'P0001';
  END IF;
  PERFORM pg_advisory_xact_lock(hashtextextended(v_user_id::text, 73));
  DELETE FROM public.user_fcm_tokens
  WHERE user_id = v_user_id
    AND device_id <> p_device_id
    AND updated_at < now() - interval '90 days';
  IF (
    SELECT count(*) FROM public.user_fcm_tokens
    WHERE user_id = v_user_id AND device_id <> p_device_id
  ) >= 5 THEN
    RAISE EXCEPTION 'device_limit_reached' USING ERRCODE = 'P0001';
  END IF;
  DELETE FROM public.user_fcm_tokens
  WHERE fcm_token = p_fcm_token AND user_id <> v_user_id;
  INSERT INTO public.user_fcm_tokens(
    user_id, device_id, fcm_token, platform, updated_at
  )
  VALUES (v_user_id, p_device_id, p_fcm_token, p_platform, now())
  ON CONFLICT (user_id, device_id) DO UPDATE SET
    fcm_token = EXCLUDED.fcm_token,
    platform = EXCLUDED.platform,
    updated_at = now();
END;
$$;

CREATE OR REPLACE FUNCTION public.unregister_my_fcm_token(p_device_id text)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  PERFORM private.assert_authenticated();
  DELETE FROM public.user_fcm_tokens
  WHERE user_id = auth.uid() AND device_id = p_device_id;
  RETURN FOUND;
END;
$$;

CREATE OR REPLACE FUNCTION public.request_my_account_deletion(p_reason text DEFAULT NULL)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_user_id uuid := private.assert_authenticated();
BEGIN
  UPDATE public.users
  SET deletion_status = 'pending_deletion',
      deletion_reason = left(nullif(trim(p_reason), ''), 500),
      deletion_requested_at = now(),
      deleted_at = now()
  WHERE id = v_user_id AND deletion_status = 'active';
END;
$$;

CREATE OR REPLACE FUNCTION public.confirm_my_verified_phone()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_user_id uuid := private.assert_authenticated();
  v_phone text;
BEGIN
  SELECT phone INTO v_phone FROM auth.users WHERE id = v_user_id;
  IF nullif(v_phone, '') IS NULL THEN
    RAISE EXCEPTION 'phone_not_verified' USING ERRCODE = 'P0001';
  END IF;
  UPDATE public.users
  SET phone = v_phone, phone_verified_at = now()
  WHERE id = v_user_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.submit_my_photo_badge_verification()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_user_id uuid := private.assert_authenticated();
BEGIN
  -- This is a photo/liveness badge, never government identity/KYC.
  UPDATE public.profiles
  SET has_verification_badge = true,
      badge_earned_at = now(),
      badge_pose_sequence = ARRAY[]::text[],
      verification_status = 'verified',
      verification_challenge = 'passive_face_scan',
      verified_at = now(),
      is_verified = true
  WHERE user_id = v_user_id;
END;
$$;

-- Existing safe RPCs are the only member write surface for these tables.
REVOKE INSERT, UPDATE, DELETE ON public.users FROM anon, authenticated;
REVOKE INSERT, UPDATE, DELETE ON public.profiles FROM anon, authenticated;
REVOKE INSERT, UPDATE, DELETE ON public.profile_preferences FROM anon, authenticated;
REVOKE INSERT, UPDATE, DELETE ON public.photos FROM anon, authenticated;
REVOKE INSERT, UPDATE, DELETE ON public.photo_access_requests FROM anon, authenticated;
REVOKE INSERT, UPDATE, DELETE ON public.interests FROM anon, authenticated;
REVOKE INSERT, UPDATE, DELETE ON public.messages FROM anon, authenticated;
REVOKE INSERT, UPDATE, DELETE ON public.reports FROM anon, authenticated;
REVOKE INSERT, UPDATE, DELETE ON public.message_reports FROM anon, authenticated;
REVOKE INSERT, UPDATE, DELETE ON public.user_fcm_tokens FROM anon, authenticated;
REVOKE INSERT, UPDATE, DELETE ON public.user_consents FROM anon, authenticated;
REVOKE INSERT, UPDATE, DELETE ON public.profile_views FROM anon, authenticated;
REVOKE UPDATE, DELETE ON public.notifications FROM anon, authenticated;
REVOKE INSERT, UPDATE, DELETE ON public.admin_memberships FROM anon, authenticated;

-- Remove permissive policies so a future broad table GRANT cannot resurrect
-- these paths.
DROP POLICY IF EXISTS users_update_own ON public.users;
DROP POLICY IF EXISTS profiles_insert ON public.profiles;
DROP POLICY IF EXISTS profiles_update ON public.profiles;
DROP POLICY IF EXISTS profiles_delete ON public.profiles;
DROP POLICY IF EXISTS photos_insert ON public.photos;
DROP POLICY IF EXISTS photos_update ON public.photos;
DROP POLICY IF EXISTS photos_delete ON public.photos;
DROP POLICY IF EXISTS par_requester_insert ON public.photo_access_requests;
DROP POLICY IF EXISTS par_owner_update ON public.photo_access_requests;
DROP POLICY IF EXISTS interests_insert ON public.interests;
DROP POLICY IF EXISTS interests_update ON public.interests;
DROP POLICY IF EXISTS messages_insert ON public.messages;
DROP POLICY IF EXISTS messages_participant_or_guardian_insert ON public.messages;
DROP POLICY IF EXISTS messages_update ON public.messages;
DROP POLICY IF EXISTS reports_insert ON public.reports;
DROP POLICY IF EXISTS message_reports_insert ON public.message_reports;
DROP POLICY IF EXISTS fcm_tokens_insert ON public.user_fcm_tokens;
DROP POLICY IF EXISTS fcm_tokens_update ON public.user_fcm_tokens;
DROP POLICY IF EXISTS fcm_tokens_delete ON public.user_fcm_tokens;
DROP POLICY IF EXISTS consents_insert ON public.user_consents;
DROP POLICY IF EXISTS user_consents_insert ON public.user_consents;
DROP POLICY IF EXISTS profile_views_insert ON public.profile_views;
DROP POLICY IF EXISTS notifs_update ON public.notifications;
DROP POLICY IF EXISTS notifs_delete ON public.notifications;
DROP POLICY IF EXISTS admin_memberships_super_admin_insert ON public.admin_memberships;
DROP POLICY IF EXISTS admin_memberships_super_admin_update ON public.admin_memberships;
DROP POLICY IF EXISTS admin_memberships_super_admin_delete ON public.admin_memberships;

REVOKE ALL ON FUNCTION public.sync_my_user(text, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.patch_my_user(jsonb) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.patch_my_profile(jsonb) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.save_my_profile_bundle(jsonb, jsonb) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.set_my_guardian_settings(boolean, boolean, text, text, text, text, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.set_my_photo_privacy(text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.set_my_onboarding_step_for_back(integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.submit_user_report(uuid, text, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.send_interest(uuid, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.respond_to_interest(uuid, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.withdraw_interest(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.send_guardian_chat_message(uuid, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.store_message_translation(uuid, text, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.mark_notification_read(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.mark_all_notifications_read() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.delete_my_notification(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.clear_my_notifications() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.register_my_fcm_token(text, text, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.unregister_my_fcm_token(text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.request_my_account_deletion(text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.confirm_my_verified_phone() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.submit_my_photo_badge_verification() FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.sync_my_user(text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.patch_my_user(jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public.patch_my_profile(jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public.save_my_profile_bundle(jsonb, jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public.set_my_guardian_settings(boolean, boolean, text, text, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.set_my_photo_privacy(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.set_my_onboarding_step_for_back(integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.submit_user_report(uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.send_interest(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.respond_to_interest(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.withdraw_interest(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.send_guardian_chat_message(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.store_message_translation(uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_notification_read(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_all_notifications_read() TO authenticated;
GRANT EXECUTE ON FUNCTION public.delete_my_notification(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.clear_my_notifications() TO authenticated;
GRANT EXECUTE ON FUNCTION public.register_my_fcm_token(text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.unregister_my_fcm_token(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.request_my_account_deletion(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.confirm_my_verified_phone() TO authenticated;
GRANT EXECUTE ON FUNCTION public.submit_my_photo_badge_verification() TO authenticated;
