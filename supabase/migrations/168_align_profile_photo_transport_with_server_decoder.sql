-- Align the profile-photo transport with the server-side decoder.
--
-- ImageScript 1.2.15 can independently decode JPEG but not WebP. Requiring
-- JPEG here keeps the reservation, signed upload, byte signature, decoder and
-- finalization MIME checks on one enforceable contract.

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

  IF p_user_id IS NULL
    OR p_storage_path !~ (
      '^' || p_user_id::text || '/[A-Za-z0-9_-]+[.](webp|jpg)$'
    )
    OR p_purpose NOT IN (
      'profile_photo',
      'kyc_selfie',
      'kyc_id',
      'badge_selfie'
    )
    OR p_max_bytes NOT BETWEEN 1 AND 10485760 THEN
    RAISE EXCEPTION 'invalid_upload_reservation' USING ERRCODE = 'P0001';
  END IF;

  PERFORM pg_advisory_xact_lock(
    hashtextextended(
      p_user_id::text || ':' || coalesce(p_order_index::text, p_purpose),
      76
    )
  );

  IF p_purpose = 'profile_photo' THEN
    IF p_bucket_id <> 'profile-photos'
      OR p_order_index NOT BETWEEN 0 AND 3
      OR p_expected_mime <> 'image/jpeg' THEN
      RAISE EXCEPTION 'invalid_profile_upload_contract'
        USING ERRCODE = 'P0001';
    END IF;

    SELECT id INTO v_profile_id
    FROM public.profiles
    WHERE user_id = p_user_id;

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
      SELECT 1
      FROM public.photos
      WHERE profile_id = v_profile_id
        AND order_index = p_order_index
        AND status = 'pending_review'
    ) THEN
      RAISE EXCEPTION 'photo_review_already_pending'
        USING ERRCODE = 'P0001';
    END IF;

    IF v_replaced IS NULL AND (
      SELECT count(*)
      FROM public.photos
      WHERE profile_id = v_profile_id
        AND status = 'active'
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
      OR p_expected_mime NOT IN ('image/webp', 'image/jpeg') THEN
      RAISE EXCEPTION 'invalid_identity_upload_contract'
        USING ERRCODE = 'P0001';
    END IF;
  END IF;

  INSERT INTO private.upload_reservations(
    user_id,
    profile_id,
    bucket_id,
    purpose,
    order_index,
    storage_path,
    expected_mime,
    max_bytes,
    replaced_photo_id
  )
  VALUES (
    p_user_id,
    v_profile_id,
    p_bucket_id,
    p_purpose,
    p_order_index,
    p_storage_path,
    p_expected_mime,
    p_max_bytes,
    v_replaced
  )
  RETURNING id INTO v_id;

  RETURN QUERY SELECT v_id, v_replaced;
END;
$$;

REVOKE ALL ON FUNCTION public.reserve_upload(
  uuid,
  text,
  text,
  text,
  text,
  integer,
  integer
) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.reserve_upload(
  uuid,
  text,
  text,
  text,
  text,
  integer,
  integer
) TO service_role;
