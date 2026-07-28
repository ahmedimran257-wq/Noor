-- A device-only passive face scan is a UX readiness check, not independent
-- identity evidence. It must never set public verification or KYC state.
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS photo_liveness_check_completed boolean
    NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS photo_liveness_check_completed_at timestamptz;

UPDATE public.profiles p
SET photo_liveness_check_completed = true,
    photo_liveness_check_completed_at = coalesce(verified_at, now()),
    has_verification_badge = false,
    badge_earned_at = NULL,
    verification_status = 'unverified',
    verified_at = NULL,
    is_verified = false
WHERE p.verification_challenge = 'passive_face_scan'
  AND coalesce(
    (
      SELECT k.status
      FROM private.current_kyc_status(p.user_id) k
    ),
    'not_started'
  ) <> 'approved';

CREATE OR REPLACE FUNCTION public.submit_my_photo_badge_verification()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_user_id uuid := private.assert_authenticated();
BEGIN
  UPDATE public.profiles
  SET photo_liveness_check_completed = true,
      photo_liveness_check_completed_at = now(),
      verification_challenge = 'passive_face_scan'
  WHERE user_id = v_user_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.get_my_photo_liveness_status()
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = ''
AS $$
  SELECT coalesce(p.photo_liveness_check_completed, false)
  FROM public.profiles p
  WHERE p.user_id = private.assert_authenticated()
$$;

REVOKE ALL ON FUNCTION public.submit_my_photo_badge_verification()
  FROM PUBLIC;
REVOKE ALL ON FUNCTION public.get_my_photo_liveness_status()
  FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.submit_my_photo_badge_verification()
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_my_photo_liveness_status()
  TO authenticated;
