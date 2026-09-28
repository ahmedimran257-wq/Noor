-- Enforce the staff lifetime at every RPC/RLS entry point, not only Next.js.
-- The Auth session, not a refreshed JWT's iat or first dashboard visit, owns
-- the clock. Missing/revoked sessions fail closed without changing member TTLs.
CREATE OR REPLACE FUNCTION private.admin_session_deadline()
RETURNS timestamptz
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT least(session.created_at + interval '12 hours', session.not_after)
  FROM auth.sessions session
  WHERE auth.uid() IS NOT NULL
    AND session.id = nullif(auth.jwt()->>'session_id', '')::uuid
    AND session.user_id = auth.uid()
    AND session.created_at IS NOT NULL;
$$;

REVOKE ALL ON FUNCTION private.admin_session_deadline()
  FROM PUBLIC, anon, authenticated, service_role;

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
    AND coalesce(private.admin_session_deadline() > now(), false)
    AND EXISTS (
      SELECT 1 FROM public.admin_memberships membership
      WHERE membership.user_id = auth.uid()
        AND membership.status = 'active'
        AND (p_roles IS NULL OR membership.role = ANY (p_roles))
    );
$$;

CREATE OR REPLACE FUNCTION public.assert_admin_session_boundary(p_session_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_admin_id uuid := private.assert_authenticated();
  v_session_id uuid := nullif(auth.jwt()->>'session_id', '')::uuid;
  v_deadline timestamptz := private.admin_session_deadline();
  v_allowed boolean := false;
BEGIN
  IF p_session_id IS NULL OR p_session_id IS DISTINCT FROM v_session_id
    OR v_deadline IS NULL OR v_deadline <= now()
    OR NOT EXISTS (
      SELECT 1 FROM public.admin_memberships membership
      WHERE membership.user_id = v_admin_id AND membership.status = 'active'
    ) THEN
    RETURN false;
  END IF;

  -- This gate also serves MFA enrollment; privileged RPCs separately require
  -- AAL2 through is_active_admin(). Never grant admin access at AAL1.
  INSERT INTO private.admin_session_boundaries(session_id, admin_id, expires_at)
  VALUES (p_session_id, v_admin_id, v_deadline)
  ON CONFLICT (session_id) DO NOTHING;

  UPDATE private.admin_session_boundaries boundary
  SET last_seen_at = now(),
      expires_at = least(boundary.expires_at, v_deadline)
  WHERE boundary.session_id = p_session_id
    AND boundary.admin_id = v_admin_id
    AND boundary.expires_at > now()
  RETURNING true INTO v_allowed;

  RETURN coalesce(v_allowed, false);
END;
$$;

REVOKE ALL ON FUNCTION public.is_active_admin(text[]) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.is_active_admin(text[]) TO authenticated;
REVOKE ALL ON FUNCTION public.assert_admin_session_boundary(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.assert_admin_session_boundary(uuid) TO authenticated;

COMMENT ON FUNCTION public.is_active_admin(text[]) IS
  'Active staff membership, AAL2 and a live Auth session less than 12 hours old are required by every privileged RPC/RLS consumer.';
COMMENT ON FUNCTION public.assert_admin_session_boundary(uuid) IS
  'Binds the requested session to the JWT and Auth owner; records a deadline no later than 12 hours after sign-in.';

NOTIFY pgrst, 'reload schema';
