-- Audit 1 admin containment: the database, not only Next.js, requires AAL2.

CREATE OR REPLACE FUNCTION public.is_active_admin(p_roles text[] DEFAULT NULL)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT
    auth.uid() IS NOT NULL
    AND coalesce(auth.jwt()->>'aal', '') = 'aal2'
    AND EXISTS (
      SELECT 1
      FROM public.admin_memberships m
      WHERE m.user_id = auth.uid()
        AND m.status = 'active'
        AND (p_roles IS NULL OR m.role = ANY (p_roles))
    );
$$;

CREATE OR REPLACE FUNCTION public.admin_update_staff_member(
  p_user_id uuid,
  p_role text,
  p_status text,
  p_mfa_required boolean DEFAULT true
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_active_super_admins integer;
  v_before public.admin_memberships%ROWTYPE;
  v_after public.admin_memberships%ROWTYPE;
BEGIN
  IF NOT public.is_active_admin(ARRAY['super_admin']) THEN
    RAISE EXCEPTION 'aal2_super_admin_required' USING ERRCODE = 'P0001';
  END IF;
  IF p_role NOT IN ('super_admin','moderator','support')
    OR p_status NOT IN ('active','revoked') THEN
    RAISE EXCEPTION 'invalid_staff_transition' USING ERRCODE = 'P0001';
  END IF;

  PERFORM pg_advisory_xact_lock(hashtextextended('active-super-admin', 74));
  SELECT * INTO v_before
  FROM public.admin_memberships
  WHERE user_id = p_user_id
  FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'staff_member_not_found' USING ERRCODE = 'P0001';
  END IF;

  SELECT count(*) INTO v_active_super_admins
  FROM public.admin_memberships
  WHERE role = 'super_admin' AND status = 'active';

  IF v_before.role = 'super_admin'
    AND v_before.status = 'active'
    AND (p_status = 'revoked' OR p_role <> 'super_admin')
    AND v_active_super_admins <= 1 THEN
    RAISE EXCEPTION 'cannot_remove_last_super_admin' USING ERRCODE = 'P0001';
  END IF;

  UPDATE public.admin_memberships
  SET role = p_role,
      status = p_status,
      mfa_required = coalesce(p_mfa_required, true),
      revoked_at = CASE WHEN p_status = 'revoked' THEN now() ELSE NULL END,
      revoked_by = CASE WHEN p_status = 'revoked' THEN auth.uid() ELSE NULL END
  WHERE user_id = p_user_id
  RETURNING * INTO v_after;

  INSERT INTO public.admin_audit_log(
    admin_id, actor_role, action_type, target_user_id,
    before_state, after_state, details
  )
  VALUES (
    auth.uid(), public.current_admin_role(), 'staff_updated', p_user_id,
    to_jsonb(v_before), to_jsonb(v_after),
    jsonb_build_object('aal', auth.jwt()->>'aal')
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_add_staff_member(
  p_email text,
  p_role text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_user_id uuid;
  v_after public.admin_memberships%ROWTYPE;
BEGIN
  IF NOT public.is_active_admin(ARRAY['super_admin']) THEN
    RAISE EXCEPTION 'aal2_super_admin_required' USING ERRCODE = 'P0001';
  END IF;
  IF p_role NOT IN ('super_admin','moderator','support') THEN
    RAISE EXCEPTION 'invalid_staff_role' USING ERRCODE = 'P0001';
  END IF;
  SELECT id INTO v_user_id
  FROM auth.users
  WHERE lower(email::text) = lower(trim(p_email))
  LIMIT 1;
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'staff_auth_user_not_found' USING ERRCODE = 'P0001';
  END IF;

  PERFORM pg_advisory_xact_lock(hashtextextended('active-super-admin', 74));
  INSERT INTO public.admin_memberships(
    user_id, role, status, mfa_required, created_by
  )
  VALUES (v_user_id, p_role, 'active', true, auth.uid())
  ON CONFLICT (user_id) DO UPDATE SET
    role = excluded.role,
    status = 'active',
    mfa_required = true,
    revoked_at = NULL,
    revoked_by = NULL
  RETURNING * INTO v_after;

  INSERT INTO public.admin_audit_log(
    admin_id, actor_role, action_type, target_user_id, after_state, details
  )
  VALUES (
    auth.uid(), public.current_admin_role(), 'staff_added', v_user_id,
    to_jsonb(v_after),
    jsonb_build_object(
      'email_hash',
      encode(extensions.digest(lower(trim(p_email)), 'sha256'), 'hex')
    )
  );
  RETURN v_user_id;
END;
$$;

-- Service-role-only atomic login throttle. Starting an attempt consumes a
-- slot before password verification, so parallel requests cannot race.
CREATE OR REPLACE FUNCTION public.begin_admin_login_attempt(
  p_email_hash text,
  p_ip_hash text
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_attempt_id uuid;
  v_failures integer;
BEGIN
  IF auth.role() <> 'service_role'
    OR p_email_hash !~ '^[0-9a-f]{64}$'
    OR p_ip_hash !~ '^[0-9a-f]{64}$' THEN
    RAISE EXCEPTION 'login_throttle_unavailable' USING ERRCODE = 'P0001';
  END IF;
  PERFORM pg_advisory_xact_lock(
    hashtextextended(p_email_hash || ':' || p_ip_hash, 75)
  );
  SELECT count(*) INTO v_failures
  FROM public.admin_login_attempts
  WHERE success = false
    AND created_at >= now() - interval '15 minutes'
    AND (email_hash = p_email_hash OR ip_hash = p_ip_hash);
  IF v_failures >= 8 THEN
    RAISE EXCEPTION 'login_rate_limited' USING ERRCODE = 'P0001';
  END IF;
  INSERT INTO public.admin_login_attempts(
    email_hash, ip_hash, success, reason
  )
  VALUES (p_email_hash, p_ip_hash, false, 'attempt_started')
  RETURNING id INTO v_attempt_id;
  RETURN v_attempt_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.finish_admin_login_attempt(
  p_attempt_id uuid,
  p_success boolean,
  p_reason text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  IF auth.role() <> 'service_role' THEN
    RAISE EXCEPTION 'service_role_required' USING ERRCODE = 'P0001';
  END IF;
  UPDATE public.admin_login_attempts
  SET success = p_success,
      reason = left(coalesce(p_reason, 'unknown'), 80)
  WHERE id = p_attempt_id AND reason = 'attempt_started';
END;
$$;

REVOKE ALL ON FUNCTION public.begin_admin_login_attempt(text, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.finish_admin_login_attempt(uuid, boolean, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.begin_admin_login_attempt(text, text) TO service_role;
GRANT EXECUTE ON FUNCTION public.finish_admin_login_attempt(uuid, boolean, text) TO service_role;

-- Preserve self-read for the MFA enrollment gate. Privileged table/RPC paths
-- call is_active_admin(), which now requires AAL2.
DROP POLICY IF EXISTS admin_memberships_select_self_or_super_admin
  ON public.admin_memberships;
CREATE POLICY admin_memberships_select_self_or_super_admin
  ON public.admin_memberships
  FOR SELECT TO authenticated
  USING (
    user_id = auth.uid()
    OR public.is_active_admin(ARRAY['super_admin'])
  );
