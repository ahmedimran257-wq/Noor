-- Retire DigiLocker completely. Identity verification now consists only of a
-- clear selfie plus government-ID photos reviewed by authorized staff.

UPDATE public.profiles
SET kyc_verified = false,
    kyc_method = NULL,
    kyc_assurance_level = 'none',
    kyc_evidence_id = NULL,
    verified_at = CASE
      WHEN coalesce(has_verification_badge, false) THEN verified_at
      ELSE NULL
    END,
    verification_status = CASE
      WHEN coalesce(has_verification_badge, false) THEN 'verified'
      ELSE 'unverified'
    END,
    is_verified = coalesce(has_verification_badge, false)
WHERE coalesce(kyc_method, '') LIKE 'digilocker%';

CREATE OR REPLACE FUNCTION private.current_kyc_status(p_user_id uuid)
RETURNS TABLE(
  status text,
  method text,
  assurance_level text,
  submitted_at timestamptz,
  reviewed_at timestamptz,
  reason text,
  can_submit boolean
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT
    CASE
      WHEN coalesce(p.kyc_verified, false)
        AND coalesce(p.kyc_method, '') = 'manual_review_v1'
        THEN 'approved'
      WHEN latest.status = 'pending' THEN 'pending_review'
      WHEN latest.status = 'approved' THEN 'approved'
      WHEN latest.status = 'rejected' THEN 'rejected'
      WHEN latest.status = 'resubmit' THEN 'resubmit_required'
      WHEN latest.status = 'expired' THEN 'expired'
      ELSE 'not_started'
    END::text,
    CASE
      WHEN latest.status IS NOT NULL THEN 'manual_review_v1'
      ELSE NULL
    END::text,
    CASE
      WHEN latest.status = 'approved'
        OR (
          coalesce(p.kyc_verified, false)
          AND coalesce(p.kyc_method, '') = 'manual_review_v1'
        )
        THEN 'manual_document_review'
      ELSE 'none'
    END::text,
    latest.submitted_at,
    latest.reviewed_at,
    latest.review_reason::text,
    (
      NOT (
        coalesce(p.kyc_verified, false)
        AND coalesce(p.kyc_method, '') = 'manual_review_v1'
      )
      AND coalesce(latest.status, '') <> 'pending'
    )::boolean
  FROM public.profiles AS p
  LEFT JOIN LATERAL (
    SELECT
      submission.status::text,
      submission.submitted_at,
      submission.reviewed_at,
      submission.review_reason
    FROM public.kyc_review_submissions AS submission
    WHERE submission.user_id = p_user_id
    ORDER BY coalesce(submission.reviewed_at, submission.submitted_at) DESC
    LIMIT 1
  ) AS latest ON true
  WHERE p.user_id = p_user_id;
$$;

COMMENT ON FUNCTION private.current_kyc_status(uuid) IS
  'Authoritative manual selfie plus government-ID review lifecycle.';

DROP FUNCTION IF EXISTS public.record_digilocker_verification_result(
  uuid, text, text, text, text, text, text, text, text, text, text, text,
  boolean, boolean, boolean, boolean, boolean, boolean, boolean, timestamptz,
  jsonb
);

DROP VIEW IF EXISTS public.my_profile_private;
ALTER TABLE public.profiles DROP COLUMN IF EXISTS kyc_evidence_id;

CREATE OR REPLACE FUNCTION public.get_my_profile_private_rows()
RETURNS SETOF public.profiles
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT p.*
  FROM public.profiles AS p
  WHERE auth.uid() IS NOT NULL
    AND p.user_id = auth.uid();
$$;

REVOKE ALL ON FUNCTION public.get_my_profile_private_rows()
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_my_profile_private_rows()
  TO authenticated;

CREATE VIEW public.my_profile_private
WITH (security_invoker = true, security_barrier = true)
AS
SELECT row_data.*
FROM public.get_my_profile_private_rows() AS row_data;

REVOKE ALL ON public.my_profile_private FROM PUBLIC, anon;
GRANT SELECT ON public.my_profile_private TO authenticated;

DROP TABLE IF EXISTS public.identity_verification_evidence;

CREATE OR REPLACE FUNCTION public.record_edge_function_result(
  p_function_name text,
  p_success boolean,
  p_error text DEFAULT NULL,
  p_details jsonb DEFAULT '{}'::jsonb
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  IF p_function_name NOT IN (
    'dispatch-notifications',
    'get-signed-url',
    'validate-photo-upload',
    'translate-message',
    'process-kyc'
  ) THEN
    RAISE EXCEPTION 'Unknown Edge Function health key';
  END IF;

  INSERT INTO private.edge_function_health AS health (
    function_name,
    last_success_at,
    last_failure_at,
    consecutive_failures,
    last_error,
    last_details,
    updated_at
  )
  VALUES (
    p_function_name,
    CASE WHEN p_success THEN now() ELSE NULL END,
    CASE WHEN p_success THEN NULL ELSE now() END,
    CASE WHEN p_success THEN 0 ELSE 1 END,
    CASE WHEN p_success THEN NULL ELSE left(coalesce(p_error, 'Unknown failure'), 1000) END,
    coalesce(p_details, '{}'::jsonb),
    now()
  )
  ON CONFLICT (function_name) DO UPDATE
  SET last_success_at = CASE
        WHEN p_success THEN now()
        ELSE health.last_success_at
      END,
      last_failure_at = CASE
        WHEN p_success THEN health.last_failure_at
        ELSE now()
      END,
      consecutive_failures = CASE
        WHEN p_success THEN 0
        ELSE health.consecutive_failures + 1
      END,
      last_error = CASE
        WHEN p_success THEN NULL
        ELSE left(coalesce(p_error, 'Unknown failure'), 1000)
      END,
      last_details = coalesce(p_details, '{}'::jsonb),
      updated_at = now();
END;
$$;

REVOKE ALL ON FUNCTION public.record_edge_function_result(text, boolean, text, jsonb)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.record_edge_function_result(text, boolean, text, jsonb)
  TO service_role;

DELETE FROM private.edge_function_health
WHERE function_name = 'digilocker-verify';
