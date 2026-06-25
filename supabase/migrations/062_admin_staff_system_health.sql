-- Phase 4: staff management, system health, and localization coverage.

CREATE OR REPLACE FUNCTION public.admin_staff_members(p_limit integer DEFAULT 100)
RETURNS TABLE(
  user_id uuid,
  email text,
  role text,
  status text,
  mfa_required boolean,
  created_at timestamptz,
  last_sign_in_at timestamptz
)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, auth AS $$
  SELECT m.user_id, au.email::text, m.role, m.status, m.mfa_required,
    m.created_at, au.last_sign_in_at
  FROM public.admin_memberships m
  JOIN auth.users au ON au.id = m.user_id
  WHERE public.is_active_admin(ARRAY['super_admin'])
  ORDER BY m.created_at DESC
  LIMIT least(greatest(p_limit, 1), 100);
$$;

CREATE OR REPLACE FUNCTION public.admin_add_staff_member(p_email text, p_role text)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, auth AS $$
DECLARE
  v_user_id uuid;
BEGIN
  IF NOT public.is_active_admin(ARRAY['super_admin']) THEN
    RAISE EXCEPTION 'Super admin authorization required';
  END IF;
  IF p_role NOT IN ('super_admin','moderator','support') THEN
    RAISE EXCEPTION 'Unsupported staff role';
  END IF;

  SELECT id INTO v_user_id
  FROM auth.users
  WHERE lower(email::text) = lower(trim(p_email))
  LIMIT 1;

  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Staff user must exist in Supabase Auth before membership can be added';
  END IF;

  INSERT INTO public.admin_memberships(user_id, role, status, mfa_required, created_by)
  VALUES (v_user_id, p_role, 'active', true, auth.uid())
  ON CONFLICT (user_id) DO UPDATE
  SET role = excluded.role,
      status = 'active',
      mfa_required = true,
      revoked_at = NULL,
      revoked_by = NULL;

  INSERT INTO public.admin_audit_log(admin_id, actor_role, action_type, details)
  VALUES (auth.uid(), public.current_admin_role(), 'staff_added',
    jsonb_build_object('staff_user_id', v_user_id, 'role', p_role, 'email', lower(trim(p_email))));

  RETURN v_user_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_update_staff_member(
  p_user_id uuid,
  p_role text,
  p_status text,
  p_mfa_required boolean DEFAULT true
)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_active_super_admins integer;
  v_existing_role text;
BEGIN
  IF NOT public.is_active_admin(ARRAY['super_admin']) THEN
    RAISE EXCEPTION 'Super admin authorization required';
  END IF;
  IF p_role NOT IN ('super_admin','moderator','support') THEN
    RAISE EXCEPTION 'Unsupported staff role';
  END IF;
  IF p_status NOT IN ('active','revoked') THEN
    RAISE EXCEPTION 'Unsupported staff status';
  END IF;

  SELECT role INTO v_existing_role
  FROM public.admin_memberships
  WHERE user_id = p_user_id;

  SELECT count(*) INTO v_active_super_admins
  FROM public.admin_memberships
  WHERE role = 'super_admin' AND status = 'active';

  IF v_existing_role = 'super_admin'
     AND (p_status = 'revoked' OR p_role <> 'super_admin')
     AND v_active_super_admins <= 1 THEN
    RAISE EXCEPTION 'Cannot remove the last active super admin';
  END IF;

  UPDATE public.admin_memberships
  SET role = p_role,
      status = p_status,
      mfa_required = coalesce(p_mfa_required, true),
      revoked_at = CASE WHEN p_status = 'revoked' THEN now() ELSE NULL END,
      revoked_by = CASE WHEN p_status = 'revoked' THEN auth.uid() ELSE NULL END
  WHERE user_id = p_user_id;

  INSERT INTO public.admin_audit_log(admin_id, actor_role, action_type, details)
  VALUES (auth.uid(), public.current_admin_role(), 'staff_updated',
    jsonb_build_object('staff_user_id', p_user_id, 'role', p_role, 'status', p_status));
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_system_health()
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT CASE WHEN public.is_active_admin() THEN jsonb_build_object(
    'dueNotifications', (SELECT count(*) FROM notifications WHERE sent_at IS NULL AND scheduled_at <= now()),
    'futureNotifications', (SELECT count(*) FROM notifications WHERE sent_at IS NULL AND scheduled_at > now()),
    'fcmTokenUsers', (SELECT count(DISTINCT user_id) FROM user_fcm_tokens),
    'pendingKyc', (SELECT count(*) FROM profiles WHERE verification_status = 'pending_review'),
    'pendingPhotos', (SELECT count(*) FROM photos WHERE moderation_status = 'pending'),
    'openReports', (SELECT count(*) FROM reports WHERE status = 'pending'),
    'queuedCampaigns', (SELECT count(*) FROM admin_push_campaigns WHERE status = 'queued'),
    'publishedContentPages', (SELECT count(*) FROM app_content_pages WHERE status = 'published'),
    'publishedSuccessStories', (SELECT count(*) FROM marriage_success_stories WHERE status = 'published'),
    'subscriptionEvents24h', (SELECT count(*) FROM subscription_events WHERE created_at >= now() - interval '24 hours'),
    'activeStaff', (SELECT count(*) FROM admin_memberships WHERE status = 'active')
  ) ELSE NULL END;
$$;

CREATE OR REPLACE FUNCTION public.admin_localization_overview()
RETURNS TABLE(locale text, page_count bigint, published_count bigint, last_updated timestamptz)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT p.locale, count(*), count(*) FILTER (WHERE p.status = 'published'), max(p.updated_at)
  FROM app_content_pages p
  WHERE public.is_active_admin()
  GROUP BY p.locale
  ORDER BY p.locale;
$$;

REVOKE ALL ON FUNCTION public.admin_staff_members(integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_add_staff_member(text, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_update_staff_member(uuid, text, text, boolean) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_system_health() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_localization_overview() FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.admin_staff_members(integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_add_staff_member(text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_update_staff_member(uuid, text, text, boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_system_health() TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_localization_overview() TO authenticated;
