-- Second audit: leased/idempotent KYC retention and referral concurrency.

ALTER TABLE public.kyc_review_submissions
  ADD COLUMN IF NOT EXISTS purge_status text NOT NULL DEFAULT 'pending',
  ADD COLUMN IF NOT EXISTS purge_claimed_at timestamptz,
  ADD COLUMN IF NOT EXISTS purge_attempts integer NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS purge_last_error text,
  ADD COLUMN IF NOT EXISTS selfie_purge_status text NOT NULL DEFAULT 'pending',
  ADD COLUMN IF NOT EXISTS id_photo_purge_status text NOT NULL DEFAULT 'pending',
  ADD COLUMN IF NOT EXISTS selfie_purge_error text,
  ADD COLUMN IF NOT EXISTS id_photo_purge_error text;

ALTER TABLE public.kyc_review_submissions
  DROP CONSTRAINT IF EXISTS kyc_review_submissions_purge_status_check;
ALTER TABLE public.kyc_review_submissions
  ADD CONSTRAINT kyc_review_submissions_purge_status_check
  CHECK (purge_status IN ('pending', 'deleting', 'failed', 'completed'));
ALTER TABLE public.kyc_review_submissions
  DROP CONSTRAINT IF EXISTS kyc_review_submissions_selfie_purge_status_check;
ALTER TABLE public.kyc_review_submissions
  ADD CONSTRAINT kyc_review_submissions_selfie_purge_status_check
  CHECK (selfie_purge_status IN ('pending', 'deleting', 'deleted', 'failed'));
ALTER TABLE public.kyc_review_submissions
  DROP CONSTRAINT IF EXISTS kyc_review_submissions_id_purge_status_check;
ALTER TABLE public.kyc_review_submissions
  ADD CONSTRAINT kyc_review_submissions_id_purge_status_check
  CHECK (id_photo_purge_status IN ('pending', 'deleting', 'deleted', 'failed'));

CREATE OR REPLACE FUNCTION public.checkout_kyc_document_purges(
  p_limit integer DEFAULT 5
)
RETURNS TABLE(
  id uuid,
  user_id uuid,
  profile_id uuid,
  status text,
  selfie_storage_path text,
  id_photo_storage_path text,
  selfie_purge_status text,
  id_photo_purge_status text
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
    SELECT s.id
    FROM public.kyc_review_submissions s
    WHERE s.documents_purged_at IS NULL
      AND s.purge_after <= now()
      AND s.purge_attempts < 10
      AND (
        s.purge_status IN ('pending', 'failed')
        OR (
          s.purge_status = 'deleting'
          AND s.purge_claimed_at < now() - interval '10 minutes'
        )
      )
    ORDER BY s.purge_after, s.id
    FOR UPDATE SKIP LOCKED
    LIMIT least(greatest(p_limit, 1), 5)
  ), claimed AS (
    UPDATE public.kyc_review_submissions s
    SET purge_status = 'deleting',
        purge_claimed_at = now(),
        purge_attempts = s.purge_attempts + 1,
        purge_last_error = NULL,
        selfie_purge_status = CASE
          WHEN s.selfie_purge_status = 'deleted' THEN 'deleted'
          ELSE 'deleting'
        END,
        id_photo_purge_status = CASE
          WHEN s.id_photo_purge_status = 'deleted' THEN 'deleted'
          ELSE 'deleting'
        END
    FROM candidates c
    WHERE s.id = c.id
    RETURNING s.*
  )
  SELECT
    c.id,
    c.user_id,
    c.profile_id,
    c.status,
    c.selfie_storage_path,
    c.id_photo_storage_path,
    c.selfie_purge_status,
    c.id_photo_purge_status
  FROM claimed c;
END;
$$;
REVOKE ALL ON FUNCTION public.checkout_kyc_document_purges(integer)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.checkout_kyc_document_purges(integer)
  TO service_role;

CREATE OR REPLACE FUNCTION public.record_kyc_purge_object_result(
  p_submission_id uuid,
  p_object_kind text,
  p_success boolean,
  p_error text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  IF auth.role() <> 'service_role'
    OR p_object_kind NOT IN ('selfie', 'id_photo') THEN
    RAISE EXCEPTION 'invalid_kyc_purge_result' USING ERRCODE = 'P0001';
  END IF;

  UPDATE public.kyc_review_submissions
  SET selfie_purge_status = CASE
        WHEN p_object_kind = 'selfie'
          THEN CASE WHEN p_success THEN 'deleted' ELSE 'failed' END
        ELSE selfie_purge_status
      END,
      selfie_purge_error = CASE
        WHEN p_object_kind = 'selfie' AND NOT p_success
          THEN left(coalesce(p_error, 'storage_delete_failed'), 300)
        WHEN p_object_kind = 'selfie' THEN NULL
        ELSE selfie_purge_error
      END,
      id_photo_purge_status = CASE
        WHEN p_object_kind = 'id_photo'
          THEN CASE WHEN p_success THEN 'deleted' ELSE 'failed' END
        ELSE id_photo_purge_status
      END,
      id_photo_purge_error = CASE
        WHEN p_object_kind = 'id_photo' AND NOT p_success
          THEN left(coalesce(p_error, 'storage_delete_failed'), 300)
        WHEN p_object_kind = 'id_photo' THEN NULL
        ELSE id_photo_purge_error
      END
  WHERE id = p_submission_id
    AND documents_purged_at IS NULL
    AND purge_status = 'deleting';
END;
$$;
REVOKE ALL ON FUNCTION public.record_kyc_purge_object_result(
  uuid, text, boolean, text
) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.record_kyc_purge_object_result(
  uuid, text, boolean, text
) TO service_role;

CREATE OR REPLACE FUNCTION public.finish_kyc_document_purge(
  p_submission_id uuid
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_submission public.kyc_review_submissions%ROWTYPE;
  v_expired boolean;
BEGIN
  IF auth.role() <> 'service_role' THEN
    RAISE EXCEPTION 'service_role_required' USING ERRCODE = 'P0001';
  END IF;

  SELECT * INTO v_submission
  FROM public.kyc_review_submissions
  WHERE id = p_submission_id
  FOR UPDATE;
  IF NOT FOUND THEN RETURN false; END IF;
  IF v_submission.documents_purged_at IS NOT NULL THEN RETURN true; END IF;

  IF v_submission.selfie_purge_status <> 'deleted'
    OR v_submission.id_photo_purge_status <> 'deleted' THEN
    UPDATE public.kyc_review_submissions
    SET purge_status = 'failed',
        purge_last_error = 'one_or_more_objects_not_deleted'
    WHERE id = p_submission_id;
    RETURN false;
  END IF;

  v_expired := v_submission.status = 'pending';
  UPDATE public.kyc_review_submissions
  SET status = CASE WHEN v_expired THEN 'expired' ELSE status END,
      review_reason = CASE
        WHEN v_expired
          THEN 'The private evidence reached its retention limit before review.'
        ELSE review_reason
      END,
      selfie_storage_path = NULL,
      id_photo_storage_path = NULL,
      documents_purged_at = now(),
      purge_status = 'completed',
      purge_claimed_at = NULL,
      purge_last_error = NULL
  WHERE id = p_submission_id;

  UPDATE public.profiles
  SET kyc_verified = CASE WHEN v_expired THEN false ELSE kyc_verified END,
      kyc_assurance_level = CASE
        WHEN v_expired THEN 'none'
        ELSE kyc_assurance_level
      END,
      verification_status = CASE
        WHEN v_expired AND has_verification_badge THEN 'verified'
        WHEN v_expired THEN 'unverified'
        ELSE verification_status
      END,
      is_verified = CASE
        WHEN v_expired THEN coalesce(has_verification_badge, false)
        ELSE is_verified
      END,
      kyc_selfie_storage_path = NULL,
      kyc_id_photo_storage_path = NULL
  WHERE id = v_submission.profile_id
    AND kyc_manual_review_id = v_submission.id;

  IF v_expired THEN
    PERFORM public.queue_notification(
      v_submission.user_id,
      'kyc_rejected',
      'Submit your ID check again',
      'Your private identity images expired before review and were deleted. Please submit a new selfie and document.',
      'silarah://verify-identity'
    );
  END IF;
  RETURN true;
END;
$$;
REVOKE ALL ON FUNCTION public.finish_kyc_document_purge(uuid)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.finish_kyc_document_purge(uuid)
  TO service_role;

CREATE OR REPLACE FUNCTION public.apply_referral_code(p_code text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_referred_id uuid := private.assert_authenticated();
  v_referrer_id uuid;
  v_inserted boolean := false;
BEGIN
  SELECT owner_id INTO v_referrer_id
  FROM public.referral_codes
  WHERE code = upper(trim(coalesce(p_code, '')));
  IF v_referrer_id IS NULL THEN
    RETURN jsonb_build_object('status', 'invalid_code');
  END IF;
  IF v_referrer_id = v_referred_id THEN
    RETURN jsonb_build_object('status', 'self_referral');
  END IF;

  WITH inserted AS (
    INSERT INTO public.referrals(referrer_id, referred_id)
    VALUES (v_referrer_id, v_referred_id)
    ON CONFLICT (referred_id) DO NOTHING
    RETURNING 1
  )
  SELECT EXISTS (SELECT 1 FROM inserted) INTO v_inserted;

  IF NOT v_inserted THEN
    RETURN jsonb_build_object('status', 'already_referred');
  END IF;

  UPDATE public.referral_codes
  SET uses_count = uses_count + 1
  WHERE owner_id = v_referrer_id;
  RETURN jsonb_build_object(
    'status', 'applied',
    'referrer_id', v_referrer_id
  );
END;
$$;
REVOKE ALL ON FUNCTION public.apply_referral_code(text)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.apply_referral_code(text)
  TO authenticated;
