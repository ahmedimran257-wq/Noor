-- Repair two app-owned PL/pgSQL ambiguities reported by plpgsql_check.
-- Extension-owned PostGIS diagnostics are intentionally not modified here.

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
    ON CONFLICT ON CONSTRAINT photo_moderation_queue_photo_id_key DO NOTHING;

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

-- Removing the default preserves the explicit nullable parameter used by the
-- app while making the internal zero-argument worker call unambiguous.
DROP FUNCTION public.get_guardian_dashboard(uuid);

CREATE FUNCTION public.get_guardian_dashboard(
  p_mark_seen_ward_id uuid
)
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
  IF p_mark_seen_ward_id IS NOT NULL
    AND NOT public.is_current_guardian_for_ward(
      p_mark_seen_ward_id,
      NULL
    ) THEN
    RAISE EXCEPTION 'guardian_not_authorized' USING ERRCODE = 'P0001';
  END IF;

  RETURN QUERY
  SELECT dashboard.*
  FROM public.get_guardian_dashboard() dashboard;

  IF p_mark_seen_ward_id IS NOT NULL THEN
    INSERT INTO public.guardian_sessions(
      guardian_id, ward_id, last_seen_at, is_active
    )
    VALUES (v_guardian_id, p_mark_seen_ward_id, now(), true)
    ON CONFLICT (guardian_id, ward_id) DO UPDATE
    SET last_seen_at = EXCLUDED.last_seen_at,
        is_active = true;
  END IF;
END;
$$;

REVOKE ALL ON FUNCTION public.get_guardian_dashboard(uuid)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_guardian_dashboard(uuid)
  TO authenticated;

COMMENT ON FUNCTION public.finalize_profile_photo_upload(
  uuid, text, text, integer, text, numeric
) IS 'Atomic service-only photo finalization with an unambiguous moderation-queue conflict target.';
COMMENT ON FUNCTION public.get_guardian_dashboard(uuid) IS
  'Auth-bound guardian dashboard with an explicit nullable acknowledgement parameter.';
