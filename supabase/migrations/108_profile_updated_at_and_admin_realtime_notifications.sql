-- Keep profile visibility/settings writes compatible across existing projects.
-- Some live databases were created before profiles.updated_at existed, while
-- current server-side pause/profile actions rely on it for audit ordering.

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS updated_at timestamptz NOT NULL DEFAULT now();

CREATE OR REPLACE FUNCTION public.touch_profile_updated_at()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS profiles_touch_updated_at ON public.profiles;
CREATE TRIGGER profiles_touch_updated_at
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.touch_profile_updated_at();

CREATE INDEX IF NOT EXISTS idx_profiles_updated_at
  ON public.profiles(updated_at DESC);

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
  v_profile public.profiles%ROWTYPE;
  v_is_banned boolean;
BEGIN
  IF NOT public.is_active_admin(ARRAY['super_admin','moderator']) THEN
    RAISE EXCEPTION 'Staff authorization required';
  END IF;

  IF p_action IN ('ban', 'shadowban') AND NOT public.is_active_admin(ARRAY['super_admin']) THEN
    RAISE EXCEPTION 'Super admin authorization required';
  END IF;

  SELECT *
  INTO v_profile
  FROM public.profiles
  WHERE user_id = p_user_id
  FOR UPDATE;

  SELECT coalesce(is_banned, false)
  INTO v_is_banned
  FROM public.users
  WHERE id = p_user_id
  FOR UPDATE;

  IF p_action = 'suspend' THEN
    UPDATE public.profiles
    SET visibility = 'suspended',
        suspended_reason = coalesce(nullif(trim(p_reason), ''), 'admin_suspension')
    WHERE user_id = p_user_id;

    PERFORM public.queue_notification(
      p_user_id,
      'account_suspended',
      'Profile suspended',
      'Your Mithaq profile has been suspended. Please contact support if you believe this is a mistake.',
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
    SET visibility = CASE
          WHEN approved_at IS NOT NULL THEN 'visible'
          ELSE 'paused'
        END,
        suspended_reason = NULL
    WHERE user_id = p_user_id;

    PERFORM public.queue_notification(
      p_user_id,
      'account_restored',
      'Profile restored',
      CASE
        WHEN v_profile.approved_at IS NOT NULL THEN 'Your Mithaq profile has been restored and is visible again.'
        ELSE 'Your Mithaq profile has been restored and is waiting for profile approval.'
      END,
      '/home?tab=3'
    );
  ELSIF p_action = 'shadowban' THEN
    UPDATE public.users
    SET is_shadowbanned = true,
        shadowbanned_at = now(),
        shadowban_reason = coalesce(nullif(trim(p_reason), ''), 'admin_shadowban')
    WHERE id = p_user_id;

    PERFORM public.queue_notification(
      p_user_id,
      'account_limited',
      'Profile reach limited',
      'Your profile reach has been limited while the Mithaq team reviews account activity.',
      '/help-support'
    );
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
      'Your Mithaq account has been banned for violating community guidelines.',
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
    jsonb_build_object('reason', p_reason)
  );
END;
$$;

REVOKE ALL ON FUNCTION public.admin_account_action(uuid, text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_account_action(uuid, text, text) TO authenticated;
