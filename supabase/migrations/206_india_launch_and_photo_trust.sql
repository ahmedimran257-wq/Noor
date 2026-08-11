-- India-first launch and privacy-minimizing profile-photo verification.
--
-- Verification captures are temporary review evidence, never identity
-- documents or biometric templates. The server is the only authority that can
-- create a submission, grant a badge, or mark capture deletion complete.

-- ---------------------------------------------------------------------------
-- 1. Server-driven launch markets. Enabling a second row restores the global
--    product without requiring a mobile release.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.launch_countries (
  country_code varchar(2) PRIMARY KEY
    REFERENCES public.countries(iso_code) ON DELETE CASCADE,
  enabled boolean NOT NULL DEFAULT false,
  enabled_at timestamptz,
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT launch_countries_uppercase
    CHECK (country_code = upper(country_code))
);

INSERT INTO public.launch_countries(country_code, enabled, enabled_at)
SELECT c.iso_code, c.iso_code = 'IN',
       CASE WHEN c.iso_code = 'IN' THEN now() ELSE NULL END
FROM public.countries c
ON CONFLICT (country_code) DO UPDATE
SET enabled = EXCLUDED.enabled,
    enabled_at = CASE
      WHEN EXCLUDED.enabled THEN coalesce(public.launch_countries.enabled_at, now())
      ELSE NULL
    END,
    updated_at = now();

ALTER TABLE public.launch_countries ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.launch_countries FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.get_launch_configuration()
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT jsonb_build_object(
    'market_mode', CASE WHEN count(*) = 1 THEN 'single_country' ELSE 'global' END,
    'enabled_countries', coalesce(
      jsonb_agg(lc.country_code ORDER BY c.display_priority DESC, c.name),
      '[]'::jsonb
    ),
    'default_country', CASE
      WHEN bool_or(lc.country_code = 'IN') THEN 'IN'
      ELSE min(lc.country_code)
    END,
    'country_count', count(*)
  )
  FROM public.launch_countries lc
  JOIN public.countries c ON c.iso_code = lc.country_code
  WHERE lc.enabled = true;
$$;

REVOKE ALL ON FUNCTION public.get_launch_configuration() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_launch_configuration() TO anon, authenticated;

-- Keep the pre-auth consent transaction in lockstep with the published policy
-- bundle. A mismatch here would reject every new signup at the legal gate.
CREATE OR REPLACE FUNCTION public.begin_signup_consent_transaction(
  p_policy_version text,
  p_acceptances jsonb
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_id uuid;
  v_required constant text[] := ARRAY[
    'terms_of_service',
    'privacy_policy',
    'community_guidelines',
    'age_verification',
    'special_category_religious'
  ];
  v_key text;
BEGIN
  IF trim(coalesce(p_policy_version, '')) <> '2.1.0'
    OR jsonb_typeof(p_acceptances) <> 'object'
    OR (SELECT count(*) FROM jsonb_object_keys(p_acceptances)) <> 5 THEN
    RAISE EXCEPTION 'invalid_consent_transaction' USING ERRCODE = 'P0001';
  END IF;
  FOREACH v_key IN ARRAY v_required LOOP
    IF p_acceptances ->> v_key <> 'true' THEN
      RAISE EXCEPTION 'required_consent_missing' USING ERRCODE = 'P0001';
    END IF;
  END LOOP;
  INSERT INTO private.signup_consent_transactions(policy_version, acceptances)
  VALUES ('2.1.0', p_acceptances)
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;

REVOKE ALL ON FUNCTION public.begin_signup_consent_transaction(text, jsonb)
  FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.begin_signup_consent_transaction(text, jsonb)
  TO anon, authenticated;

-- The catalogue is also an authoritative signup boundary. This trigger allows
-- an empty country on an account shell, but no client (including an outdated
-- build) can persist a disabled market on users or profiles.
CREATE OR REPLACE FUNCTION private.enforce_enabled_launch_country()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_country_code text := upper(trim(coalesce(NEW.country_code::text, '')));
BEGIN
  IF v_country_code = '' THEN
    RETURN NEW;
  END IF;
  IF NOT EXISTS (
    SELECT 1
    FROM public.launch_countries market
    WHERE market.country_code = v_country_code
      AND market.enabled = true
  ) THEN
    RAISE EXCEPTION 'launch_country_unavailable'
      USING ERRCODE = 'P0001';
  END IF;
  NEW.country_code := v_country_code;
  RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION private.enforce_enabled_launch_country() FROM PUBLIC;

DROP TRIGGER IF EXISTS trg_enforce_user_launch_country ON public.users;
CREATE TRIGGER trg_enforce_user_launch_country
BEFORE INSERT OR UPDATE OF country_code ON public.users
FOR EACH ROW EXECUTE FUNCTION private.enforce_enabled_launch_country();

DROP TRIGGER IF EXISTS trg_enforce_profile_launch_country ON public.profiles;
CREATE TRIGGER trg_enforce_profile_launch_country
BEFORE INSERT OR UPDATE OF country_code ON public.profiles
FOR EACH ROW EXECUTE FUNCTION private.enforce_enabled_launch_country();

-- Candidates outside enabled launch markets cannot leak through an old app or
-- a hand-crafted discovery request.
CREATE OR REPLACE VIEW public.live_discovery_pool
WITH (security_invoker = true)
AS
SELECT
  p.id AS profile_id,
  p.user_id,
  p.gender,
  p.first_name,
  p.last_name AS last_name_initial,
  extract(year FROM age(p.date_of_birth))::integer AS age,
  c.name AS city_name,
  p.country_code,
  p.city_id,
  p.sect::text AS sect,
  p.deen_level::text AS deen_level,
  p.profession,
  p.bio,
  CASE WHEN p.photo_privacy = 'public' THEN primary_photo.storage_path END
    AS photo_url,
  photo_totals.photo_count,
  p.photo_privacy::text AS photo_privacy,
  p.is_verified,
  p.location,
  p.static_rank_score AS rank_score,
  p.marriage_timeline,
  p.height_cm,
  p.complexion,
  p.mother_tongue,
  p.smoking_habit,
  p.community,
  p.diet_type,
  p.living_expectation,
  p.quran_memorization,
  p.religious_education,
  p.willing_to_relocate,
  p.previously_married,
  p.family_type,
  p.children_count,
  p.education_rank,
  prefs.preferred_age_min,
  prefs.preferred_age_max,
  p.last_active_at,
  CASE WHEN p.photo_privacy = 'public' THEN primary_photo.blurhash END
    AS blurhash
FROM public.profiles p
JOIN public.users account ON account.id = p.user_id
JOIN public.launch_countries market
  ON market.country_code = upper(p.country_code::text)
 AND market.enabled = true
LEFT JOIN public.cities c ON c.id = p.city_id
LEFT JOIN public.profile_preferences prefs ON prefs.profile_id = p.id
JOIN LATERAL (
  SELECT count(*)::integer AS photo_count
  FROM public.photos ph
  WHERE ph.profile_id = p.id
    AND ph.status = 'active'
    AND ph.admin_approved = true
    AND ph.nsfw_cleared = true
) photo_totals ON photo_totals.photo_count > 0
JOIN LATERAL (
  SELECT ph.id, ph.storage_path, ph.blurhash
  FROM public.photos ph
  WHERE ph.profile_id = p.id
    AND ph.order_index = 0
    AND ph.status = 'active'
    AND ph.admin_approved = true
    AND ph.nsfw_cleared = true
  ORDER BY ph.created_at DESC
  LIMIT 1
) primary_photo ON true
WHERE p.visibility = 'visible'
  AND p.onboarding_completed = true
  AND p.approved_at IS NOT NULL
  AND account.deleted_at IS NULL
  AND coalesce(account.is_banned, false) = false
  AND coalesce(account.is_shadowbanned, false) = false;

REVOKE ALL ON public.live_discovery_pool FROM PUBLIC, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 2. Temporary profile-photo review evidence.
-- ---------------------------------------------------------------------------
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS photo_verified_at timestamptz,
  ADD COLUMN IF NOT EXISTS photo_verification_submission_id uuid,
  ADD COLUMN IF NOT EXISTS photo_verification_paused_at timestamptz,
  ADD COLUMN IF NOT EXISTS photo_verification_pause_reason text;

CREATE TABLE IF NOT EXISTS public.photo_verification_submissions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  profile_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  primary_photo_id uuid NOT NULL REFERENCES public.photos(id) ON DELETE RESTRICT,
  neutral_storage_path text,
  smile_storage_path text,
  blink_storage_path text,
  status text NOT NULL DEFAULT 'uploading'
    CHECK (status IN (
      'uploading', 'pending', 'approved', 'resubmit', 'rejected',
      'expired', 'revoked'
    )),
  guidance_mode text NOT NULL DEFAULT 'smile_blink_v1'
    CHECK (guidance_mode IN ('smile_blink_v1', 'manual_accessibility_v1')),
  submitted_at timestamptz,
  review_deadline timestamptz NOT NULL DEFAULT (now() + interval '48 hours'),
  reviewed_at timestamptz,
  reviewed_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  review_reason text,
  review_checklist jsonb NOT NULL DEFAULT '{}'::jsonb,
  purge_after timestamptz NOT NULL DEFAULT (now() + interval '47 hours 50 minutes'),
  purge_status text NOT NULL DEFAULT 'pending'
    CHECK (purge_status IN ('pending', 'deleting', 'failed', 'completed')),
  purge_claimed_at timestamptz,
  purge_attempts integer NOT NULL DEFAULT 0 CHECK (purge_attempts >= 0),
  purge_last_error text,
  captures_purged_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT photo_verification_deadline_bound CHECK (
    review_deadline <= created_at + interval '48 hours'
    AND purge_after <= created_at + interval '48 hours'
  ),
  CONSTRAINT photo_verification_paths_scoped CHECK (
    (neutral_storage_path IS NULL OR neutral_storage_path LIKE user_id::text || '/%')
    AND (smile_storage_path IS NULL OR smile_storage_path LIKE user_id::text || '/%')
    AND (blink_storage_path IS NULL OR blink_storage_path LIKE user_id::text || '/%')
  )
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_photo_verification_one_open
  ON public.photo_verification_submissions(user_id)
  WHERE status IN ('uploading', 'pending');
CREATE INDEX IF NOT EXISTS idx_photo_verification_review_queue
  ON public.photo_verification_submissions(submitted_at, id)
  WHERE status = 'pending' AND captures_purged_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_photo_verification_purge_queue
  ON public.photo_verification_submissions(purge_after, id)
  WHERE captures_purged_at IS NULL;

-- Preserve the cheap cached admin snapshots while replacing their retired KYC
-- counter at read time with the authoritative photo-review queue count.
CREATE OR REPLACE FUNCTION public.admin_dashboard_metrics()
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT CASE WHEN public.is_active_admin() THEN (
    SELECT (snapshot.payload - 'pendingKyc') || jsonb_build_object(
      'pendingPhotoChecks', (
        SELECT count(*)
        FROM public.photo_verification_submissions submission
        WHERE submission.status = 'pending'
          AND submission.reviewed_at IS NULL
      )
    )
    FROM private.admin_metric_snapshots snapshot
    WHERE snapshot.metric_name = 'dashboard'
  ) ELSE NULL END;
$$;

CREATE OR REPLACE FUNCTION public.admin_system_health()
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT CASE WHEN public.is_active_admin() THEN (
    SELECT (snapshot.payload - 'pendingKyc') || jsonb_build_object(
      'pendingPhotoChecks', (
        SELECT count(*)
        FROM public.photo_verification_submissions submission
        WHERE submission.status = 'pending'
          AND submission.reviewed_at IS NULL
      )
    )
    FROM private.admin_metric_snapshots snapshot
    WHERE snapshot.metric_name = 'system_health'
  ) ELSE NULL END;
$$;

REVOKE ALL ON FUNCTION public.admin_dashboard_metrics() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_system_health() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_dashboard_metrics() TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_system_health() TO authenticated;

ALTER TABLE public.photo_verification_submissions ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.photo_verification_submissions
  FROM PUBLIC, anon, authenticated;

ALTER TABLE public.profiles
  DROP CONSTRAINT IF EXISTS profiles_photo_verification_submission_id_fkey;
ALTER TABLE public.profiles
  ADD CONSTRAINT profiles_photo_verification_submission_id_fkey
  FOREIGN KEY (photo_verification_submission_id)
  REFERENCES public.photo_verification_submissions(id) ON DELETE SET NULL;

INSERT INTO storage.buckets(id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'photo-verification-captures',
  'photo-verification-captures',
  false,
  2097152,
  ARRAY['image/jpeg']::text[]
)
ON CONFLICT (id) DO UPDATE
SET public = false,
    file_size_limit = EXCLUDED.file_size_limit,
    allowed_mime_types = EXCLUDED.allowed_mime_types;

CREATE OR REPLACE FUNCTION public.start_photo_verification_submission(
  p_user_id uuid,
  p_neutral_path text,
  p_smile_path text,
  p_blink_path text,
  p_guidance_mode text DEFAULT 'smile_blink_v1'
)
RETURNS TABLE(submission_id uuid, review_deadline timestamptz)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_profile_id uuid;
  v_primary_photo_id uuid;
  v_submission_id uuid;
  v_deadline timestamptz := now() + interval '48 hours';
  v_active_verification boolean := false;
BEGIN
  IF auth.role() <> 'service_role' THEN
    RAISE EXCEPTION 'service_role_required' USING ERRCODE = 'P0001';
  END IF;
  IF p_user_id IS NULL
    OR p_guidance_mode NOT IN ('smile_blink_v1', 'manual_accessibility_v1')
    OR p_neutral_path !~ ('^' || p_user_id::text || '/[A-Za-z0-9_-]+[.]jpg$')
    OR p_smile_path !~ ('^' || p_user_id::text || '/[A-Za-z0-9_-]+[.]jpg$')
    OR p_blink_path !~ ('^' || p_user_id::text || '/[A-Za-z0-9_-]+[.]jpg$')
    OR cardinality(ARRAY[p_neutral_path, p_smile_path, p_blink_path]) <> 3
    OR (SELECT count(DISTINCT path) FROM unnest(
      ARRAY[p_neutral_path, p_smile_path, p_blink_path]
    ) path) <> 3 THEN
    RAISE EXCEPTION 'invalid_photo_verification_submission'
      USING ERRCODE = '22023';
  END IF;

  PERFORM pg_advisory_xact_lock(hashtextextended(p_user_id::text, 206));

  SELECT p.id, ph.id,
         (p.photo_verified_at IS NOT NULL
          AND p.photo_verification_paused_at IS NULL)
  INTO v_profile_id, v_primary_photo_id, v_active_verification
  FROM public.profiles p
  JOIN public.photos ph ON ph.profile_id = p.id
  WHERE p.user_id = p_user_id
    AND p.visibility NOT IN ('suspended', 'deactivated')
    AND ph.order_index = 0
    AND ph.status = 'active'
    AND ph.admin_approved = true
    AND ph.nsfw_cleared = true
  ORDER BY ph.created_at DESC
  LIMIT 1;
  IF v_profile_id IS NULL OR v_primary_photo_id IS NULL THEN
    RAISE EXCEPTION 'approved_primary_photo_required' USING ERRCODE = 'P0001';
  END IF;
  IF v_active_verification THEN
    RAISE EXCEPTION 'photo_verification_already_approved'
      USING ERRCODE = 'P0001';
  END IF;

  UPDATE public.photo_verification_submissions
  SET status = 'expired',
      review_reason = 'A newer verification attempt was started.',
      purge_after = least(purge_after, now())
  WHERE user_id = p_user_id
    AND status = 'uploading'
    AND created_at < now() - interval '15 minutes';

  IF EXISTS (
    SELECT 1 FROM public.photo_verification_submissions
    WHERE user_id = p_user_id AND status IN ('uploading', 'pending')
  ) THEN
    RAISE EXCEPTION 'photo_verification_already_in_progress'
      USING ERRCODE = 'P0001';
  END IF;

  INSERT INTO public.photo_verification_submissions(
    user_id, profile_id, primary_photo_id,
    neutral_storage_path, smile_storage_path, blink_storage_path,
    guidance_mode, review_deadline, purge_after
  ) VALUES (
    p_user_id, v_profile_id, v_primary_photo_id,
    p_neutral_path, p_smile_path, p_blink_path,
    p_guidance_mode, v_deadline, v_deadline - interval '10 minutes'
  ) RETURNING id INTO v_submission_id;

  RETURN QUERY SELECT v_submission_id, v_deadline;
END;
$$;

CREATE OR REPLACE FUNCTION public.submit_photo_verification_for_review(
  p_user_id uuid,
  p_submission_id uuid
)
RETURNS timestamptz
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_deadline timestamptz;
BEGIN
  IF auth.role() <> 'service_role' THEN
    RAISE EXCEPTION 'service_role_required' USING ERRCODE = 'P0001';
  END IF;
  UPDATE public.photo_verification_submissions s
  SET status = 'pending', submitted_at = now()
  WHERE s.id = p_submission_id
    AND s.user_id = p_user_id
    AND s.status = 'uploading'
    AND s.review_deadline > now()
    AND s.neutral_storage_path IS NOT NULL
    AND s.smile_storage_path IS NOT NULL
    AND s.blink_storage_path IS NOT NULL
  RETURNING s.review_deadline INTO v_deadline;
  IF v_deadline IS NULL THEN
    RAISE EXCEPTION 'photo_verification_submission_not_submittable'
      USING ERRCODE = 'P0001';
  END IF;
  RETURN v_deadline;
END;
$$;

REVOKE ALL ON FUNCTION public.start_photo_verification_submission(
  uuid, text, text, text, text
) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.submit_photo_verification_for_review(uuid, uuid)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.start_photo_verification_submission(
  uuid, text, text, text, text
) TO service_role;
GRANT EXECUTE ON FUNCTION public.submit_photo_verification_for_review(uuid, uuid)
  TO service_role;

CREATE OR REPLACE FUNCTION public.get_my_photo_verification_status()
RETURNS TABLE(
  status text,
  submitted_at timestamptz,
  review_deadline timestamptz,
  reviewed_at timestamptz,
  reason text,
  captures_purged_at timestamptz,
  photo_verified_at timestamptz,
  paused_at timestamptz,
  pause_reason text,
  can_submit boolean
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_me uuid := private.assert_authenticated();
BEGIN
  RETURN QUERY
  SELECT
    coalesce(s.status, 'not_started')::text,
    s.submitted_at,
    s.review_deadline,
    s.reviewed_at,
    s.review_reason::text,
    s.captures_purged_at,
    p.photo_verified_at,
    p.photo_verification_paused_at,
    p.photo_verification_pause_reason::text,
    (coalesce(s.status, '') NOT IN ('uploading', 'pending'))::boolean
  FROM public.profiles p
  LEFT JOIN LATERAL (
    SELECT latest.*
    FROM public.photo_verification_submissions latest
    WHERE latest.user_id = v_me
    ORDER BY latest.created_at DESC, latest.id DESC
    LIMIT 1
  ) s ON true
  WHERE p.user_id = v_me;
END;
$$;

REVOKE ALL ON FUNCTION public.get_my_photo_verification_status()
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_my_photo_verification_status()
  TO authenticated;

-- One bounded batch per discovery page exposes booleans only; no phone,
-- email, document, path, or reviewer data leaves the trust boundary.
CREATE OR REPLACE FUNCTION public.get_member_trust_summaries(p_user_ids uuid[])
RETURNS TABLE(
  user_id uuid,
  photo_verified boolean,
  phone_verified boolean,
  guardian_connected boolean,
  established_member boolean
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_me uuid := private.assert_authenticated();
  v_ids uuid[];
BEGIN
  v_ids := ARRAY(
    SELECT DISTINCT requested
    FROM unnest(coalesce(p_user_ids, ARRAY[]::uuid[])) requested
    WHERE requested IS NOT NULL
    LIMIT 20
  );
  IF cardinality(v_ids) = 0 THEN RETURN; END IF;

  RETURN QUERY
  SELECT
    p.user_id,
    (p.photo_verified_at IS NOT NULL
      AND p.photo_verification_paused_at IS NULL)::boolean,
    (u.phone_verified_at IS NOT NULL)::boolean,
    (p.guardian_user_id IS NOT NULL)::boolean,
    (u.created_at <= now() - interval '30 days'
      AND u.deleted_at IS NULL
      AND coalesce(u.is_banned, false) = false)::boolean
  FROM public.profiles p
  JOIN public.users u ON u.id = p.user_id
  WHERE p.user_id = ANY(v_ids)
    AND (
      p.user_id = v_me
      OR EXISTS (
        SELECT 1 FROM public.live_discovery_pool candidate
        WHERE candidate.user_id = p.user_id
      )
      OR EXISTS (
        SELECT 1 FROM public.interests i
        WHERE (i.sender_id = v_me AND i.receiver_id = p.user_id)
           OR (i.receiver_id = v_me AND i.sender_id = p.user_id)
      )
      OR EXISTS (
        SELECT 1 FROM public.matches m
        WHERE (m.user_a = v_me AND m.user_b = p.user_id)
           OR (m.user_b = v_me AND m.user_a = p.user_id)
      )
    );
END;
$$;

REVOKE ALL ON FUNCTION public.get_member_trust_summaries(uuid[])
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_member_trust_summaries(uuid[])
  TO authenticated;

-- ---------------------------------------------------------------------------
-- 3. Staff review. Approval compares only the temporary captures with the
--    current primary profile photo and cannot outlive a photo replacement.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.admin_photo_verification_queue(
  p_limit integer DEFAULT 25
)
RETURNS TABLE(
  submission_id uuid,
  user_id uuid,
  profile_id uuid,
  member_name text,
  submitted_at timestamptz,
  review_deadline timestamptz,
  guidance_mode text,
  primary_photo_path text,
  neutral_path text,
  smile_path text,
  blink_path text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  IF NOT public.is_active_admin(ARRAY['super_admin','moderator']) THEN
    RAISE EXCEPTION 'staff_authorization_required' USING ERRCODE = '42501';
  END IF;
  IF p_limit NOT BETWEEN 1 AND 100 THEN
    RAISE EXCEPTION 'invalid_queue_limit' USING ERRCODE = '22023';
  END IF;
  RETURN QUERY
  SELECT s.id, s.user_id, s.profile_id,
         trim(concat_ws(' ', p.first_name, p.last_name)),
         s.submitted_at, s.review_deadline, s.guidance_mode,
         ph.storage_path, s.neutral_storage_path, s.smile_storage_path,
         s.blink_storage_path
  FROM public.photo_verification_submissions s
  JOIN public.profiles p ON p.id = s.profile_id
  JOIN public.photos ph ON ph.id = s.primary_photo_id
  WHERE s.status = 'pending'
    AND s.captures_purged_at IS NULL
    AND s.review_deadline > now()
  ORDER BY s.submitted_at, s.id
  LIMIT p_limit;
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_review_photo_verification(
  p_submission_id uuid,
  p_decision text,
  p_reason text DEFAULT NULL,
  p_same_person boolean DEFAULT false,
  p_clear_capture boolean DEFAULT false,
  p_current_photo_match boolean DEFAULT false
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_submission public.photo_verification_submissions%ROWTYPE;
  v_reason text := trim(coalesce(p_reason, ''));
  v_current_primary uuid;
BEGIN
  IF NOT public.is_active_admin(ARRAY['super_admin','moderator']) THEN
    RAISE EXCEPTION 'staff_authorization_required' USING ERRCODE = '42501';
  END IF;
  IF p_decision NOT IN ('approve', 'resubmit', 'reject') THEN
    RAISE EXCEPTION 'unsupported_photo_verification_decision'
      USING ERRCODE = '22023';
  END IF;

  SELECT * INTO v_submission
  FROM public.photo_verification_submissions
  WHERE id = p_submission_id
  FOR UPDATE;
  IF NOT FOUND OR v_submission.status <> 'pending'
    OR v_submission.captures_purged_at IS NOT NULL
    OR v_submission.review_deadline <= now() THEN
    RAISE EXCEPTION 'photo_verification_not_reviewable' USING ERRCODE = 'P0001';
  END IF;

  SELECT ph.id INTO v_current_primary
  FROM public.photos ph
  WHERE ph.profile_id = v_submission.profile_id
    AND ph.order_index = 0
    AND ph.status = 'active'
    AND ph.admin_approved = true
    AND ph.nsfw_cleared = true
  ORDER BY ph.created_at DESC
  LIMIT 1;

  IF p_decision = 'approve' THEN
    IF NOT (p_same_person AND p_clear_capture AND p_current_photo_match)
      OR v_current_primary IS DISTINCT FROM v_submission.primary_photo_id THEN
      RAISE EXCEPTION 'photo_verification_checklist_incomplete'
        USING ERRCODE = 'P0001';
    END IF;
  ELSIF length(v_reason) < 6 THEN
    RAISE EXCEPTION 'photo_verification_reason_required'
      USING ERRCODE = '22023';
  END IF;

  UPDATE public.photo_verification_submissions
  SET status = CASE p_decision
        WHEN 'approve' THEN 'approved'
        WHEN 'resubmit' THEN 'resubmit'
        ELSE 'rejected'
      END,
      reviewed_at = now(),
      reviewed_by = auth.uid(),
      review_reason = nullif(v_reason, ''),
      review_checklist = jsonb_build_object(
        'same_person', p_same_person,
        'clear_capture', p_clear_capture,
        'current_photo_match', p_current_photo_match
      ),
      purge_after = now(),
      purge_status = 'pending',
      purge_claimed_at = NULL
  WHERE id = v_submission.id;

  IF p_decision = 'approve' THEN
    UPDATE public.profiles
    SET photo_verified_at = now(),
        photo_verification_submission_id = v_submission.id,
        photo_verification_paused_at = NULL,
        photo_verification_pause_reason = NULL,
        has_verification_badge = true,
        badge_earned_at = now(),
        verification_status = 'verified',
        verification_challenge = 'manual_photo_review_v1',
        verified_at = now(),
        is_verified = true
    WHERE id = v_submission.profile_id;
  END IF;

  INSERT INTO public.admin_audit_log(
    admin_id, actor_role, action_type, target_user_id, details
  ) VALUES (
    auth.uid(), public.current_admin_role(),
    'photo_verification_' || p_decision,
    v_submission.user_id,
    jsonb_build_object(
      'submission_id', v_submission.id,
      'reason', nullif(v_reason, ''),
      'captures_purge_queued', true
    )
  );

  PERFORM public.queue_notification(
    v_submission.user_id,
    CASE WHEN p_decision = 'approve' THEN 'photo_verification_approved'
         ELSE 'photo_verification_reviewed' END,
    CASE WHEN p_decision = 'approve' THEN 'Photo verified'
         WHEN p_decision = 'resubmit' THEN 'New verification photos needed'
         ELSE 'Photo verification not approved' END,
    CASE WHEN p_decision = 'approve'
         THEN 'Your temporary captures are queued for immediate deletion.'
         ELSE v_reason END,
    'silarah://verify'
  );
END;
$$;

REVOKE ALL ON FUNCTION public.admin_photo_verification_queue(integer)
  FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.admin_review_photo_verification(
  uuid, text, text, boolean, boolean, boolean
) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_photo_verification_queue(integer)
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_review_photo_verification(
  uuid, text, text, boolean, boolean, boolean
) TO authenticated;

-- ---------------------------------------------------------------------------
-- 4. Leased, idempotent deletion. Path columns are cleared only after every
--    object deletion succeeds; audit outcome and dates remain.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.checkout_photo_verification_purges(
  p_limit integer DEFAULT 10
)
RETURNS TABLE(
  submission_id uuid,
  user_id uuid,
  neutral_path text,
  smile_path text,
  blink_path text
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
    FROM public.photo_verification_submissions s
    WHERE s.captures_purged_at IS NULL
      AND s.purge_after <= now()
      AND s.purge_attempts < 12
      AND (
        s.purge_status IN ('pending', 'failed')
        OR (s.purge_status = 'deleting'
            AND s.purge_claimed_at < now() - interval '10 minutes')
      )
    ORDER BY s.purge_after, s.id
    FOR UPDATE SKIP LOCKED
    LIMIT least(greatest(coalesce(p_limit, 10), 1), 25)
  ), claimed AS (
    UPDATE public.photo_verification_submissions s
    SET purge_status = 'deleting',
        purge_claimed_at = now(),
        purge_attempts = s.purge_attempts + 1,
        purge_last_error = NULL
    FROM candidates c
    WHERE s.id = c.id
    RETURNING s.*
  )
  SELECT c.id, c.user_id, c.neutral_storage_path,
         c.smile_storage_path, c.blink_storage_path
  FROM claimed c;
END;
$$;

CREATE OR REPLACE FUNCTION public.finish_photo_verification_purge(
  p_submission_id uuid,
  p_success boolean,
  p_error text DEFAULT NULL
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_submission public.photo_verification_submissions%ROWTYPE;
BEGIN
  IF auth.role() <> 'service_role' THEN
    RAISE EXCEPTION 'service_role_required' USING ERRCODE = 'P0001';
  END IF;
  SELECT * INTO v_submission
  FROM public.photo_verification_submissions
  WHERE id = p_submission_id
  FOR UPDATE;
  IF NOT FOUND THEN RETURN false; END IF;
  IF v_submission.captures_purged_at IS NOT NULL THEN RETURN true; END IF;

  IF NOT p_success THEN
    UPDATE public.photo_verification_submissions
    SET purge_status = 'failed',
        purge_last_error = left(coalesce(p_error, 'storage_delete_failed'), 300),
        purge_claimed_at = NULL
    WHERE id = p_submission_id;
    RETURN false;
  END IF;

  UPDATE public.photo_verification_submissions
  SET status = CASE
        WHEN status IN ('uploading', 'pending') THEN 'expired'
        ELSE status
      END,
      review_reason = CASE
        WHEN status IN ('uploading', 'pending')
          THEN 'Temporary verification captures reached their deletion deadline.'
        ELSE review_reason
      END,
      neutral_storage_path = NULL,
      smile_storage_path = NULL,
      blink_storage_path = NULL,
      captures_purged_at = now(),
      purge_status = 'completed',
      purge_claimed_at = NULL,
      purge_last_error = NULL
  WHERE id = p_submission_id;
  RETURN true;
END;
$$;

REVOKE ALL ON FUNCTION public.checkout_photo_verification_purges(integer)
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.finish_photo_verification_purge(uuid, boolean, text)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.checkout_photo_verification_purges(integer)
  TO service_role;
GRANT EXECUTE ON FUNCTION public.finish_photo_verification_purge(uuid, boolean, text)
  TO service_role;

-- A primary-photo replacement/removal pauses the public photo badge until a
-- new submission is reviewed against the new active photo.
CREATE OR REPLACE FUNCTION private.pause_photo_verification_on_primary_change()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_profile_id uuid := coalesce(NEW.profile_id, OLD.profile_id);
  v_order integer := coalesce(NEW.order_index, OLD.order_index);
BEGIN
  IF v_order = 0 THEN
    UPDATE public.profiles p
    SET photo_verification_paused_at = now(),
        photo_verification_pause_reason = 'primary_photo_changed',
        has_verification_badge = false,
        verification_status = 'unverified',
        verified_at = NULL,
        is_verified = false
    WHERE p.id = v_profile_id
      AND p.photo_verified_at IS NOT NULL
      AND p.photo_verification_paused_at IS NULL;
  END IF;
  IF TG_OP = 'DELETE' THEN RETURN OLD; END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_pause_photo_verification_on_primary_change
  ON public.photos;
CREATE TRIGGER trg_pause_photo_verification_on_primary_change
AFTER INSERT OR DELETE OR UPDATE OF status, order_index, admin_approved,
  nsfw_cleared, storage_path
ON public.photos
FOR EACH ROW EXECUTE FUNCTION private.pause_photo_verification_on_primary_change();

-- Retire the client-trusted completion RPC. Existing status data remains for
-- migration visibility but can no longer grant any public trust state.
REVOKE ALL ON FUNCTION public.submit_my_photo_badge_verification()
  FROM PUBLIC, anon, authenticated;
DROP FUNCTION IF EXISTS public.submit_my_photo_badge_verification();
REVOKE ALL ON FUNCTION public.get_my_photo_liveness_status()
  FROM PUBLIC, anon, authenticated;
DROP FUNCTION IF EXISTS public.get_my_photo_liveness_status();
-- The invoker-safe owner projection expands the profiles composite type. Drop
-- and recreate only that view so PostgreSQL can remove the retired columns
-- without CASCADE or weakening the read boundary.
DROP VIEW IF EXISTS public.my_profile_private;
ALTER TABLE public.profiles
  DROP COLUMN IF EXISTS photo_liveness_check_completed,
  DROP COLUMN IF EXISTS photo_liveness_check_completed_at;
CREATE VIEW public.my_profile_private
WITH (security_invoker = true, security_barrier = true)
AS
SELECT row_data.*
FROM public.get_my_profile_private_rows() AS row_data;
REVOKE ALL ON public.my_profile_private FROM PUBLIC, anon;
GRANT SELECT ON public.my_profile_private TO authenticated;

-- Government-ID KYC is retired from the product. Existing private evidence
-- is queued for the already-idempotent KYC purge worker; historical decision
-- rows remain only until a later, separately verified destructive migration.
UPDATE public.kyc_review_submissions
SET status = CASE WHEN status = 'pending' THEN 'expired' ELSE status END,
    review_reason = CASE WHEN status = 'pending'
      THEN 'Government-ID verification was retired.' ELSE review_reason END,
    purge_after = least(purge_after, now())
WHERE documents_purged_at IS NULL;

REVOKE ALL ON FUNCTION public.get_my_kyc_status()
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.admin_kyc_queue(integer)
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.admin_review_kyc(
  uuid, text, text, boolean, boolean, boolean, boolean, boolean
) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.submit_manual_kyc_for_review(
  uuid, text, text, text, text, date, numeric
) FROM PUBLIC, anon, authenticated, service_role;

-- The old broad boolean remains a compatibility alias during rollout, but it
-- now means current photo-review approval only.
UPDATE public.profiles
SET has_verification_badge = false,
    badge_earned_at = NULL,
    verification_status = 'unverified',
    verified_at = NULL,
    is_verified = false
WHERE photo_verified_at IS NULL;

-- Server-side trust-filter enforcement. Old verified_only clients map to
-- photo verification; new clients can request the explicit trust modes.
CREATE OR REPLACE FUNCTION private.assert_discovery_filter_entitlement(
  p_user_id uuid,
  p_filters jsonb
)
RETURNS void
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_features text[] := ARRAY[]::text[];
  v_trust_filter text := nullif(lower(trim(p_filters->>'trust_filter')), '');
BEGIN
  IF v_trust_filter IS NOT NULL
    AND v_trust_filter NOT IN ('photo', 'phone', 'both', 'guardian') THEN
    RAISE EXCEPTION 'invalid_trust_filter' USING ERRCODE = '22023';
  END IF;
  IF public.has_active_premium(p_user_id) THEN RETURN; END IF;
  IF coalesce((p_filters->>'verified_only')::boolean, false)
    OR v_trust_filter IS NOT NULL THEN
    v_features := array_append(v_features, 'trust_filter');
  END IF;
  IF nullif(trim(p_filters->>'mother_tongue'), '') IS NOT NULL THEN
    v_features := array_append(v_features, 'mother_tongue');
  END IF;
  IF nullif(trim(p_filters->>'community'), '') IS NOT NULL THEN
    v_features := array_append(v_features, 'community');
  END IF;
  IF nullif(trim(p_filters->>'living_expectation'), '') IS NOT NULL THEN
    v_features := array_append(v_features, 'living_expectation');
  END IF;
  IF cardinality(v_features) > 0 THEN
    RAISE EXCEPTION 'premium_filter_required'
      USING ERRCODE = 'P0001', DETAIL = json_build_object(
        'feature', 'premium_preferences', 'filters', v_features
      )::text;
  END IF;
END;
$$;

-- Patch the existing mature discovery function in place so all relationship,
-- rematch, quota and ranking fixes remain intact.
DO $migration$
DECLARE
  v_signature regprocedure :=
    'public.get_discovery_feed(uuid,double precision,uuid,integer,jsonb)'::regprocedure;
  v_definition text;
  v_updated text;
  v_old text := $old$      AND (coalesce((p_filters->>'verified_only')::boolean, false) IS FALSE
        OR dp.is_verified = true)$old$;
  v_new text := $new$      AND (
        (coalesce((p_filters->>'verified_only')::boolean, false) IS FALSE
          OR dp.is_verified = true)
        AND (
          nullif(lower(trim(p_filters->>'trust_filter')), '') IS NULL
          OR (lower(trim(p_filters->>'trust_filter')) = 'photo'
              AND candidate_profile.photo_verified_at IS NOT NULL
              AND candidate_profile.photo_verification_paused_at IS NULL)
          OR (lower(trim(p_filters->>'trust_filter')) = 'phone'
              AND EXISTS (
                SELECT 1 FROM public.users trust_account
                WHERE trust_account.id = dp.user_id
                  AND trust_account.phone_verified_at IS NOT NULL
              ))
          OR (lower(trim(p_filters->>'trust_filter')) = 'both'
              AND candidate_profile.photo_verified_at IS NOT NULL
              AND candidate_profile.photo_verification_paused_at IS NULL
              AND EXISTS (
                SELECT 1 FROM public.users trust_account
                WHERE trust_account.id = dp.user_id
                  AND trust_account.phone_verified_at IS NOT NULL
              ))
          OR (lower(trim(p_filters->>'trust_filter')) = 'guardian'
              AND candidate_profile.guardian_user_id IS NOT NULL)
        )
      )$new$;
BEGIN
  SELECT replace(pg_get_functiondef(v_signature), E'\r\n', E'\n')
  INTO v_definition;
  IF position('candidate_profile.photo_verified_at' IN v_definition) = 0 THEN
    IF position(v_old IN v_definition) = 0 THEN
      RAISE EXCEPTION 'trust_filter_patch_anchor_not_found';
    END IF;
    v_updated := replace(v_definition, v_old, v_new);
    EXECUTE v_updated;
  END IF;
END;
$migration$;

-- SMS verification is a trust prerequisite for outgoing chat. Premium
-- purchase state never substitutes for a successful phone OTP.
DO $migration$
DECLARE
  v_signature regprocedure :=
    'public.send_chat_message(uuid,text)'::regprocedure;
  v_definition text;
  v_anchor text := $anchor$  IF v_me IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = 'P0001';
  END IF;$anchor$;
  v_replacement text := $replacement$  IF v_me IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = 'P0001';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.users verified_sender
    WHERE verified_sender.id = v_me
      AND verified_sender.phone_verified_at IS NOT NULL
  ) THEN
    RAISE EXCEPTION 'phone_verification_required'
      USING ERRCODE = 'P0001';
  END IF;$replacement$;
BEGIN
  SELECT replace(pg_get_functiondef(v_signature), E'\r\n', E'\n')
  INTO v_definition;
  IF position('phone_verification_required' IN v_definition) = 0 THEN
    IF position(v_anchor IN v_definition) = 0 THEN
      RAISE EXCEPTION 'chat_phone_verification_anchor_not_found';
    END IF;
    EXECUTE replace(v_definition, v_anchor, v_replacement);
  END IF;
END;
$migration$;

COMMENT ON TABLE public.photo_verification_submissions IS
  'Temporary smile/blink review captures. No biometric templates, identity documents, age estimation, or automated identity matching.';
COMMENT ON FUNCTION public.get_launch_configuration() IS
  'Public, non-personal launch-market feature configuration for adaptive client filters.';

CREATE OR REPLACE FUNCTION private.invoke_photo_verification_purge_worker()
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
      url := v_url || '/functions/v1/purge-photo-verification-captures',
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
REVOKE ALL ON FUNCTION private.invoke_photo_verification_purge_worker()
  FROM PUBLIC;

DO $migration$
DECLARE v_job record;
BEGIN
  IF to_regclass('cron.job') IS NULL THEN RETURN; END IF;
  FOR v_job IN
    SELECT jobid FROM cron.job
    WHERE jobname = 'photo_verification_capture_purge'
  LOOP
    PERFORM cron.unschedule(v_job.jobid);
  END LOOP;
  PERFORM cron.schedule(
    'photo_verification_capture_purge',
    '*/5 * * * *',
    'SELECT private.invoke_photo_verification_purge_worker();'
  );
END;
$migration$;

NOTIFY pgrst, 'reload schema';
