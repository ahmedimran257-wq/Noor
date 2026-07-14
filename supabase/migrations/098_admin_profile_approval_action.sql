-- Admin-controlled profile approval gate.
-- Profiles only become discoverable after onboarding is complete, at least one
-- approved/safe photo exists, and a moderator/super-admin explicitly approves.

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

    UPDATE public.profiles
    SET approved_at = coalesce(approved_at, now()),
        visibility = 'visible',
        suspended_reason = NULL
    WHERE user_id = p_user_id;
  ELSE
    UPDATE public.profiles
    SET approved_at = NULL,
        visibility = CASE
          WHEN visibility IN ('suspended', 'deactivated') THEN visibility
          ELSE 'paused'
        END,
        suspended_reason = coalesce(nullif(trim(p_reason), ''), suspended_reason)
    WHERE user_id = p_user_id;
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

REVOKE ALL ON FUNCTION public.admin_profile_visibility_action(uuid, text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_profile_visibility_action(uuid, text, text) TO authenticated;
