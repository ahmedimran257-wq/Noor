-- Audit 1: durable photo/KYC reservations, deletion jobs and push leases.

ALTER TABLE public.photos DROP CONSTRAINT IF EXISTS photos_status_check;
ALTER TABLE public.photos
  ADD CONSTRAINT photos_status_check
  CHECK (status IN (
    'pending_upload', 'pending_review', 'active', 'rejected',
    'deletion_pending'
  ));

DROP INDEX IF EXISTS public.idx_photos_primary;
CREATE UNIQUE INDEX IF NOT EXISTS idx_photos_active_slot
  ON public.photos(profile_id, order_index)
  WHERE status = 'active';
CREATE UNIQUE INDEX IF NOT EXISTS idx_photos_pending_review_slot
  ON public.photos(profile_id, order_index)
  WHERE status = 'pending_review';
CREATE UNIQUE INDEX IF NOT EXISTS idx_photos_storage_path_unique
  ON public.photos(storage_path);

CREATE TABLE IF NOT EXISTS private.upload_reservations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  profile_id uuid REFERENCES public.profiles(id) ON DELETE CASCADE,
  bucket_id text NOT NULL,
  purpose text NOT NULL CHECK (purpose IN (
    'profile_photo', 'kyc_selfie', 'kyc_id', 'badge_selfie'
  )),
  order_index integer,
  storage_path text NOT NULL UNIQUE,
  expected_mime text NOT NULL,
  max_bytes integer NOT NULL CHECK (max_bytes BETWEEN 1 AND 10485760),
  replaced_photo_id uuid REFERENCES public.photos(id) ON DELETE SET NULL,
  status text NOT NULL DEFAULT 'reserved' CHECK (status IN (
    'reserved', 'uploaded', 'consumed', 'expired', 'rejected', 'superseded'
  )),
  created_at timestamptz NOT NULL DEFAULT now(),
  expires_at timestamptz NOT NULL DEFAULT now() + interval '15 minutes',
  consumed_at timestamptz
);
CREATE INDEX IF NOT EXISTS idx_upload_reservations_expiry
  ON private.upload_reservations(status, expires_at);
CREATE UNIQUE INDEX IF NOT EXISTS idx_profile_upload_one_live_reservation
  ON private.upload_reservations(user_id, order_index)
  WHERE purpose = 'profile_photo' AND status = 'reserved';

REVOKE ALL ON private.upload_reservations FROM PUBLIC, anon, authenticated;

CREATE TABLE IF NOT EXISTS private.storage_deletion_jobs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  bucket_id text NOT NULL,
  storage_path text NOT NULL,
  photo_id uuid REFERENCES public.photos(id) ON DELETE SET NULL,
  user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE,
  reason text NOT NULL,
  status text NOT NULL DEFAULT 'pending' CHECK (status IN (
    'pending', 'processing', 'completed', 'failed', 'dead_letter'
  )),
  attempt_count integer NOT NULL DEFAULT 0,
  next_attempt_at timestamptz NOT NULL DEFAULT now(),
  lease_token uuid,
  processing_at timestamptz,
  last_error_code text,
  created_at timestamptz NOT NULL DEFAULT now(),
  completed_at timestamptz,
  UNIQUE(bucket_id, storage_path)
);
CREATE INDEX IF NOT EXISTS idx_storage_deletion_jobs_due
  ON private.storage_deletion_jobs(next_attempt_at, created_at)
  WHERE status IN ('pending', 'failed');
REVOKE ALL ON private.storage_deletion_jobs FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.reserve_upload(
  p_user_id uuid,
  p_bucket_id text,
  p_purpose text,
  p_storage_path text,
  p_expected_mime text,
  p_max_bytes integer,
  p_order_index integer DEFAULT NULL
)
RETURNS TABLE(reservation_id uuid, replaced_photo_id uuid)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_profile_id uuid;
  v_replaced uuid;
  v_id uuid;
BEGIN
  IF auth.role() <> 'service_role' THEN
    RAISE EXCEPTION 'service_role_required' USING ERRCODE = 'P0001';
  END IF;
  IF p_storage_path !~ (
      '^' || p_user_id::text || '/[A-Za-z0-9_-]+\\.(webp|jpg)$'
    )
    OR p_purpose NOT IN ('profile_photo','kyc_selfie','kyc_id','badge_selfie')
    OR p_max_bytes NOT BETWEEN 1 AND 10485760 THEN
    RAISE EXCEPTION 'invalid_upload_reservation' USING ERRCODE = 'P0001';
  END IF;
  PERFORM pg_advisory_xact_lock(hashtextextended(p_user_id::text || ':' || coalesce(p_order_index::text, p_purpose), 76));

  IF p_purpose = 'profile_photo' THEN
    IF p_bucket_id <> 'profile-photos'
      OR p_order_index NOT BETWEEN 0 AND 3
      OR p_expected_mime <> 'image/webp' THEN
      RAISE EXCEPTION 'invalid_profile_upload_contract' USING ERRCODE = 'P0001';
    END IF;
    SELECT id INTO v_profile_id FROM public.profiles WHERE user_id = p_user_id;
    IF v_profile_id IS NULL THEN
      RAISE EXCEPTION 'profile_not_found' USING ERRCODE = 'P0001';
    END IF;
    SELECT id INTO v_replaced
    FROM public.photos
    WHERE profile_id = v_profile_id
      AND order_index = p_order_index
      AND status = 'active'
    FOR UPDATE;
    IF EXISTS (
      SELECT 1 FROM public.photos
      WHERE profile_id = v_profile_id
        AND order_index = p_order_index
        AND status = 'pending_review'
    ) THEN
      RAISE EXCEPTION 'photo_review_already_pending' USING ERRCODE = 'P0001';
    END IF;
    IF v_replaced IS NULL AND (
      SELECT count(*) FROM public.photos
      WHERE profile_id = v_profile_id AND status = 'active'
    ) >= 4 THEN
      RAISE EXCEPTION 'photo_quota_reached' USING ERRCODE = 'P0001';
    END IF;
    UPDATE private.upload_reservations
    SET status = 'superseded'
    WHERE user_id = p_user_id
      AND purpose = 'profile_photo'
      AND order_index = p_order_index
      AND status = 'reserved';
  ELSE
    IF p_bucket_id NOT IN ('kyc-documents', 'selfie-verifications')
      OR p_expected_mime NOT IN ('image/webp','image/jpeg') THEN
      RAISE EXCEPTION 'invalid_identity_upload_contract' USING ERRCODE = 'P0001';
    END IF;
  END IF;

  INSERT INTO private.upload_reservations(
    user_id, profile_id, bucket_id, purpose, order_index, storage_path,
    expected_mime, max_bytes, replaced_photo_id
  )
  VALUES (
    p_user_id, v_profile_id, p_bucket_id, p_purpose, p_order_index,
    p_storage_path, p_expected_mime, p_max_bytes, v_replaced
  )
  RETURNING id INTO v_id;
  RETURN QUERY SELECT v_id, v_replaced;
END;
$$;

CREATE OR REPLACE FUNCTION public.consume_upload_reservation(
  p_user_id uuid,
  p_storage_path text,
  p_observed_mime text,
  p_observed_bytes integer
)
RETURNS TABLE(
  reservation_id uuid,
  profile_id uuid,
  purpose text,
  order_index integer,
  replaced_photo_id uuid
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_row private.upload_reservations%ROWTYPE;
BEGIN
  IF auth.role() <> 'service_role' THEN
    RAISE EXCEPTION 'service_role_required' USING ERRCODE = 'P0001';
  END IF;
  SELECT * INTO v_row
  FROM private.upload_reservations
  WHERE user_id = p_user_id
    AND storage_path = p_storage_path
    AND status = 'reserved'
  FOR UPDATE;
  IF NOT FOUND OR v_row.expires_at <= now()
    OR v_row.expected_mime <> p_observed_mime
    OR p_observed_bytes > v_row.max_bytes THEN
    RAISE EXCEPTION 'upload_reservation_invalid_or_expired' USING ERRCODE = 'P0001';
  END IF;
  UPDATE private.upload_reservations
  SET status = 'consumed', consumed_at = now()
  WHERE id = v_row.id;
  RETURN QUERY
  SELECT v_row.id, v_row.profile_id, v_row.purpose,
         v_row.order_index, v_row.replaced_photo_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.consume_kyc_upload_reservations(
  p_user_id uuid,
  p_selfie_path text,
  p_selfie_mime text,
  p_selfie_bytes integer,
  p_id_path text,
  p_id_mime text,
  p_id_bytes integer
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_selfie private.upload_reservations%ROWTYPE;
  v_id private.upload_reservations%ROWTYPE;
BEGIN
  IF auth.role() <> 'service_role' THEN
    RAISE EXCEPTION 'service_role_required' USING ERRCODE = 'P0001';
  END IF;
  SELECT * INTO v_selfie
  FROM private.upload_reservations
  WHERE user_id = p_user_id AND storage_path = p_selfie_path
    AND purpose = 'kyc_selfie' AND status = 'reserved'
  FOR UPDATE;
  SELECT * INTO v_id
  FROM private.upload_reservations
  WHERE user_id = p_user_id AND storage_path = p_id_path
    AND purpose = 'kyc_id' AND status = 'reserved'
  FOR UPDATE;
  IF v_selfie.id IS NULL OR v_id.id IS NULL
    OR v_selfie.expires_at <= now() OR v_id.expires_at <= now()
    OR v_selfie.expected_mime <> p_selfie_mime
    OR v_id.expected_mime <> p_id_mime
    OR p_selfie_bytes > v_selfie.max_bytes
    OR p_id_bytes > v_id.max_bytes THEN
    RAISE EXCEPTION 'kyc_upload_reservation_invalid_or_expired'
      USING ERRCODE = 'P0001';
  END IF;
  UPDATE private.upload_reservations
  SET status = 'consumed', consumed_at = now()
  WHERE id IN (v_selfie.id, v_id.id);
END;
$$;

REVOKE ALL ON FUNCTION public.reserve_upload(uuid, text, text, text, text, integer, integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.consume_upload_reservation(uuid, text, text, integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.consume_kyc_upload_reservations(uuid, text, text, integer, text, text, integer) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.reserve_upload(uuid, text, text, text, text, integer, integer) TO service_role;
GRANT EXECUTE ON FUNCTION public.consume_upload_reservation(uuid, text, text, integer) TO service_role;
GRANT EXECUTE ON FUNCTION public.consume_kyc_upload_reservations(uuid, text, text, integer, text, text, integer) TO service_role;

CREATE OR REPLACE FUNCTION public.request_profile_photo_deletion(
  p_user_id uuid,
  p_order_index integer
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_photo public.photos%ROWTYPE;
  v_profile_id uuid;
BEGIN
  IF auth.role() <> 'service_role' THEN
    RAISE EXCEPTION 'service_role_required' USING ERRCODE = 'P0001';
  END IF;
  SELECT id INTO v_profile_id
  FROM public.profiles
  WHERE user_id = p_user_id;
  SELECT * INTO v_photo
  FROM public.photos
  WHERE profile_id = v_profile_id
    AND order_index = p_order_index
    AND status IN ('active', 'pending_review', 'rejected')
  ORDER BY created_at DESC
  LIMIT 1
  FOR UPDATE;
  IF NOT FOUND THEN
    RETURN false;
  END IF;
  UPDATE public.photos
  SET status = 'deletion_pending'
  WHERE id = v_photo.id;
  INSERT INTO private.storage_deletion_jobs(
    bucket_id, storage_path, photo_id, user_id, reason
  )
  VALUES (
    'profile-photos', v_photo.storage_path, v_photo.id, p_user_id,
    'member_requested'
  )
  ON CONFLICT (bucket_id, storage_path) DO UPDATE
  SET status = 'pending', next_attempt_at = now(), lease_token = NULL;
  IF p_order_index = 0 THEN
    UPDATE public.profiles
    SET visibility = 'hidden'
    WHERE id = v_profile_id;
  END IF;
  RETURN true;
END;
$$;

CREATE OR REPLACE FUNCTION public.checkout_storage_deletions(
  p_limit integer DEFAULT 25
)
RETURNS TABLE(
  job_id uuid,
  bucket_id text,
  storage_path text,
  lease_token uuid
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  IF auth.role() <> 'service_role' THEN
    RAISE EXCEPTION 'service_role_required' USING ERRCODE = 'P0001';
  END IF;
  RETURN QUERY
  WITH candidates AS (
    SELECT j.id
    FROM private.storage_deletion_jobs j
    WHERE (
      j.status IN ('pending', 'failed') AND j.next_attempt_at <= now()
    ) OR (
      j.status = 'processing' AND j.processing_at < now() - interval '5 minutes'
    )
    ORDER BY j.created_at
    LIMIT least(greatest(p_limit, 1), 100)
    FOR UPDATE SKIP LOCKED
  ), leased AS (
    UPDATE private.storage_deletion_jobs j
    SET status = 'processing',
        processing_at = now(),
        lease_token = gen_random_uuid(),
        attempt_count = attempt_count + 1
    FROM candidates c
    WHERE j.id = c.id
    RETURNING j.id, j.bucket_id, j.storage_path, j.lease_token
  )
  SELECT l.id, l.bucket_id, l.storage_path, l.lease_token
  FROM leased l;
END;
$$;

CREATE OR REPLACE FUNCTION public.expire_upload_reservations(
  p_limit integer DEFAULT 100
)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_count integer;
BEGIN
  IF auth.role() <> 'service_role' THEN
    RAISE EXCEPTION 'service_role_required' USING ERRCODE = 'P0001';
  END IF;
  WITH expired AS (
    SELECT id, bucket_id, storage_path, user_id
    FROM private.upload_reservations
    WHERE status = 'reserved' AND expires_at <= now()
    ORDER BY expires_at
    LIMIT least(greatest(p_limit, 1), 500)
    FOR UPDATE SKIP LOCKED
  ), changed AS (
    UPDATE private.upload_reservations r
    SET status = 'expired'
    FROM expired e
    WHERE r.id = e.id
    RETURNING e.bucket_id, e.storage_path, e.user_id
  ), queued AS (
    INSERT INTO private.storage_deletion_jobs(
      bucket_id, storage_path, user_id, reason
    )
    SELECT bucket_id, storage_path, user_id, 'expired_upload_reservation'
    FROM changed
    ON CONFLICT (bucket_id, storage_path) DO NOTHING
    RETURNING 1
  )
  SELECT count(*) INTO v_count FROM changed;
  RETURN coalesce(v_count, 0);
END;
$$;

CREATE OR REPLACE FUNCTION public.finish_storage_deletion(
  p_job_id uuid,
  p_lease_token uuid,
  p_success boolean,
  p_error_code text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_job private.storage_deletion_jobs%ROWTYPE;
BEGIN
  IF auth.role() <> 'service_role' THEN
    RAISE EXCEPTION 'service_role_required' USING ERRCODE = 'P0001';
  END IF;
  SELECT * INTO v_job
  FROM private.storage_deletion_jobs
  WHERE id = p_job_id AND lease_token = p_lease_token
  FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'invalid_storage_deletion_lease' USING ERRCODE = 'P0001';
  END IF;
  IF p_success THEN
    DELETE FROM public.photos WHERE id = v_job.photo_id;
    UPDATE private.storage_deletion_jobs
    SET status = 'completed', completed_at = now(), lease_token = NULL,
        last_error_code = NULL
    WHERE id = p_job_id;
  ELSE
    UPDATE private.storage_deletion_jobs
    SET status = CASE WHEN attempt_count >= 8 THEN 'dead_letter' ELSE 'failed' END,
        next_attempt_at = now() + make_interval(
          secs => least(21600, (30 * power(2, least(attempt_count, 9)))::integer)
        ),
        lease_token = NULL,
        last_error_code = left(coalesce(p_error_code, 'storage_delete_failed'), 80)
    WHERE id = p_job_id;
  END IF;
END;
$$;

REVOKE ALL ON FUNCTION public.request_profile_photo_deletion(uuid, integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.checkout_storage_deletions(integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.expire_upload_reservations(integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.finish_storage_deletion(uuid, uuid, boolean, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.request_profile_photo_deletion(uuid, integer) TO service_role;
GRANT EXECUTE ON FUNCTION public.checkout_storage_deletions(integer) TO service_role;
GRANT EXECUTE ON FUNCTION public.expire_upload_reservations(integer) TO service_role;
GRANT EXECUTE ON FUNCTION public.finish_storage_deletion(uuid, uuid, boolean, text) TO service_role;

ALTER TABLE public.photo_moderation_queue
  DROP CONSTRAINT IF EXISTS photo_moderation_queue_confidence_check;
ALTER TABLE public.photo_moderation_queue
  ADD CONSTRAINT photo_moderation_queue_confidence_check
  CHECK (confidence >= 0 AND confidence <= 1);
ALTER TABLE public.photo_moderation_queue
  DROP CONSTRAINT IF EXISTS photo_moderation_queue_category_check;
ALTER TABLE public.photo_moderation_queue
  ADD CONSTRAINT photo_moderation_queue_category_check
  CHECK (category IN ('unreviewed_upload', 'explicit_content'));

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
BEGIN
  IF NOT public.is_active_admin(ARRAY['super_admin','moderator']) THEN
    RAISE EXCEPTION 'aal2_staff_required' USING ERRCODE = 'P0001';
  END IF;
  IF p_decision NOT IN ('approve','reject') THEN
    RAISE EXCEPTION 'invalid_photo_decision' USING ERRCODE = 'P0001';
  END IF;
  SELECT ph.* INTO v_photo
  FROM public.photos ph
  JOIN public.photo_moderation_queue q ON q.photo_id = ph.id
  WHERE ph.id = p_photo_id AND q.status = 'pending_review'
  FOR UPDATE OF ph;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'photo_not_pending_review' USING ERRCODE = 'P0001';
  END IF;
  SELECT user_id INTO v_target
  FROM public.profiles WHERE id = v_photo.profile_id;

  IF p_decision = 'approve' THEN
    SELECT * INTO v_old
    FROM public.photos
    WHERE profile_id = v_photo.profile_id
      AND order_index = v_photo.order_index
      AND status = 'active'
      AND id <> v_photo.id
    FOR UPDATE;
    IF v_old.id IS NOT NULL THEN
      UPDATE public.photos SET status = 'deletion_pending' WHERE id = v_old.id;
      INSERT INTO private.storage_deletion_jobs(
        bucket_id, storage_path, photo_id, user_id, reason
      )
      VALUES (
        'profile-photos', v_old.storage_path, v_old.id, v_target,
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
      'profile-photos', v_photo.storage_path, v_photo.id, v_target,
      'moderation_rejected'
    )
    ON CONFLICT (bucket_id, storage_path) DO NOTHING;
  END IF;

  UPDATE public.photo_moderation_queue
  SET status = CASE WHEN p_decision = 'approve' THEN 'approved' ELSE 'rejected' END,
      reviewed_at = now(), reviewed_by = auth.uid(), review_reason = p_reason
  WHERE photo_id = p_photo_id;

  IF p_decision = 'approve' AND v_photo.order_index = 0 THEN
    UPDATE public.profiles
    SET approved_at = coalesce(approved_at, now()),
        visibility = CASE
          WHEN visibility IN ('suspended','deactivated') THEN visibility
          ELSE 'visible'
        END
    WHERE id = v_photo.profile_id;
  END IF;

  PERFORM public.queue_notification(
    v_target,
    CASE
      WHEN p_decision = 'approve' AND v_photo.order_index = 0 THEN 'profile_live'
      WHEN p_decision = 'approve' THEN 'photo_approved'
      ELSE 'photo_rejected'
    END,
    CASE
      WHEN p_decision = 'approve' AND v_photo.order_index = 0 THEN 'Your profile is now live! 🎉'
      WHEN p_decision = 'approve' THEN 'Photo approved'
      ELSE 'Photo needs attention'
    END,
    CASE
      WHEN p_decision = 'approve' AND v_photo.order_index = 0
        THEN 'Muslims in your area can now find you on Silarah.'
      WHEN p_decision = 'approve' THEN 'Your photo passed the safety review.'
      ELSE 'This photo did not meet Silarah’s safety requirements. You can upload another.'
    END,
    CASE WHEN v_photo.order_index = 0 THEN '/home?tab=0' ELSE '/home?tab=3' END
  );

  INSERT INTO public.admin_audit_log(
    admin_id, actor_role, action_type, target_user_id, details
  )
  VALUES (
    auth.uid(), public.current_admin_role(), 'photo_' || p_decision,
    v_target,
    jsonb_build_object(
      'photo_id', p_photo_id, 'reason', p_reason,
      'replaced_photo_id', v_old.id
    )
  );
END;
$$;

-- Durable notification lease and token-level delivery state.
ALTER TABLE public.notifications
  ADD COLUMN IF NOT EXISTS processing_at timestamptz,
  ADD COLUMN IF NOT EXISTS lease_token uuid,
  ADD COLUMN IF NOT EXISTS attempt_count integer NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS next_attempt_at timestamptz,
  ADD COLUMN IF NOT EXISTS delivery_status text NOT NULL DEFAULT 'pending',
  ADD COLUMN IF NOT EXISTS last_error_code text;

UPDATE public.notifications
SET next_attempt_at = coalesce(next_attempt_at, scheduled_at)
WHERE next_attempt_at IS NULL;
ALTER TABLE public.notifications
  ALTER COLUMN next_attempt_at SET DEFAULT now(),
  ALTER COLUMN next_attempt_at SET NOT NULL;
ALTER TABLE public.notifications DROP CONSTRAINT IF EXISTS notifications_delivery_status_check;
ALTER TABLE public.notifications
  ADD CONSTRAINT notifications_delivery_status_check
  CHECK (delivery_status IN ('pending','processing','sent','in_app_only','dead_letter'));

CREATE TABLE IF NOT EXISTS private.notification_deliveries (
  notification_id uuid NOT NULL REFERENCES public.notifications(id) ON DELETE CASCADE,
  token_hash text NOT NULL,
  status text NOT NULL CHECK (status IN ('pending','sent','retry','invalid','failed')),
  attempt_count integer NOT NULL DEFAULT 0,
  next_attempt_at timestamptz NOT NULL DEFAULT now(),
  last_error_code text,
  updated_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY(notification_id, token_hash)
);
REVOKE ALL ON private.notification_deliveries FROM PUBLIC, anon, authenticated;

DROP FUNCTION IF EXISTS public.checkout_notifications(integer);
CREATE OR REPLACE FUNCTION public.checkout_notifications(batch_size integer DEFAULT 100)
RETURNS TABLE(
  id uuid,
  user_id uuid,
  type text,
  title text,
  body text,
  deep_link text,
  lease_token uuid
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  IF auth.role() <> 'service_role' THEN
    RAISE EXCEPTION 'service_role_required' USING ERRCODE = 'P0001';
  END IF;
  UPDATE public.notifications
  SET delivery_status = 'pending', processing_at = NULL, lease_token = NULL
  WHERE delivery_status = 'processing'
    AND processing_at < now() - interval '5 minutes'
    AND sent_at IS NULL;

  UPDATE public.notifications n
  SET sent_at = now(), delivery_status = 'in_app_only'
  WHERE n.sent_at IS NULL
    AND n.scheduled_at <= now()
    AND NOT public.notification_push_enabled(n.user_id, n.type);

  RETURN QUERY
  UPDATE public.notifications n
  SET delivery_status = 'processing',
      processing_at = now(),
      lease_token = gen_random_uuid(),
      attempt_count = n.attempt_count + 1
  WHERE n.id IN (
    SELECT q.id
    FROM public.notifications q
    WHERE q.sent_at IS NULL
      AND q.scheduled_at <= now()
      AND q.next_attempt_at <= now()
      AND q.delivery_status = 'pending'
      AND q.attempt_count < 8
      AND public.notification_push_enabled(q.user_id, q.type)
    ORDER BY q.scheduled_at, q.id
    LIMIT least(greatest(batch_size, 1), 100)
    FOR UPDATE SKIP LOCKED
  )
  RETURNING n.id, n.user_id, n.type, n.title, n.body, n.deep_link, n.lease_token;
END;
$$;

CREATE OR REPLACE FUNCTION public.finish_notification_delivery(
  p_notification_id uuid,
  p_lease_token uuid,
  p_status text,
  p_error_code text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE v_attempt integer;
BEGIN
  IF auth.role() <> 'service_role'
    OR p_status NOT IN ('sent','in_app_only','retry','dead_letter') THEN
    RAISE EXCEPTION 'invalid_delivery_completion' USING ERRCODE = 'P0001';
  END IF;
  SELECT attempt_count INTO v_attempt
  FROM public.notifications
  WHERE id = p_notification_id
    AND lease_token = p_lease_token
    AND delivery_status = 'processing'
  FOR UPDATE;
  IF NOT FOUND THEN RETURN; END IF;
  UPDATE public.notifications
  SET sent_at = CASE WHEN p_status IN ('sent','in_app_only') THEN now() ELSE NULL END,
      delivery_status = CASE
        WHEN p_status = 'retry' AND v_attempt >= 8 THEN 'dead_letter'
        WHEN p_status = 'retry' THEN 'pending'
        ELSE p_status
      END,
      processing_at = NULL,
      lease_token = NULL,
      last_error_code = left(p_error_code, 80),
      next_attempt_at = CASE
        WHEN p_status = 'retry'
          THEN now() + make_interval(secs => least(3600, (power(2, least(v_attempt, 10))::integer * 15)))
        ELSE next_attempt_at
      END
  WHERE id = p_notification_id AND lease_token = p_lease_token;
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

REVOKE ALL ON FUNCTION public.checkout_notifications(integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.finish_notification_delivery(uuid, uuid, text, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.record_notification_token_delivery(uuid, uuid, text, text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.checkout_notifications(integer) TO service_role;
GRANT EXECUTE ON FUNCTION public.finish_notification_delivery(uuid, uuid, text, text) TO service_role;
GRANT EXECUTE ON FUNCTION public.record_notification_token_delivery(uuid, uuid, text, text, text) TO service_role;

-- Honor each user's configured quiet window.
CREATE OR REPLACE FUNCTION public.queue_notification(
  p_user_id uuid,
  p_type text,
  p_title text,
  p_body text,
  p_deep_link text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_tz text;
  v_start time;
  v_end time;
  v_local timestamp;
  v_local_time time;
  v_local_date date;
  v_deliver_local timestamp;
  v_deliver_at timestamptz;
  v_quiet boolean;
BEGIN
  SELECT
    CASE WHEN EXISTS (
      SELECT 1 FROM pg_catalog.pg_timezone_names WHERE name = u.timezone
    ) THEN u.timezone ELSE 'UTC' END,
    coalesce(np.quiet_start, time '23:00'),
    coalesce(np.quiet_end, time '08:00')
  INTO v_tz, v_start, v_end
  FROM public.users u
  LEFT JOIN public.notification_prefs np ON np.user_id = u.id
  WHERE u.id = p_user_id;
  IF v_tz IS NULL THEN v_tz := 'UTC'; END IF;

  v_local := now() AT TIME ZONE v_tz;
  v_local_time := v_local::time;
  v_local_date := v_local::date;
  v_quiet := CASE
    WHEN v_start = v_end THEN false
    WHEN v_start < v_end THEN v_local_time >= v_start AND v_local_time < v_end
    ELSE v_local_time >= v_start OR v_local_time < v_end
  END;

  IF NOT v_quiet THEN
    v_deliver_at := now();
  ELSE
    v_deliver_local := CASE
      WHEN v_start < v_end THEN v_local_date + v_end
      WHEN v_local_time >= v_start THEN (v_local_date + 1) + v_end
      ELSE v_local_date + v_end
    END;
    v_deliver_at := v_deliver_local AT TIME ZONE v_tz;
  END IF;

  INSERT INTO public.notifications(
    user_id, type, title, body, deep_link, scheduled_at, next_attempt_at
  )
  VALUES (
    p_user_id, p_type, left(p_title, 160), left(p_body, 1000),
    p_deep_link, v_deliver_at, v_deliver_at
  );
END;
$$;

-- Repository-defined identity/selfie bucket limits.
UPDATE storage.buckets
SET public = false,
    file_size_limit = 5242880,
    allowed_mime_types = ARRAY['image/webp','image/jpeg']
WHERE id = 'kyc-documents';

UPDATE storage.buckets
SET public = false,
    file_size_limit = 3145728,
    allowed_mime_types = ARRAY['image/webp','image/jpeg']
WHERE id = 'selfie-verifications';

-- Shared execution ledger/overlap primitive for cron and workers.
CREATE TABLE IF NOT EXISTS private.job_runs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  job_name text NOT NULL,
  status text NOT NULL CHECK (status IN ('running','completed','failed','skipped')),
  started_at timestamptz NOT NULL DEFAULT now(),
  finished_at timestamptz,
  rows_affected bigint,
  error_code text,
  details jsonb NOT NULL DEFAULT '{}'::jsonb
);
CREATE INDEX IF NOT EXISTS idx_job_runs_name_started
  ON private.job_runs(job_name, started_at DESC);
REVOKE ALL ON private.job_runs FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.begin_worker_run(p_job_name text)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_id uuid;
BEGIN
  IF auth.role() <> 'service_role' THEN
    RAISE EXCEPTION 'service_role_required' USING ERRCODE = 'P0001';
  END IF;
  IF NOT pg_try_advisory_xact_lock(hashtextextended(p_job_name, 148)) THEN
    RETURN NULL;
  END IF;
  IF EXISTS (
    SELECT 1 FROM private.job_runs
    WHERE job_name = p_job_name
      AND status = 'running'
      AND started_at > now() - interval '10 minutes'
  ) THEN
    RETURN NULL;
  END IF;
  UPDATE private.job_runs
  SET status = 'failed', finished_at = now(), error_code = 'stale_lease'
  WHERE job_name = p_job_name
    AND status = 'running'
    AND started_at <= now() - interval '10 minutes';
  INSERT INTO private.job_runs(job_name, status)
  VALUES (left(p_job_name, 80), 'running')
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.finish_worker_run(
  p_run_id uuid,
  p_status text,
  p_rows_affected bigint DEFAULT 0,
  p_error_code text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  IF auth.role() <> 'service_role' OR p_status NOT IN ('completed','failed') THEN
    RAISE EXCEPTION 'invalid_worker_completion' USING ERRCODE = 'P0001';
  END IF;
  UPDATE private.job_runs
  SET status = p_status,
      finished_at = now(),
      rows_affected = greatest(p_rows_affected, 0),
      error_code = left(p_error_code, 80)
  WHERE id = p_run_id AND status = 'running';
END;
$$;

REVOKE ALL ON FUNCTION public.begin_worker_run(text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.finish_worker_run(uuid, text, bigint, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.begin_worker_run(text) TO service_role;
GRANT EXECUTE ON FUNCTION public.finish_worker_run(uuid, text, bigint, text) TO service_role;

CREATE OR REPLACE FUNCTION private.invoke_storage_lifecycle_worker()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_secret text;
  v_url text;
BEGIN
  v_url := nullif(current_setting('app.supabase_url', true), '');
  IF v_url IS NULL THEN
    SELECT decrypted_secret INTO v_url
    FROM vault.decrypted_secrets
    WHERE name = 'silarah_supabase_url'
    LIMIT 1;
  END IF;
  SELECT decrypted_secret INTO v_secret
  FROM vault.decrypted_secrets
  WHERE name IN ('silarah_edge_cron_secret', 'mithaq_edge_cron_secret')
  ORDER BY (name = 'silarah_edge_cron_secret') DESC
  LIMIT 1;
  IF v_url ~ '^https://[a-z0-9-]+[.]supabase[.]co$'
    AND nullif(v_secret, '') IS NOT NULL THEN
    PERFORM net.http_post(
      url := v_url || '/functions/v1/storage-lifecycle-worker',
      body := '{}'::jsonb,
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'x-cron-secret', v_secret
      ),
      timeout_milliseconds := 10000
    );
  END IF;
END;
$$;
REVOKE ALL ON FUNCTION private.invoke_storage_lifecycle_worker() FROM PUBLIC;

DO $$
BEGIN
  PERFORM cron.unschedule(jobid)
  FROM cron.job
  WHERE jobname = 'storage_lifecycle_worker';
END;
$$;
SELECT cron.schedule(
  'storage_lifecycle_worker',
  '*/5 * * * *',
  $$SELECT private.invoke_storage_lifecycle_worker();$$
);
