-- Admin observability and security controls:
-- audit feed, admin inbox, and durable login-attempt tracking.

CREATE TABLE IF NOT EXISTS public.admin_login_attempts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  email_hash text NOT NULL,
  ip_hash text NOT NULL,
  success boolean NOT NULL DEFAULT false,
  reason text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_admin_login_attempts_email_time
  ON public.admin_login_attempts(email_hash, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_admin_login_attempts_ip_time
  ON public.admin_login_attempts(ip_hash, created_at DESC);

ALTER TABLE public.admin_login_attempts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS admin_login_attempts_staff_read ON public.admin_login_attempts;
CREATE POLICY admin_login_attempts_staff_read
  ON public.admin_login_attempts FOR SELECT
  USING (public.is_active_admin(ARRAY['super_admin']));

CREATE OR REPLACE FUNCTION public.admin_audit_feed(p_limit integer DEFAULT 100)
RETURNS TABLE(
  audit_id uuid,
  admin_id uuid,
  admin_email text,
  actor_role text,
  action_type text,
  target_user_id uuid,
  details jsonb,
  created_at timestamptz
)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, auth AS $$
  SELECT a.id, a.admin_id, au.email::text, a.actor_role, a.action_type,
    a.target_user_id, a.details, a.created_at
  FROM public.admin_audit_log a
  LEFT JOIN auth.users au ON au.id = a.admin_id
  WHERE public.is_active_admin()
  ORDER BY a.created_at DESC
  LIMIT least(greatest(p_limit, 1), 200);
$$;

CREATE OR REPLACE FUNCTION public.admin_inbox(p_limit integer DEFAULT 100)
RETURNS TABLE(
  notification_id uuid,
  type text,
  message text,
  related_user_id uuid,
  is_read boolean,
  created_at timestamptz
)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT n.id, n.type, n.message, n.related_user_id, n.is_read, n.created_at
  FROM public.admin_notifications n
  WHERE public.is_active_admin()
  ORDER BY n.is_read ASC, n.created_at DESC
  LIMIT least(greatest(p_limit, 1), 200);
$$;

CREATE OR REPLACE FUNCTION public.admin_mark_notification_read(p_notification_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.is_active_admin() THEN
    RAISE EXCEPTION 'Staff authorization required';
  END IF;

  UPDATE public.admin_notifications
  SET is_read = true
  WHERE id = p_notification_id;

  INSERT INTO public.admin_audit_log(admin_id, actor_role, action_type, details)
  VALUES (auth.uid(), public.current_admin_role(), 'admin_notification_read',
    jsonb_build_object('notification_id', p_notification_id));
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_mark_all_notifications_read()
RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_count integer := 0;
BEGIN
  IF NOT public.is_active_admin() THEN
    RAISE EXCEPTION 'Staff authorization required';
  END IF;

  UPDATE public.admin_notifications
  SET is_read = true
  WHERE is_read = false;

  GET DIAGNOSTICS v_count = ROW_COUNT;

  INSERT INTO public.admin_audit_log(admin_id, actor_role, action_type, details)
  VALUES (auth.uid(), public.current_admin_role(), 'admin_notifications_read_all',
    jsonb_build_object('count', v_count));

  RETURN v_count;
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_security_metrics()
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT CASE WHEN public.is_active_admin(ARRAY['super_admin']) THEN jsonb_build_object(
    'failedLogins15m', (
      SELECT count(*) FROM admin_login_attempts
      WHERE success = false AND created_at >= now() - interval '15 minutes'
    ),
    'failedLogins24h', (
      SELECT count(*) FROM admin_login_attempts
      WHERE success = false AND created_at >= now() - interval '24 hours'
    ),
    'successfulLogins24h', (
      SELECT count(*) FROM admin_login_attempts
      WHERE success = true AND created_at >= now() - interval '24 hours'
    ),
    'unreadAdminNotifications', (
      SELECT count(*) FROM admin_notifications
      WHERE is_read = false
    ),
    'auditEvents24h', (
      SELECT count(*) FROM admin_audit_log
      WHERE created_at >= now() - interval '24 hours'
    ),
    'activeSuperAdmins', (
      SELECT count(*) FROM admin_memberships
      WHERE role = 'super_admin' AND status = 'active'
    )
  ) ELSE NULL END;
$$;

REVOKE ALL ON FUNCTION public.admin_audit_feed(integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_inbox(integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_mark_notification_read(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_mark_all_notifications_read() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_security_metrics() FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.admin_audit_feed(integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_inbox(integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_mark_notification_read(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_mark_all_notifications_read() TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_security_metrics() TO authenticated;
