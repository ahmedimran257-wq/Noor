-- Shadowbans are intentionally silent: the affected account must not receive
-- a push or in-app notification that reveals the moderation control. This
-- migration also exposes the state to staff and removes the legacy approval
-- gate from restore behavior.

DROP FUNCTION IF EXISTS public.admin_user_directory_page(text, integer, integer);

CREATE FUNCTION public.admin_user_directory_page(
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
  is_shadowbanned boolean,
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
      coalesce(u.is_shadowbanned, false) AS is_shadowbanned,
      u.subscription_status::text AS subscription_status,
      p.verification_status::text AS verification_status,
      coalesce(p.has_verification_badge, false) AS has_verification_badge,
      coalesce(p.onboarding_completed, false) AS onboarding_completed,
      p.marriage_timeline,
      EXISTS (
        SELECT 1
        FROM public.photos ph
        WHERE ph.profile_id = p.id
          AND ph.order_index = 0
          AND ph.admin_approved = true
          AND ph.nsfw_cleared = true
          AND coalesce(ph.status, 'active') = 'active'
      ) AS has_safe_primary_photo
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
    d.is_shadowbanned::boolean,
    d.subscription_status,
    d.verification_status,
    d.has_verification_badge::boolean,
    (
      NOT d.is_banned
      AND d.onboarding_completed
      AND d.visibility NOT IN ('suspended', 'deactivated')
      AND d.has_safe_primary_photo
      AND d.marriage_timeline IS NOT NULL
    )::boolean AS can_approve_profile,
    CASE
      WHEN d.is_banned THEN 'Banned users cannot be made visible.'
      WHEN d.onboarding_completed IS DISTINCT FROM true THEN 'Onboarding must be complete.'
      WHEN d.visibility IN ('suspended', 'deactivated') THEN 'Restore the account first.'
      WHEN d.has_safe_primary_photo IS DISTINCT FROM true THEN 'A safe primary photo is required.'
      WHEN d.marriage_timeline IS NULL THEN 'Marriage timeline is required.'
      ELSE NULL
    END::text AS approval_block_reason,
    count(*) OVER ()::bigint AS total_count
  FROM directory d
  ORDER BY d.joined_at DESC
  LIMIT v_limit OFFSET v_offset;
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_account_action(
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
  v_is_banned boolean;
  v_has_safe_primary_photo boolean;
BEGIN
  IF NOT public.is_active_admin(ARRAY['super_admin','moderator']) THEN
    RAISE EXCEPTION 'Staff authorization required';
  END IF;

  IF p_action IN ('ban', 'shadowban') AND NOT public.is_active_admin(ARRAY['super_admin']) THEN
    RAISE EXCEPTION 'Super admin authorization required';
  END IF;

  SELECT
    coalesce(u.is_banned, false),
    EXISTS (
      SELECT 1
      FROM public.profiles p
      JOIN public.photos ph ON ph.profile_id = p.id
      WHERE p.user_id = p_user_id
        AND ph.order_index = 0
        AND ph.admin_approved = true
        AND ph.nsfw_cleared = true
        AND coalesce(ph.status, 'active') = 'active'
    )
  INTO v_is_banned, v_has_safe_primary_photo
  FROM public.users u
  WHERE u.id = p_user_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'User not found';
  END IF;

  IF p_action = 'suspend' THEN
    UPDATE public.profiles
    SET visibility = 'suspended',
        suspended_reason = coalesce(nullif(trim(p_reason), ''), 'admin_suspension')
    WHERE user_id = p_user_id;

    PERFORM public.queue_notification(
      p_user_id,
      'account_suspended',
      'Profile suspended',
      'Your Silarah profile has been suspended. Contact support if you believe this is a mistake.',
      '/help-support'
    );
  ELSIF p_action = 'restore' THEN
    IF coalesce(v_is_banned, false) AND NOT public.is_active_admin(ARRAY['super_admin']) THEN
      RAISE EXCEPTION 'Super admin authorization required to restore a banned account';
    END IF;

    UPDATE public.users
    SET is_shadowbanned = false,
        shadowbanned_at = NULL,
        shadowban_reason = NULL,
        is_banned = CASE WHEN coalesce(v_is_banned, false) THEN false ELSE is_banned END,
        banned_at = CASE WHEN coalesce(v_is_banned, false) THEN NULL ELSE banned_at END,
        banned_reason = CASE WHEN coalesce(v_is_banned, false) THEN NULL ELSE banned_reason END
    WHERE id = p_user_id;

    UPDATE public.profiles
    SET visibility = CASE WHEN v_has_safe_primary_photo THEN 'visible' ELSE 'paused' END,
        suspended_reason = NULL
    WHERE user_id = p_user_id;

    PERFORM public.queue_notification(
      p_user_id,
      'account_restored',
      'Profile restored',
      CASE
        WHEN v_has_safe_primary_photo THEN 'Your Silarah profile has been restored and is visible again.'
        ELSE 'Your Silarah account has been restored. Add a safe primary photo to return to discovery.'
      END,
      '/home?tab=3'
    );
  ELSIF p_action = 'shadowban' THEN
    UPDATE public.users
    SET is_shadowbanned = true,
        shadowbanned_at = now(),
        shadowban_reason = coalesce(nullif(trim(p_reason), ''), 'admin_shadowban')
    WHERE id = p_user_id;

    -- Deliberately silent: do not disclose this moderation control to the user.
  ELSIF p_action = 'ban' THEN
    UPDATE public.users
    SET is_banned = true,
        banned_at = now(),
        banned_reason = coalesce(nullif(trim(p_reason), ''), 'admin_ban')
    WHERE id = p_user_id;

    UPDATE public.profiles
    SET visibility = 'suspended',
        suspended_reason = coalesce(nullif(trim(p_reason), ''), 'admin_ban')
    WHERE user_id = p_user_id;

    PERFORM public.queue_notification(
      p_user_id,
      'account_banned',
      'Account banned',
      'Your Silarah account has been banned for violating community guidelines.',
      '/help-support'
    );
  ELSE
    RAISE EXCEPTION 'Unsupported account action';
  END IF;

  INSERT INTO public.admin_audit_log(admin_id, actor_role, action_type, target_user_id, details)
  VALUES (
    auth.uid(),
    public.current_admin_role(),
    'account_' || p_action,
    p_user_id,
    jsonb_build_object('reason', p_reason, 'silent', p_action = 'shadowban')
  );
END;
$$;

-- Remove notifications generated by the previous implementation because they
-- disclose the presence of a shadowban.
DELETE FROM public.notifications WHERE type = 'account_limited';

REVOKE ALL ON FUNCTION public.admin_user_directory_page(text, integer, integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_account_action(uuid, text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_user_directory_page(text, integer, integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_account_action(uuid, text, text) TO authenticated;
