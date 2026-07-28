-- Resolve PL/pgSQL output-column ambiguities detected by plpgsql_check and
-- align token-delivery storage with its durable delivery RPC.

ALTER TABLE private.notification_deliveries
  ADD COLUMN IF NOT EXISTS delivered_at timestamptz;

CREATE OR REPLACE FUNCTION public.patch_my_user(p_fields jsonb)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_user_id uuid := private.assert_authenticated();
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
      keys.key_name
    ),
    ', '
  )
  INTO v_assignments
  FROM jsonb_object_keys(p_fields) AS keys(key_name);

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
      keys.key_name
    ),
    ', '
  )
  INTO v_assignments
  FROM jsonb_object_keys(p_fields) AS keys(key_name);

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
  v_profile := public.patch_my_profile(
    coalesce(p_profile_fields, '{}'::jsonb)
  );
  SELECT id INTO v_profile_id
  FROM public.profiles
  WHERE user_id = v_user_id
  FOR UPDATE;

  PERFORM private.assert_jsonb_keys(
    coalesce(p_preference_fields, '{}'::jsonb),
    v_pref_allowed
  );

  IF coalesce(p_preference_fields, '{}'::jsonb) <> '{}'::jsonb THEN
    INSERT INTO public.profile_preferences(profile_id)
    VALUES (v_profile_id)
    ON CONFLICT (profile_id) DO NOTHING;

    SELECT string_agg(
      format(
        '%1$I = (jsonb_populate_record(NULL::public.profile_preferences, $1)).%1$I',
        keys.key_name
      ),
      ', '
    )
    INTO v_assignments
    FROM jsonb_object_keys(p_preference_fields) AS keys(key_name);

    EXECUTE format(
      'UPDATE public.profile_preferences SET %s WHERE profile_id = $2',
      v_assignments
    )
    USING p_preference_fields, v_profile_id;
  END IF;

  RETURN v_profile;
END;
$$;

CREATE OR REPLACE FUNCTION public.record_notification_token_delivery(
  p_notification_id uuid,
  p_lease_token uuid,
  p_fcm_token text,
  p_status text,
  p_error_code text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  IF auth.role() <> 'service_role'
    OR p_status NOT IN ('sent','invalid_token','retry','failed') THEN
    RAISE EXCEPTION 'invalid_token_delivery' USING ERRCODE = 'P0001';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.notifications
    WHERE id = p_notification_id
      AND lease_token = p_lease_token
      AND delivery_status = 'processing'
  ) THEN
    RETURN;
  END IF;

  INSERT INTO private.notification_deliveries(
    notification_id, token_hash, status, attempt_count, last_error_code,
    delivered_at, updated_at
  )
  VALUES (
    p_notification_id,
    encode(extensions.digest(p_fcm_token, 'sha256'), 'hex'),
    p_status,
    1,
    left(p_error_code, 80),
    CASE WHEN p_status = 'sent' THEN now() ELSE NULL END,
    now()
  )
  ON CONFLICT (notification_id, token_hash) DO UPDATE
  SET status = EXCLUDED.status,
      attempt_count = private.notification_deliveries.attempt_count + 1,
      last_error_code = EXCLUDED.last_error_code,
      delivered_at = coalesce(
        private.notification_deliveries.delivered_at,
        EXCLUDED.delivered_at
      ),
      updated_at = now();
END;
$$;

CREATE OR REPLACE FUNCTION public.checkout_account_purge_jobs(
  p_limit integer DEFAULT 10
)
RETURNS TABLE(user_id uuid, phase text, lease_token uuid)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  IF auth.role() <> 'service_role' THEN
    RAISE EXCEPTION 'service_role_required' USING ERRCODE = 'P0001';
  END IF;

  INSERT INTO private.account_purge_jobs(user_id)
  SELECT u.id
  FROM public.users u
  WHERE u.deletion_status = 'pending_deletion'
    AND u.deleted_at < now() - interval '30 days'
  ON CONFLICT ON CONSTRAINT account_purge_jobs_pkey DO NOTHING;

  RETURN QUERY
  WITH candidates AS (
    SELECT j.user_id
    FROM private.account_purge_jobs j
    WHERE (
      j.status IN ('pending','failed') AND j.next_attempt_at <= now()
    ) OR (
      j.status = 'processing'
      AND j.processing_at < now() - interval '10 minutes'
    )
    ORDER BY j.created_at
    LIMIT least(greatest(p_limit, 1), 25)
    FOR UPDATE SKIP LOCKED
  ), leased AS (
    UPDATE private.account_purge_jobs j
    SET status = 'processing',
        processing_at = now(),
        lease_token = gen_random_uuid(),
        attempt_count = j.attempt_count + 1
    FROM candidates c
    WHERE j.user_id = c.user_id
    RETURNING j.user_id, j.phase, j.lease_token
  )
  SELECT l.user_id, l.phase, l.lease_token FROM leased l;
END;
$$;

CREATE OR REPLACE FUNCTION public.finalize_profile_photo_upload(
  p_user_id uuid,
  p_storage_path text,
  p_observed_mime text,
  p_observed_bytes integer,
  p_blurhash text,
  p_client_nsfw_score numeric DEFAULT 0
)
RETURNS TABLE(photo_id uuid, action text)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_reservation private.upload_reservations%ROWTYPE;
  v_photo_id uuid;
  v_score numeric := least(
    greatest(coalesce(p_client_nsfw_score, 0), 0),
    1
  );
BEGIN
  IF auth.role() <> 'service_role' THEN
    RAISE EXCEPTION 'service_role_required' USING ERRCODE = 'P0001';
  END IF;

  SELECT ph.id INTO v_photo_id
  FROM public.photos ph
  JOIN public.profiles pr ON pr.id = ph.profile_id
  WHERE ph.storage_path = p_storage_path
    AND pr.user_id = p_user_id;
  IF v_photo_id IS NOT NULL THEN
    INSERT INTO public.photo_moderation_queue(
      photo_id, user_id, confidence, category, status
    )
    SELECT
      ph.id, p_user_id, coalesce(ph.nsfw_score, 0),
      'unreviewed_upload', 'pending_review'
    FROM public.photos ph
    WHERE ph.id = v_photo_id
      AND ph.status = 'pending_review'
    ON CONFLICT ON CONSTRAINT photo_moderation_queue_photo_id_key DO NOTHING;
    RETURN QUERY SELECT v_photo_id, 'pending_review'::text;
    RETURN;
  END IF;

  SELECT * INTO v_reservation
  FROM private.upload_reservations r
  WHERE r.user_id = p_user_id
    AND r.storage_path = p_storage_path
    AND r.purpose = 'profile_photo'
    AND r.status = 'reserved'
  FOR UPDATE;

  IF NOT FOUND
    OR v_reservation.expires_at <= now()
    OR v_reservation.expected_mime <> p_observed_mime
    OR p_observed_bytes < 32
    OR p_observed_bytes > v_reservation.max_bytes
    OR nullif(trim(coalesce(p_blurhash, '')), '') IS NULL THEN
    RAISE EXCEPTION 'upload_reservation_invalid_or_expired'
      USING ERRCODE = 'P0001';
  END IF;

  INSERT INTO public.photos(
    profile_id, storage_path, status, order_index, admin_approved,
    nsfw_cleared, nsfw_score, nsfw_category, nsfw_scanned_at,
    moderation_source, moderation_status, blurhash
  )
  VALUES (
    v_reservation.profile_id, v_reservation.storage_path, 'pending_review',
    v_reservation.order_index, false, false, v_score, 'unreviewed_upload',
    now(), 'client_signal_untrusted', 'pending', p_blurhash
  )
  RETURNING id INTO v_photo_id;

  INSERT INTO public.photo_moderation_queue(
    photo_id, user_id, confidence, category, status
  )
  VALUES (
    v_photo_id, p_user_id, v_score, 'unreviewed_upload', 'pending_review'
  );

  UPDATE private.upload_reservations
  SET status = 'consumed', consumed_at = now()
  WHERE id = v_reservation.id;

  RETURN QUERY SELECT v_photo_id, 'pending_review'::text;
END;
$$;

REVOKE ALL ON FUNCTION public.patch_my_user(jsonb) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.patch_my_profile(jsonb) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.save_my_profile_bundle(jsonb, jsonb) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.record_notification_token_delivery(
  uuid, uuid, text, text, text
) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.checkout_account_purge_jobs(integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.finalize_profile_photo_upload(
  uuid, text, text, integer, text, numeric
) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.patch_my_user(jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public.patch_my_profile(jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public.save_my_profile_bundle(
  jsonb, jsonb
) TO authenticated;
GRANT EXECUTE ON FUNCTION public.record_notification_token_delivery(
  uuid, uuid, text, text, text
) TO service_role;
GRANT EXECUTE ON FUNCTION public.checkout_account_purge_jobs(
  integer
) TO service_role;
GRANT EXECUTE ON FUNCTION public.finalize_profile_photo_upload(
  uuid, text, text, integer, text, numeric
) TO service_role;
