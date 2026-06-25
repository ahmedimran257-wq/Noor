-- Phase 0: separate staff identities from public matrimony accounts.
-- Staff authenticate through auth.users but never need a public.users/profile row.
CREATE TABLE IF NOT EXISTS public.admin_memberships (
  user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  role text NOT NULL CHECK (role IN ('super_admin', 'moderator', 'support')),
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'revoked')),
  mfa_required boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid REFERENCES auth.users(id),
  revoked_at timestamptz,
  revoked_by uuid REFERENCES auth.users(id)
);

CREATE INDEX IF NOT EXISTS idx_admin_memberships_active
  ON public.admin_memberships (role)
  WHERE status = 'active';

CREATE OR REPLACE FUNCTION public.current_admin_role()
RETURNS text
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT role
  FROM public.admin_memberships
  WHERE user_id = auth.uid() AND status = 'active'
  LIMIT 1;
$$;

CREATE OR REPLACE FUNCTION public.is_active_admin(p_roles text[] DEFAULT NULL)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.admin_memberships
    WHERE user_id = auth.uid()
      AND status = 'active'
      AND (p_roles IS NULL OR role = ANY (p_roles))
  );
$$;

REVOKE ALL ON FUNCTION public.current_admin_role() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.is_active_admin(text[]) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.current_admin_role() TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_active_admin(text[]) TO authenticated;

ALTER TABLE public.admin_memberships ENABLE ROW LEVEL SECURITY;

CREATE POLICY admin_memberships_select_self_or_super_admin
  ON public.admin_memberships FOR SELECT
  USING (
    user_id = auth.uid()
    OR public.is_active_admin(ARRAY['super_admin'])
  );

CREATE POLICY admin_memberships_manage_super_admin
  ON public.admin_memberships FOR ALL
  USING (public.is_active_admin(ARRAY['super_admin']))
  WITH CHECK (public.is_active_admin(ARRAY['super_admin']));

-- Existing audit data is retained. New fields make future web actions
-- traceable without exposing the table to ordinary authenticated users.
ALTER TABLE public.admin_audit_log
  ADD COLUMN IF NOT EXISTS actor_role text,
  ADD COLUMN IF NOT EXISTS request_id uuid,
  ADD COLUMN IF NOT EXISTS ip_address inet,
  ADD COLUMN IF NOT EXISTS user_agent text,
  ADD COLUMN IF NOT EXISTS before_state jsonb,
  ADD COLUMN IF NOT EXISTS after_state jsonb;

ALTER TABLE public.admin_audit_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.admin_notifications ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS admin_audit_log_staff_read ON public.admin_audit_log;
CREATE POLICY admin_audit_log_staff_read
  ON public.admin_audit_log FOR SELECT
  USING (public.is_active_admin());

DROP POLICY IF EXISTS admin_notifications_staff_read ON public.admin_notifications;
CREATE POLICY admin_notifications_staff_read
  ON public.admin_notifications FOR SELECT
  USING (public.is_active_admin());

DROP POLICY IF EXISTS admin_notifications_staff_update ON public.admin_notifications;
CREATE POLICY admin_notifications_staff_update
  ON public.admin_notifications FOR UPDATE
  USING (public.is_active_admin())
  WITH CHECK (public.is_active_admin());

-- The obsolete password-hash table remains for data preservation but is not
-- reachable by clients or used by the new panel.
ALTER TABLE public.admins ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.admins FROM anon, authenticated;

COMMENT ON TABLE public.admin_memberships IS
  'Staff-only Supabase Auth membership for the Mithaq web admin panel.';

-- Bootstrap the first super admin manually after creating their Supabase Auth
-- account: INSERT INTO public.admin_memberships (user_id, role) VALUES
-- ('<auth-user-uuid>', 'super_admin');
