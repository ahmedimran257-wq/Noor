-- Access-token iat changes whenever Supabase refreshes a token, so it cannot
-- enforce an absolute staff session lifetime. session_id remains stable for
-- the underlying Auth session and is bounded here server-side.
CREATE TABLE IF NOT EXISTS private.admin_session_boundaries (
  session_id uuid PRIMARY KEY,
  admin_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  started_at timestamptz NOT NULL DEFAULT now(),
  last_seen_at timestamptz NOT NULL DEFAULT now(),
  expires_at timestamptz NOT NULL DEFAULT now() + interval '12 hours',
  CONSTRAINT admin_session_boundary_time_order
    CHECK (expires_at > started_at)
);

CREATE INDEX IF NOT EXISTS idx_admin_session_boundaries_expiry
  ON private.admin_session_boundaries(expires_at);

REVOKE ALL ON private.admin_session_boundaries
  FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.assert_admin_session_boundary(
  p_session_id uuid
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_admin_id uuid := private.assert_authenticated();
  v_allowed boolean := false;
BEGIN
  IF p_session_id IS NULL OR NOT EXISTS (
    SELECT 1 FROM public.admin_memberships membership
    WHERE membership.user_id = v_admin_id
      AND membership.status = 'active'
  ) THEN
    RETURN false;
  END IF;

  INSERT INTO private.admin_session_boundaries(session_id, admin_id)
  VALUES (p_session_id, v_admin_id)
  ON CONFLICT (session_id) DO NOTHING;

  UPDATE private.admin_session_boundaries boundary
  SET last_seen_at = now()
  WHERE boundary.session_id = p_session_id
    AND boundary.admin_id = v_admin_id
    AND boundary.expires_at > now()
  RETURNING true INTO v_allowed;

  RETURN coalesce(v_allowed, false);
END;
$$;

REVOKE ALL ON FUNCTION public.assert_admin_session_boundary(uuid)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.assert_admin_session_boundary(uuid)
  TO authenticated;

COMMENT ON FUNCTION public.assert_admin_session_boundary(uuid) IS
  'Enforces an absolute 12-hour staff session using the stable Supabase Auth session_id claim.';

NOTIFY pgrst, 'reload schema';
