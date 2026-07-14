-- User-facing notifications for admin decisions.
-- These rows power both in-app realtime notifications and the FCM dispatcher.

CREATE OR REPLACE FUNCTION public.admin_account_action(p_user_id uuid, p_action text, p_reason text DEFAULT NULL)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_profile public.profiles%ROWTYPE;
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
    UPDATE public.users
    SET is_shadowbanned = false, shadowbanned_at = NULL, shadowban_reason = NULL
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
      '/home?tab=3'
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

CREATE OR REPLACE FUNCTION public.admin_review_kyc(p_user_id uuid, p_decision text, p_reason text DEFAULT NULL)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT public.is_active_admin(ARRAY['super_admin','moderator']) THEN
    RAISE EXCEPTION 'Staff authorization required';
  END IF;

  IF p_decision = 'approve' THEN
    UPDATE public.profiles
    SET kyc_verified = true,
        is_verified = true,
        verification_status = 'verified',
        verified_at = now()
    WHERE user_id = p_user_id;

    PERFORM public.queue_notification(
      p_user_id,
      'kyc_approved',
      'Verification approved',
      'Your verification badge has been approved.',
      '/home?tab=3'
    );
  ELSIF p_decision IN ('reject','resubmit') THEN
    UPDATE public.profiles
    SET kyc_verified = false,
        verification_status = 'unverified'
    WHERE user_id = p_user_id;

    PERFORM public.queue_notification(
      p_user_id,
      'kyc_rejected',
      'Verification needs attention',
      'Your verification could not be approved. Please review and try again.',
      '/verify'
    );
  ELSE
    RAISE EXCEPTION 'Unsupported KYC decision';
  END IF;

  INSERT INTO public.admin_audit_log(admin_id, actor_role, action_type, target_user_id, details)
  VALUES (
    auth.uid(),
    public.current_admin_role(),
    'kyc_' || p_decision,
    p_user_id,
    jsonb_build_object('reason', p_reason)
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_review_photo(p_photo_id uuid, p_decision text, p_reason text DEFAULT NULL)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_target uuid;
BEGIN
  IF NOT public.is_active_admin(ARRAY['super_admin','moderator']) THEN
    RAISE EXCEPTION 'Staff authorization required';
  END IF;

  IF p_decision = 'approve' THEN
    UPDATE public.photos
    SET moderation_status = 'approved',
        moderation_reason = p_reason,
        moderated_at = now(),
        moderated_by = auth.uid(),
        admin_approved = true,
        nsfw_cleared = true,
        status = 'active'
    WHERE id = p_photo_id
    RETURNING (SELECT user_id FROM public.profiles WHERE id = photos.profile_id) INTO v_target;

    PERFORM public.queue_notification(
      v_target,
      'photo_approved',
      'Photo approved',
      'Your profile photo has been approved.',
      '/home?tab=3'
    );
  ELSIF p_decision = 'reject' THEN
    UPDATE public.photos
    SET moderation_status = 'rejected',
        moderation_reason = p_reason,
        moderated_at = now(),
        moderated_by = auth.uid(),
        admin_approved = false,
        nsfw_cleared = false
    WHERE id = p_photo_id
    RETURNING (SELECT user_id FROM public.profiles WHERE id = photos.profile_id) INTO v_target;

    PERFORM public.queue_notification(
      v_target,
      'photo_rejected',
      'Photo rejected',
      'A profile photo could not be accepted. Please upload a clear, respectful photo showing your face.',
      '/home?tab=3'
    );
  ELSE
    RAISE EXCEPTION 'Unsupported photo decision';
  END IF;

  INSERT INTO public.admin_audit_log(admin_id, actor_role, action_type, target_user_id, details)
  VALUES (
    auth.uid(),
    public.current_admin_role(),
    'photo_' || p_decision,
    v_target,
    jsonb_build_object('photo_id', p_photo_id, 'reason', p_reason)
  );
END;
$$;

REVOKE ALL ON FUNCTION public.admin_account_action(uuid, text, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_profile_visibility_action(uuid, text, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_review_kyc(uuid, text, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_review_photo(uuid, text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_account_action(uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_profile_visibility_action(uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_review_kyc(uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_review_photo(uuid, text, text) TO authenticated;
