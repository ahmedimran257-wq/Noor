-- Admin profile approval should fail before a visibility update reaches generic
-- profile triggers, and the directory should expose readiness state so the UI
-- can disable impossible approval actions.

DROP FUNCTION IF EXISTS public.admin_user_directory_page(text, integer, integer);

CREATE OR REPLACE FUNCTION public.admin_user_directory_page(
  p_query text DEFAULT '',
  p_limit integer DEFAULT 50,
  p_offset integer DEFAULT 0
)
RETURNS TABLE(
  user_id uuid,
  profile_id uuid,
  name text,
  email text,
  country_code text,
  gender text,
  joined_at timestamptz,
  last_active_at timestamptz,
  onboarding_step int,
  completeness_score int,
  visibility text,
  is_banned boolean,
  subscription_status text,
  verification_status text,
  has_verification_badge boolean,
  can_approve_profile boolean,
  approval_block_reason text,
  total_count bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_limit integer := least(greatest(coalesce(p_limit, 50), 1), 50);
  v_offset integer := greatest(coalesce(p_offset, 0), 0);
  v_query text := trim(coalesce(p_query, ''));
BEGIN
  IF NOT public.is_active_admin() THEN
    RAISE EXCEPTION 'Staff authorization required';
  END IF;

  INSERT INTO public.admin_audit_log(admin_id, actor_role, action_type, details)
  VALUES (
    auth.uid(),
    public.current_admin_role(),
    'admin_user_directory_read',
    jsonb_build_object('query_present', v_query <> '', 'limit', v_limit, 'offset', v_offset)
  );

  RETURN QUERY
  WITH directory AS (
    SELECT
      u.id AS user_id,
      p.id AS profile_id,
      public.mask_admin_name(concat_ws(' ', p.first_name, p.last_name))::text AS name,
      public.mask_admin_email(u.email::text)::text AS email,
      p.country_code::text AS country_code,
      p.gender::text AS gender,
      u.created_at AS joined_at,
      p.last_active_at AS last_active_at,
      p.onboarding_step::int AS onboarding_step,
      p.completeness_score::int AS completeness_score,
      p.visibility::text AS visibility,
      coalesce(u.is_banned, false) AS is_banned,
      u.subscription_status::text AS subscription_status,
      p.verification_status::text AS verification_status,
      coalesce(p.has_verification_badge, false) AS has_verification_badge,
      coalesce(p.onboarding_completed, false) AS onboarding_completed,
      p.marriage_timeline,
      EXISTS (
        SELECT 1
        FROM public.photos ph
        WHERE ph.profile_id = p.id
          AND ph.admin_approved = true
          AND ph.nsfw_cleared = true
          AND coalesce(ph.status, 'active') = 'active'
      ) AS has_safe_photo
    FROM public.users u
    JOIN public.profiles p ON p.user_id = u.id
    WHERE
      v_query = ''
      OR concat_ws(' ', p.first_name, p.last_name, u.email, u.id::text) ILIKE '%' || v_query || '%'
  )
  SELECT
    d.user_id::uuid,
    d.profile_id::uuid,
    d.name,
    d.email,
    d.country_code,
    d.gender,
    d.joined_at::timestamptz,
    d.last_active_at::timestamptz,
    d.onboarding_step,
    d.completeness_score,
    d.visibility,
    d.is_banned::boolean,
    d.subscription_status,
    d.verification_status,
    d.has_verification_badge::boolean,
    (
      NOT d.is_banned
      AND d.onboarding_completed
      AND d.visibility NOT IN ('suspended', 'deactivated')
      AND d.has_safe_photo
      AND d.marriage_timeline IS NOT NULL
    )::boolean AS can_approve_profile,
    CASE
      WHEN d.is_banned THEN 'Banned users cannot be approved.'
      WHEN d.onboarding_completed IS DISTINCT FROM true THEN 'Onboarding must be complete before approval.'
      WHEN d.visibility IN ('suspended', 'deactivated') THEN 'Restore the account before approving profile visibility.'
      WHEN d.has_safe_photo IS DISTINCT FROM true THEN 'Approve at least one safe profile photo before approving visibility.'
      WHEN d.marriage_timeline IS NULL THEN 'Marriage timeline is required before this profile can go live.'
      ELSE NULL
    END::text AS approval_block_reason,
    count(*) OVER ()::bigint AS total_count
  FROM directory d
  ORDER BY d.joined_at DESC
  LIMIT v_limit OFFSET v_offset;
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_profile_visibility_action(
  p_user_id uuid,
  p_action text,
  p_reason text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_profile public.profiles%ROWTYPE;
  v_is_banned boolean;
  v_has_safe_photo boolean;
BEGIN
  IF NOT public.is_active_admin(ARRAY['super_admin','moderator']) THEN
    RAISE EXCEPTION 'Staff authorization required';
  END IF;

  IF p_action NOT IN ('approve', 'return_to_review') THEN
    RAISE EXCEPTION 'Unsupported profile visibility action';
  END IF;

  SELECT *
  INTO v_profile
  FROM public.profiles
  WHERE user_id = p_user_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Profile not found';
  END IF;

  SELECT coalesce(u.is_banned, false)
  INTO v_is_banned
  FROM public.users u
  WHERE u.id = p_user_id;

  IF coalesce(v_is_banned, false) THEN
    RAISE EXCEPTION 'Banned users cannot be approved';
  END IF;

  IF p_action = 'approve' THEN
    IF coalesce(v_profile.onboarding_completed, false) IS DISTINCT FROM true THEN
      RAISE EXCEPTION 'Onboarding must be complete before approval';
    END IF;

    IF v_profile.visibility IN ('suspended', 'deactivated') THEN
      RAISE EXCEPTION 'Restore the account before approving profile visibility';
    END IF;

    SELECT EXISTS (
      SELECT 1
      FROM public.photos ph
      WHERE ph.profile_id = v_profile.id
        AND ph.admin_approved = true
        AND ph.nsfw_cleared = true
        AND coalesce(ph.status, 'active') = 'active'
    )
    INTO v_has_safe_photo;

    IF NOT coalesce(v_has_safe_photo, false) THEN
      RAISE EXCEPTION 'Approve at least one safe profile photo before approving visibility';
    END IF;

    IF v_profile.marriage_timeline IS NULL THEN
      RAISE EXCEPTION 'Marriage timeline is required before this profile can go live.';
    END IF;

    UPDATE public.profiles
    SET approved_at = coalesce(approved_at, now()),
        visibility = 'visible',
        suspended_reason = NULL
    WHERE user_id = p_user_id;

    PERFORM public.queue_notification(
      p_user_id,
      'profile_approved',
      'Profile approved',
      'Your Mithaq profile is now visible in discovery.',
      '/home?tab=0'
    );
  ELSE
    UPDATE public.profiles
    SET approved_at = NULL,
        visibility = CASE
          WHEN visibility IN ('suspended', 'deactivated') THEN visibility
          ELSE 'paused'
        END,
        suspended_reason = coalesce(nullif(trim(p_reason), ''), suspended_reason)
    WHERE user_id = p_user_id;

    PERFORM public.queue_notification(
      p_user_id,
      'profile_returned_to_review',
      'Profile returned to review',
      'Your profile is temporarily hidden while the Mithaq team reviews it.',
      '/profile'
    );
  END IF;

  INSERT INTO public.admin_audit_log(admin_id, actor_role, action_type, target_user_id, details)
  VALUES (
    auth.uid(),
    public.current_admin_role(),
    'profile_visibility_' || p_action,
    p_user_id,
    jsonb_build_object('reason', p_reason)
  );
END;
$$;

REVOKE ALL ON FUNCTION public.admin_user_directory_page(text, integer, integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_profile_visibility_action(uuid, text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_user_directory_page(text, integer, integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_profile_visibility_action(uuid, text, text) TO authenticated;
