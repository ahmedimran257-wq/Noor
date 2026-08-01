-- Safe profile photos publish immediately after the on-device and server
-- integrity checks. Every upload still enters the staff moderation queue so a
-- moderator can remove it later. Only explicit-content flags remain withheld
-- while they await a decision.

DROP TRIGGER IF EXISTS trg_enforce_marriage_timeline ON public.profiles;

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
  v_existing public.photos%ROWTYPE;
  v_replaced public.photos%ROWTYPE;
  v_photo_id uuid;
  v_score numeric := least(
    greatest(coalesce(p_client_nsfw_score, 0), 0),
    1
  );
  v_flagged boolean;
  v_became_live_user uuid;
BEGIN
  IF auth.role() <> 'service_role' THEN
    RAISE EXCEPTION 'service_role_required' USING ERRCODE = 'P0001';
  END IF;

  v_flagged := v_score > 0.85;

  SELECT ph.* INTO v_existing
  FROM public.photos ph
  JOIN public.profiles pr ON pr.id = ph.profile_id
  WHERE ph.storage_path = p_storage_path
    AND pr.user_id = p_user_id;

  IF v_existing.id IS NOT NULL THEN
    INSERT INTO public.photo_moderation_queue(
      photo_id, user_id, confidence, category, status
    )
    VALUES (
      v_existing.id,
      p_user_id,
      coalesce(v_existing.nsfw_score, v_score),
      CASE
        WHEN coalesce(v_existing.nsfw_score, v_score) > 0.85
          THEN 'explicit_content'
        ELSE 'unreviewed_upload'
      END,
      'pending_review'
    )
    ON CONFLICT (photo_id) DO NOTHING;

    RETURN QUERY SELECT
      v_existing.id,
      CASE
        WHEN v_existing.status = 'active' THEN 'active'::text
        ELSE 'pending_review'::text
      END;
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

  -- A safe replacement becomes authoritative immediately. Explicit-content
  -- flags leave the existing published slot intact until a moderator approves.
  IF NOT v_flagged AND v_reservation.replaced_photo_id IS NOT NULL THEN
    SELECT * INTO v_replaced
    FROM public.photos
    WHERE id = v_reservation.replaced_photo_id
      AND profile_id = v_reservation.profile_id
    FOR UPDATE;

    IF v_replaced.id IS NOT NULL AND v_replaced.status = 'active' THEN
      UPDATE public.photos
      SET status = 'deletion_pending'
      WHERE id = v_replaced.id;

      UPDATE public.photo_moderation_queue
      SET status = 'rejected',
          reviewed_at = now(),
          review_reason = 'Superseded by a newer member upload.'
      WHERE photo_id = v_replaced.id
        AND status = 'pending_review';

      INSERT INTO private.storage_deletion_jobs(
        bucket_id, storage_path, photo_id, user_id, reason
      )
      VALUES (
        'profile-photos',
        v_replaced.storage_path,
        v_replaced.id,
        p_user_id,
        'published_replacement'
      )
      ON CONFLICT (bucket_id, storage_path) DO NOTHING;
    END IF;
  END IF;

  INSERT INTO public.photos(
    profile_id, storage_path, status, order_index, admin_approved,
    nsfw_cleared, nsfw_score, nsfw_category, nsfw_scanned_at,
    moderation_source, moderation_status, blurhash
  )
  VALUES (
    v_reservation.profile_id,
    v_reservation.storage_path,
    CASE WHEN v_flagged THEN 'pending_review' ELSE 'active' END,
    v_reservation.order_index,
    NOT v_flagged,
    NOT v_flagged,
    v_score,
    CASE WHEN v_flagged THEN 'explicit_content' ELSE 'unreviewed_upload' END,
    now(),
    'on_device_scan',
    'pending',
    p_blurhash
  )
  RETURNING id INTO v_photo_id;

  INSERT INTO public.photo_moderation_queue(
    photo_id, user_id, confidence, category, status
  )
  VALUES (
    v_photo_id,
    p_user_id,
    v_score,
    CASE WHEN v_flagged THEN 'explicit_content' ELSE 'unreviewed_upload' END,
    'pending_review'
  );

  UPDATE private.upload_reservations
  SET status = 'consumed', consumed_at = now()
  WHERE id = v_reservation.id;

  -- This covers members who completed onboarding without a usable primary
  -- photo and later add one from Manage Photos. The normal onboarding route is
  -- completed atomically by complete_onboarding_profile() below.
  IF NOT v_flagged
    AND v_reservation.order_index = 0
    AND v_reservation.replaced_photo_id IS NULL THEN
    UPDATE public.profiles
    SET approved_at = coalesce(approved_at, now()),
        visibility = CASE
          WHEN visibility IN ('suspended', 'deactivated') THEN visibility
          ELSE 'visible'
        END,
        updated_at = now()
    WHERE id = v_reservation.profile_id
      AND onboarding_completed = true
      AND visibility NOT IN ('visible', 'suspended', 'deactivated')
    RETURNING user_id INTO v_became_live_user;

    IF v_became_live_user IS NOT NULL THEN
      PERFORM public.queue_notification(
        v_became_live_user,
        'profile_live',
        'Your profile is now live!',
        'Muslims in your area can now find you on Silarah.',
        'silarah://profile'
      );
    END IF;
  END IF;

  RETURN QUERY SELECT
    v_photo_id,
    CASE WHEN v_flagged THEN 'pending_review'::text ELSE 'active'::text END;
END;
$$;

REVOKE ALL ON FUNCTION public.finalize_profile_photo_upload(
  uuid, text, text, integer, text, numeric
) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.finalize_profile_photo_upload(
  uuid, text, text, integer, text, numeric
) TO service_role;

CREATE OR REPLACE FUNCTION public.complete_onboarding_profile()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_profile public.profiles%ROWTYPE;
  v_has_primary boolean;
  v_became_live boolean;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'authentication_required' USING ERRCODE = '42501';
  END IF;

  SELECT * INTO v_profile
  FROM public.profiles
  WHERE user_id = v_user_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'profile_row_missing' USING ERRCODE = '23503';
  END IF;

  SELECT EXISTS (
    SELECT 1
    FROM public.photos ph
    WHERE ph.profile_id = v_profile.id
      AND ph.order_index = 0
      AND ph.status = 'active'
      AND ph.admin_approved = true
      AND ph.nsfw_cleared = true
  ) INTO v_has_primary;

  v_became_live :=
    v_has_primary
    AND v_profile.visibility IS DISTINCT FROM 'visible'
    AND v_profile.visibility NOT IN ('suspended', 'deactivated');

  UPDATE public.profiles
  SET onboarding_completed = true,
      onboarding_flow_version = 3,
      onboarding_step = greatest(coalesce(onboarding_step, 0), 5),
      approved_at = CASE
        WHEN v_has_primary THEN coalesce(approved_at, now())
        ELSE approved_at
      END,
      visibility = CASE
        WHEN visibility IN ('suspended', 'deactivated') THEN visibility
        WHEN v_has_primary THEN 'visible'
        ELSE 'paused'
      END,
      updated_at = now()
  WHERE id = v_profile.id;

  UPDATE public.users
  SET onboarding_completed = true,
      onboarding_step = greatest(coalesce(onboarding_step, 0), 5)
  WHERE id = v_user_id;

  IF v_became_live THEN
    PERFORM public.queue_notification(
      v_user_id,
      'profile_live',
      'Your profile is now live!',
      'Muslims in your area can now find you on Silarah.',
      'silarah://profile'
    );
  END IF;
END;
$$;

REVOKE ALL ON FUNCTION public.complete_onboarding_profile()
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.complete_onboarding_profile()
  TO authenticated;

CREATE OR REPLACE FUNCTION public.set_profile_pause(p_paused boolean)
RETURNS TABLE (
  is_paused boolean,
  visibility text,
  message text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_profile public.profiles%ROWTYPE;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'authentication_required' USING ERRCODE = '42501';
  END IF;

  SELECT * INTO v_profile
  FROM public.profiles
  WHERE user_id = auth.uid()
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Complete your profile before changing visibility.';
  END IF;
  IF v_profile.visibility IN ('suspended', 'deactivated') THEN
    RAISE EXCEPTION 'This profile cannot be made visible from settings.';
  END IF;

  IF coalesce(p_paused, false) THEN
    UPDATE public.profiles
    SET visibility = 'paused', updated_at = now()
    WHERE id = v_profile.id;
    RETURN QUERY
      SELECT true, 'paused'::text, 'Your profile is hidden.'::text;
    RETURN;
  END IF;

  IF coalesce(v_profile.onboarding_completed, false) IS DISTINCT FROM true THEN
    RAISE EXCEPTION 'Complete onboarding before making your profile visible.';
  END IF;
  IF NOT EXISTS (
    SELECT 1
    FROM public.photos ph
    WHERE ph.profile_id = v_profile.id
      AND ph.order_index = 0
      AND ph.status = 'active'
      AND ph.admin_approved = true
      AND ph.nsfw_cleared = true
  ) THEN
    RAISE EXCEPTION
      'Add a primary photo that passes the safety scan before making your profile visible.';
  END IF;

  UPDATE public.profiles
  SET visibility = 'visible',
      approved_at = coalesce(approved_at, now()),
      updated_at = now()
  WHERE id = v_profile.id;
  RETURN QUERY
    SELECT false, 'visible'::text, 'Your profile is visible.'::text;
END;
$$;

REVOKE ALL ON FUNCTION public.set_profile_pause(boolean)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.set_profile_pause(boolean)
  TO authenticated;

CREATE OR REPLACE FUNCTION public.admin_review_photo(
  p_photo_id uuid,
  p_decision text,
  p_reason text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_photo public.photos%ROWTYPE;
  v_target uuid;
  v_old public.photos%ROWTYPE;
  v_was_published boolean;
  v_profile_became_live boolean := false;
BEGIN
  IF NOT public.is_active_admin(ARRAY['super_admin', 'moderator']) THEN
    RAISE EXCEPTION 'aal2_staff_required' USING ERRCODE = 'P0001';
  END IF;
  IF p_decision NOT IN ('approve', 'reject') THEN
    RAISE EXCEPTION 'invalid_photo_decision' USING ERRCODE = 'P0001';
  END IF;

  SELECT ph.* INTO v_photo
  FROM public.photos ph
  JOIN public.photo_moderation_queue q ON q.photo_id = ph.id
  WHERE ph.id = p_photo_id
    AND q.status = 'pending_review'
  FOR UPDATE OF ph;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'photo_not_pending_review' USING ERRCODE = 'P0001';
  END IF;

  SELECT user_id INTO v_target
  FROM public.profiles
  WHERE id = v_photo.profile_id;

  v_was_published :=
    v_photo.status = 'active'
    AND v_photo.admin_approved = true
    AND v_photo.nsfw_cleared = true;

  IF p_decision = 'approve' THEN
    SELECT * INTO v_old
    FROM public.photos
    WHERE profile_id = v_photo.profile_id
      AND order_index = v_photo.order_index
      AND status = 'active'
      AND id <> v_photo.id
    FOR UPDATE;

    IF v_old.id IS NOT NULL THEN
      UPDATE public.photos
      SET status = 'deletion_pending'
      WHERE id = v_old.id;

      UPDATE public.photo_moderation_queue
      SET status = 'rejected',
          reviewed_at = now(),
          review_reason = 'Superseded by an approved replacement.'
      WHERE photo_id = v_old.id
        AND status = 'pending_review';

      INSERT INTO private.storage_deletion_jobs(
        bucket_id, storage_path, photo_id, user_id, reason
      )
      VALUES (
        'profile-photos',
        v_old.storage_path,
        v_old.id,
        v_target,
        'approved_replacement'
      )
      ON CONFLICT (bucket_id, storage_path) DO NOTHING;
    END IF;

    UPDATE public.photos
    SET moderation_status = 'approved',
        moderation_reason = p_reason,
        moderated_at = now(),
        moderated_by = auth.uid(),
        admin_approved = true,
        nsfw_cleared = true,
        status = 'active'
    WHERE id = p_photo_id;

    IF NOT v_was_published AND v_photo.order_index = 0 THEN
      UPDATE public.profiles
      SET approved_at = coalesce(approved_at, now()),
          visibility = CASE
            WHEN visibility IN ('suspended', 'deactivated') THEN visibility
            WHEN onboarding_completed = true THEN 'visible'
            ELSE visibility
          END,
          updated_at = now()
      WHERE id = v_photo.profile_id
      RETURNING
        onboarding_completed = true AND visibility = 'visible'
      INTO v_profile_became_live;
    END IF;
  ELSE
    UPDATE public.photos
    SET moderation_status = 'rejected',
        moderation_reason = p_reason,
        moderated_at = now(),
        moderated_by = auth.uid(),
        admin_approved = false,
        nsfw_cleared = false,
        status = 'rejected'
    WHERE id = p_photo_id;

    INSERT INTO private.storage_deletion_jobs(
      bucket_id, storage_path, photo_id, user_id, reason
    )
    VALUES (
      'profile-photos',
      v_photo.storage_path,
      v_photo.id,
      v_target,
      'moderation_rejected'
    )
    ON CONFLICT (bucket_id, storage_path) DO NOTHING;

    IF v_photo.order_index = 0 THEN
      UPDATE public.profiles
      SET visibility = CASE
            WHEN visibility IN ('suspended', 'deactivated') THEN visibility
            ELSE 'paused'
          END,
          updated_at = now()
      WHERE id = v_photo.profile_id;
    END IF;
  END IF;

  UPDATE public.photo_moderation_queue
  SET status = CASE
        WHEN p_decision = 'approve' THEN 'approved'
        ELSE 'rejected'
      END,
      reviewed_at = now(),
      reviewed_by = auth.uid(),
      review_reason = p_reason
  WHERE photo_id = p_photo_id;

  PERFORM public.queue_notification(
    v_target,
    CASE
      WHEN p_decision = 'approve' AND v_profile_became_live
        THEN 'profile_live'
      WHEN p_decision = 'approve'
        THEN 'photo_approved'
      ELSE 'photo_rejected'
    END,
    CASE
      WHEN p_decision = 'approve' AND v_profile_became_live
        THEN 'Your profile is now live!'
      WHEN p_decision = 'approve'
        THEN 'Photo review complete'
      WHEN v_photo.order_index = 0
        THEN 'Primary photo removed'
      ELSE 'Photo removed'
    END,
    CASE
      WHEN p_decision = 'approve' AND v_profile_became_live
        THEN 'Muslims in your area can now find you on Silarah.'
      WHEN p_decision = 'approve'
        THEN 'Your photo passed Silarah moderation.'
      WHEN v_photo.order_index = 0
        THEN 'Your primary photo did not meet Silarah safety requirements. Your profile is paused until you upload another.'
      ELSE 'A photo did not meet Silarah safety requirements and was removed.'
    END,
    'silarah://profile'
  );

  INSERT INTO public.admin_audit_log(
    admin_id, actor_role, action_type, target_user_id, details
  )
  VALUES (
    auth.uid(),
    public.current_admin_role(),
    'photo_' || p_decision,
    v_target,
    jsonb_build_object(
      'photo_id', p_photo_id,
      'reason', p_reason,
      'was_published', v_was_published,
      'replaced_photo_id', v_old.id
    )
  );

  DELETE FROM public.admin_work_locks
  WHERE item_type = 'photo'
    AND item_id = p_photo_id
    AND locked_by = auth.uid();
END;
$$;

REVOKE ALL ON FUNCTION public.admin_review_photo(uuid, text, text)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_review_photo(uuid, text, text)
  TO authenticated;

CREATE OR REPLACE FUNCTION public.notification_push_enabled(
  p_user_id uuid,
  p_type text
)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT CASE
    WHEN p_type IN (
      'new_message', 'guardian_message_mirror', 'guardian_sent_message'
    ) THEN coalesce(np.new_message, true)
    WHEN p_type IN (
      'interest_received', 'new_interest', 'photo_access_request'
    ) THEN coalesce(np.new_interest, true)
    WHEN p_type IN ('interest_accepted', 'photo_access_granted')
      THEN coalesce(np.interest_accepted, true)
    WHEN p_type IN (
      'profile_returned_to_review', 'profile_live',
      'photo_approved', 'photo_rejected'
    ) THEN coalesce(np.profile_live, true)
    WHEN p_type = 'interest_expiring'
      THEN coalesce(np.interest_expiring, true)
    WHEN p_type IN ('inactive_nudge', 'profile_nudge')
      THEN coalesce(np.inactive_nudge, true)
    WHEN p_type IN (
      'boost_ready', 'boost_available',
      'referral_reward', 'referral_completed'
    ) THEN coalesce(np.boost_available, true)
    ELSE true
  END
  FROM (SELECT p_user_id AS user_id) u
  LEFT JOIN public.notification_prefs np ON np.user_id = u.user_id;
$$;

REVOKE ALL ON FUNCTION public.notification_push_enabled(uuid, text)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.notification_push_enabled(uuid, text)
  TO service_role;
