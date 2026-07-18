-- Cost-conscious global KYC: all non-DigiLocker checks are reviewed by a
-- human. On-device OCR/face scores are hints only and can never grant KYC.

CREATE TABLE IF NOT EXISTS public.kyc_review_submissions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  profile_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  status text NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'approved', 'rejected', 'resubmit', 'expired')),
  country_code varchar(2) NOT NULL,
  id_type text NOT NULL
    CHECK (id_type IN ('government_id', 'national_id', 'passport', 'driving_license')),
  client_ocr_dob date,
  client_face_similarity numeric(5,4)
    CHECK (client_face_similarity IS NULL OR client_face_similarity BETWEEN 0 AND 1),
  selfie_storage_path text,
  id_photo_storage_path text,
  selfie_sha256 text,
  id_photo_sha256 text,
  attempt_number integer NOT NULL CHECK (attempt_number BETWEEN 1 AND 1000),
  submitted_at timestamptz NOT NULL DEFAULT now(),
  reviewed_at timestamptz,
  -- Staff identities live in auth.users and deliberately do not need a
  -- public dating profile.
  reviewed_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  review_reason text,
  review_checklist jsonb NOT NULL DEFAULT '{}'::jsonb
    CHECK (jsonb_typeof(review_checklist) = 'object'),
  purge_after timestamptz NOT NULL DEFAULT (now() + interval '30 days'),
  documents_purged_at timestamptz,
  CHECK (
    documents_purged_at IS NOT NULL OR
    (selfie_storage_path IS NOT NULL AND id_photo_storage_path IS NOT NULL)
  )
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_kyc_review_one_pending_per_user
  ON public.kyc_review_submissions (user_id)
  WHERE status = 'pending';
CREATE INDEX IF NOT EXISTS idx_kyc_review_queue
  ON public.kyc_review_submissions (submitted_at, id)
  WHERE status = 'pending';
CREATE INDEX IF NOT EXISTS idx_kyc_review_retention
  ON public.kyc_review_submissions (purge_after, id)
  WHERE documents_purged_at IS NULL;

ALTER TABLE public.kyc_review_submissions ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.kyc_review_submissions FROM PUBLIC, anon, authenticated;

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS kyc_manual_review_id uuid
    REFERENCES public.kyc_review_submissions(id) ON DELETE SET NULL;

COMMENT ON TABLE public.kyc_review_submissions IS
  'Service-role submission ledger and staff-only manual global KYC queue. Client OCR and face scores are non-authoritative review hints.';
COMMENT ON COLUMN public.kyc_review_submissions.purge_after IS
  'Raw identity images are removed after 30 days. Only decision metadata, checks and cryptographic file digests remain.';

CREATE OR REPLACE FUNCTION public.submit_manual_kyc_for_review(
  p_user_id uuid,
  p_country_code text,
  p_id_type text,
  p_selfie_storage_path text,
  p_id_photo_storage_path text,
  p_client_ocr_dob date DEFAULT NULL,
  p_client_face_similarity numeric DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_profile public.profiles%ROWTYPE;
  v_existing_id uuid;
  v_submission_id uuid;
  v_attempt_number integer;
  v_recent_attempts integer;
BEGIN
  IF coalesce(auth.role(), '') <> 'service_role' THEN
    RAISE EXCEPTION 'Service role required.';
  END IF;

  SELECT * INTO v_profile
  FROM public.profiles
  WHERE user_id = p_user_id
  FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Profile not found.';
  END IF;
  IF upper(trim(coalesce(p_country_code, ''))) <> v_profile.country_code THEN
    RAISE EXCEPTION 'KYC country must match the profile country.';
  END IF;
  IF p_id_type NOT IN ('government_id', 'national_id', 'passport', 'driving_license') THEN
    RAISE EXCEPTION 'Unsupported identity document type.';
  END IF;
  IF p_client_face_similarity IS NOT NULL AND
     (p_client_face_similarity < 0 OR p_client_face_similarity > 1) THEN
    RAISE EXCEPTION 'Invalid client face hint.';
  END IF;
  IF p_selfie_storage_path !~ ('^' || p_user_id::text || '/kyc_selfie_[0-9a-f-]+\.(jpg|jpeg|png|webp)$') OR
     p_id_photo_storage_path !~ ('^' || p_user_id::text || '/kyc_id_[0-9a-f-]+\.(jpg|jpeg|png|webp)$') THEN
    RAISE EXCEPTION 'Invalid private KYC document paths.';
  END IF;

  SELECT id INTO v_existing_id
  FROM public.kyc_review_submissions
  WHERE user_id = p_user_id AND status = 'pending'
  ORDER BY submitted_at DESC
  LIMIT 1;
  IF v_existing_id IS NOT NULL THEN
    RETURN jsonb_build_object(
      'status', 'pending_review',
      'submission_id', v_existing_id,
      'accepted', false,
      'message', 'Your identity check is already awaiting review.'
    );
  END IF;

  SELECT count(*)::integer INTO v_recent_attempts
  FROM public.kyc_review_submissions
  WHERE user_id = p_user_id
    AND submitted_at > now() - interval '24 hours';
  IF v_recent_attempts >= 3 THEN
    RAISE EXCEPTION 'Maximum 3 identity-check submissions per 24 hours.';
  END IF;

  SELECT coalesce(max(attempt_number), 0) + 1 INTO v_attempt_number
  FROM public.kyc_review_submissions
  WHERE user_id = p_user_id;

  INSERT INTO public.kyc_review_submissions (
    user_id,
    profile_id,
    country_code,
    id_type,
    client_ocr_dob,
    client_face_similarity,
    selfie_storage_path,
    id_photo_storage_path,
    attempt_number
  ) VALUES (
    p_user_id,
    v_profile.id,
    v_profile.country_code,
    p_id_type,
    p_client_ocr_dob,
    p_client_face_similarity,
    p_selfie_storage_path,
    p_id_photo_storage_path,
    v_attempt_number
  )
  RETURNING id INTO v_submission_id;

  UPDATE public.profiles
  SET kyc_verified = false,
      kyc_method = 'manual_review_v1',
      kyc_assurance_level = 'none',
      kyc_manual_review_id = v_submission_id,
      kyc_id_type = p_id_type,
      kyc_country_code = v_profile.country_code,
      kyc_selfie_storage_path = p_selfie_storage_path,
      kyc_id_photo_storage_path = p_id_photo_storage_path,
      face_similarity = p_client_face_similarity,
      verification_status = 'pending_review',
      is_verified = coalesce(has_verification_badge, false)
  WHERE id = v_profile.id;

  RETURN jsonb_build_object(
    'status', 'pending_review',
    'submission_id', v_submission_id,
    'accepted', true,
    'message', 'Your identity check was submitted for private review.'
  );
END;
$$;

REVOKE ALL ON FUNCTION public.submit_manual_kyc_for_review(
  uuid, text, text, text, text, date, numeric
) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.submit_manual_kyc_for_review(
  uuid, text, text, text, text, date, numeric
) TO service_role;

DROP FUNCTION IF EXISTS public.admin_kyc_queue(integer);
CREATE FUNCTION public.admin_kyc_queue(p_limit integer DEFAULT 25)
RETURNS TABLE(
  submission_id uuid,
  user_id uuid,
  profile_id uuid,
  name text,
  date_of_birth date,
  age integer,
  country_code text,
  kyc_id_type text,
  client_ocr_dob date,
  client_face_similarity numeric,
  attempt_number integer,
  submitted_at timestamptz,
  selfie_path text,
  id_path text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT public.is_active_admin(ARRAY['super_admin','moderator']) THEN
    RAISE EXCEPTION 'Staff authorization required';
  END IF;
  IF p_limit < 1 OR p_limit > 100 THEN
    RAISE EXCEPTION 'Queue limit must be between 1 and 100.';
  END IF;

  RETURN QUERY
  SELECT
    s.id,
    s.user_id,
    s.profile_id,
    trim(concat_ws(' ', p.first_name, p.last_name)),
    p.date_of_birth,
    extract(year FROM age(p.date_of_birth))::integer,
    s.country_code::text,
    s.id_type,
    s.client_ocr_dob,
    s.client_face_similarity,
    s.attempt_number,
    s.submitted_at,
    s.selfie_storage_path,
    s.id_photo_storage_path
  FROM public.kyc_review_submissions s
  JOIN public.profiles p ON p.id = s.profile_id
  WHERE s.status = 'pending'
    AND s.documents_purged_at IS NULL
  ORDER BY s.submitted_at ASC, s.id ASC
  LIMIT p_limit;
END;
$$;

REVOKE ALL ON FUNCTION public.admin_kyc_queue(integer) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_kyc_queue(integer) TO authenticated;

DROP FUNCTION IF EXISTS public.admin_review_kyc(uuid, text, text);
CREATE FUNCTION public.admin_review_kyc(
  p_submission_id uuid,
  p_decision text,
  p_reason text DEFAULT NULL,
  p_document_readable boolean DEFAULT false,
  p_name_match boolean DEFAULT false,
  p_dob_match boolean DEFAULT false,
  p_face_match boolean DEFAULT false,
  p_document_unexpired boolean DEFAULT false
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_submission public.kyc_review_submissions%ROWTYPE;
  v_profile public.profiles%ROWTYPE;
  v_reason text := trim(coalesce(p_reason, ''));
BEGIN
  IF NOT public.is_active_admin(ARRAY['super_admin','moderator']) THEN
    RAISE EXCEPTION 'Staff authorization required';
  END IF;
  IF p_decision NOT IN ('approve', 'reject', 'resubmit') THEN
    RAISE EXCEPTION 'Unsupported KYC decision';
  END IF;

  SELECT * INTO v_submission
  FROM public.kyc_review_submissions
  WHERE id = p_submission_id
  FOR UPDATE;
  IF NOT FOUND OR v_submission.status <> 'pending' THEN
    RAISE EXCEPTION 'This submission is no longer pending.';
  END IF;
  IF v_submission.documents_purged_at IS NOT NULL OR
     v_submission.selfie_storage_path IS NULL OR
     v_submission.id_photo_storage_path IS NULL THEN
    RAISE EXCEPTION 'The review evidence is no longer available.';
  END IF;

  SELECT * INTO v_profile
  FROM public.profiles
  WHERE id = v_submission.profile_id
  FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Profile not found.';
  END IF;

  PERFORM public.admin_claim_work_item('kyc', v_submission.user_id);

  IF p_decision = 'approve' THEN
    IF NOT (
      p_document_readable AND
      p_name_match AND
      p_dob_match AND
      p_face_match AND
      p_document_unexpired
    ) THEN
      RAISE EXCEPTION 'Complete all five evidence checks before approval.';
    END IF;
    IF extract(year FROM age(v_profile.date_of_birth)) < 18 THEN
      RAISE EXCEPTION 'A minor cannot be approved.';
    END IF;

    UPDATE public.kyc_review_submissions
    SET status = 'approved',
        reviewed_at = now(),
        reviewed_by = auth.uid(),
        review_reason = nullif(v_reason, ''),
        review_checklist = jsonb_build_object(
          'document_readable', p_document_readable,
          'name_match', p_name_match,
          'dob_match', p_dob_match,
          'face_match', p_face_match,
          'document_unexpired', p_document_unexpired
        ),
        purge_after = now() + interval '30 days'
    WHERE id = v_submission.id;

    UPDATE public.profiles
    SET kyc_verified = true,
        kyc_method = 'manual_review_v1',
        kyc_assurance_level = 'manual_document_review',
        kyc_manual_review_id = v_submission.id,
        verification_status = 'verified',
        is_verified = true,
        verified_at = now()
    WHERE id = v_profile.id;

    PERFORM public.queue_notification(
      v_submission.user_id,
      'kyc_approved',
      'ID review complete',
      'Your identity document and selfie were reviewed by Silarah.',
      'silarah://profile'
    );
  ELSE
    IF length(v_reason) < 6 THEN
      RAISE EXCEPTION 'Choose a clear reason before requesting resubmission or rejecting.';
    END IF;

    UPDATE public.kyc_review_submissions
    SET status = CASE WHEN p_decision = 'resubmit' THEN 'resubmit' ELSE 'rejected' END,
        reviewed_at = now(),
        reviewed_by = auth.uid(),
        review_reason = v_reason,
        review_checklist = jsonb_build_object(
          'document_readable', p_document_readable,
          'name_match', p_name_match,
          'dob_match', p_dob_match,
          'face_match', p_face_match,
          'document_unexpired', p_document_unexpired
        ),
        purge_after = now() + interval '30 days'
    WHERE id = v_submission.id;

    UPDATE public.profiles
    SET kyc_verified = false,
        kyc_method = 'manual_review_v1',
        kyc_assurance_level = 'none',
        verification_status = CASE
          WHEN coalesce(has_verification_badge, false) THEN 'verified'
          ELSE 'unverified'
        END,
        is_verified = coalesce(has_verification_badge, false),
        verified_at = CASE
          WHEN coalesce(has_verification_badge, false) THEN verified_at
          ELSE NULL
        END
    WHERE id = v_profile.id;

    PERFORM public.queue_notification(
      v_submission.user_id,
      'kyc_rejected',
      CASE WHEN p_decision = 'resubmit'
        THEN 'New identity photos needed'
        ELSE 'Identity review not approved'
      END,
      v_reason,
      'silarah://verify-identity'
    );
  END IF;

  DELETE FROM public.admin_work_locks
  WHERE item_type = 'kyc'
    AND item_id = v_submission.user_id
    AND locked_by = auth.uid();

  INSERT INTO public.admin_audit_log (
    admin_id,
    actor_role,
    action_type,
    target_user_id,
    details
  ) VALUES (
    auth.uid(),
    public.current_admin_role(),
    'kyc_' || p_decision,
    v_submission.user_id,
    jsonb_build_object(
      'submission_id', v_submission.id,
      'reason', nullif(v_reason, ''),
      'review_checklist', jsonb_build_object(
        'document_readable', p_document_readable,
        'name_match', p_name_match,
        'dob_match', p_dob_match,
        'face_match', p_face_match,
        'document_unexpired', p_document_unexpired
      )
    )
  );
END;
$$;

REVOKE ALL ON FUNCTION public.admin_review_kyc(
  uuid, text, text, boolean, boolean, boolean, boolean, boolean
) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_review_kyc(
  uuid, text, text, boolean, boolean, boolean, boolean, boolean
) TO authenticated;

CREATE OR REPLACE FUNCTION public.lock_identity_during_kyc_review()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF (
    NEW.first_name IS DISTINCT FROM OLD.first_name OR
    NEW.last_name IS DISTINCT FROM OLD.last_name OR
    NEW.date_of_birth IS DISTINCT FROM OLD.date_of_birth
  ) AND EXISTS (
    SELECT 1
    FROM public.kyc_review_submissions s
    WHERE s.user_id = OLD.user_id AND s.status = 'pending'
  ) THEN
    RAISE EXCEPTION 'Name and date of birth cannot change while identity review is pending.';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_lock_identity_during_kyc_review ON public.profiles;
CREATE TRIGGER trg_lock_identity_during_kyc_review
BEFORE UPDATE OF first_name, last_name, date_of_birth ON public.profiles
FOR EACH ROW EXECUTE FUNCTION public.lock_identity_during_kyc_review();

-- Re-route every legacy client-approved KYC record to human review when the
-- evidence still exists. Preserve independently earned face/liveness badges.
INSERT INTO public.kyc_review_submissions (
  user_id,
  profile_id,
  status,
  country_code,
  id_type,
  client_face_similarity,
  selfie_storage_path,
  id_photo_storage_path,
  attempt_number,
  submitted_at,
  purge_after
)
SELECT
  p.user_id,
  p.id,
  'pending',
  p.country_code,
  CASE
    WHEN p.kyc_id_type IN ('government_id', 'national_id', 'passport', 'driving_license')
      THEN p.kyc_id_type
    ELSE 'government_id'
  END,
  CASE
    WHEN p.face_similarity BETWEEN 0 AND 1 THEN p.face_similarity
    WHEN p.face_similarity > 1 AND p.face_similarity <= 100 THEN p.face_similarity / 100.0
    ELSE NULL
  END,
  p.kyc_selfie_storage_path,
  p.kyc_id_photo_storage_path,
  1,
  coalesce(p.verified_at, p.created_at, now()),
  now() + interval '30 days'
FROM public.profiles p
WHERE p.kyc_method = 'on_device'
  AND p.kyc_selfie_storage_path IS NOT NULL
  AND p.kyc_id_photo_storage_path IS NOT NULL
  AND NOT EXISTS (
    SELECT 1 FROM public.kyc_review_submissions s
    WHERE s.user_id = p.user_id AND s.status = 'pending'
  );

UPDATE public.profiles p
SET kyc_verified = false,
    kyc_method = 'manual_review_v1',
    kyc_assurance_level = 'none',
    kyc_manual_review_id = s.id,
    verification_status = 'pending_review',
    is_verified = coalesce(p.has_verification_badge, false)
FROM public.kyc_review_submissions s
WHERE s.user_id = p.user_id
  AND s.status = 'pending'
  AND p.kyc_method = 'on_device';

UPDATE public.profiles
SET kyc_verified = false,
    kyc_method = 'manual_review_v1',
    kyc_assurance_level = 'none',
    verification_status = CASE
      WHEN coalesce(has_verification_badge, false) THEN 'verified'
      ELSE 'unverified'
    END,
    is_verified = coalesce(has_verification_badge, false),
    verified_at = CASE
      WHEN coalesce(has_verification_badge, false) THEN verified_at
      ELSE NULL
    END
WHERE kyc_method = 'on_device'
  AND kyc_manual_review_id IS NULL;

DO $$
BEGIN
  PERFORM cron.unschedule(jobid)
  FROM cron.job
  WHERE jobname = 'purge_kyc_documents_daily';
END;
$$;

SELECT cron.schedule(
  'purge_kyc_documents_daily',
  '45 3 * * *',
  $$
    SELECT net.http_post(
      url := current_setting('app.supabase_url', true) || '/functions/v1/purge-kyc-documents',
      body := '{}'::jsonb,
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'x-cron-secret', (
          SELECT decrypted_secret
          FROM vault.decrypted_secrets
          WHERE name = 'mithaq_edge_cron_secret'
        )
      )
    );
  $$
);
