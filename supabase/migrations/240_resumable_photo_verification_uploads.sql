-- An interrupted upload must never trap a member behind a timer. The trusted
-- Edge Function calls this before a replacement attempt and after any client
-- upload failure. Pending human-review submissions are deliberately immutable.
CREATE OR REPLACE FUNCTION public.abandon_photo_verification_upload(
  p_user_id uuid,
  p_submission_id uuid DEFAULT NULL
)
RETURNS text[]
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_paths text[] := ARRAY[]::text[];
BEGIN
  IF auth.role() <> 'service_role' THEN
    RAISE EXCEPTION 'service_role_required' USING ERRCODE = 'P0001';
  END IF;
  IF p_user_id IS NULL THEN
    RAISE EXCEPTION 'invalid_user' USING ERRCODE = '22023';
  END IF;

  PERFORM pg_advisory_xact_lock(hashtextextended(p_user_id::text, 206));

  -- Lock the submission rows separately. PostgreSQL does not permit every
  -- row-locking clause shape around a set-returning unnest projection, and
  -- the advisory lock already serializes replacement starts for this user.
  PERFORM 1
  FROM public.photo_verification_submissions
  WHERE user_id = p_user_id
    AND status = 'uploading'
    AND (p_submission_id IS NULL OR id = p_submission_id)
  FOR UPDATE;

  SELECT coalesce(array_agg(path), ARRAY[]::text[])
  INTO v_paths
  FROM (
    SELECT unnest(ARRAY[
      neutral_storage_path,
      smile_storage_path,
      blink_storage_path
    ]) AS path
    FROM public.photo_verification_submissions
    WHERE user_id = p_user_id
      AND status = 'uploading'
      AND (p_submission_id IS NULL OR id = p_submission_id)
  ) pending_paths
  WHERE path IS NOT NULL
    AND path LIKE p_user_id::text || '/%';

  UPDATE public.photo_verification_submissions
  SET status = 'expired',
      review_reason = 'Upload was cancelled or replaced before submission.',
      purge_after = least(purge_after, now()),
      neutral_storage_path = NULL,
      smile_storage_path = NULL,
      blink_storage_path = NULL,
      captures_purged_at = now()
  WHERE user_id = p_user_id
    AND status = 'uploading'
    AND (p_submission_id IS NULL OR id = p_submission_id);

  RETURN v_paths;
END;
$$;

REVOKE ALL ON FUNCTION public.abandon_photo_verification_upload(uuid, uuid)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.abandon_photo_verification_upload(uuid, uuid)
  TO service_role;

COMMENT ON FUNCTION public.abandon_photo_verification_upload(uuid, uuid) IS
  'Service-only recovery for unfinished photo-check uploads. It never cancels a pending review.';
