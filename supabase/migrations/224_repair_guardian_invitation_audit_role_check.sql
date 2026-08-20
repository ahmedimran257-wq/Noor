-- Repair the operational audit guard to use Supabase's built-in request role.
-- The Guardian runtime functions were already active; only this service-role
-- diagnostic referenced a helper that does not exist in this project.
CREATE OR REPLACE FUNCTION public.audit_guardian_invitation_wiring()
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  IF auth.role() <> 'service_role' THEN
    RAISE EXCEPTION 'service_role_required' USING ERRCODE = '42501';
  END IF;
  RETURN jsonb_build_object(
    'hashed_codes', true,
    'firebase_phone_column', EXISTS (
      SELECT 1 FROM information_schema.columns
      WHERE table_schema = 'public' AND table_name = 'users'
        AND column_name = 'phone_verified_at'
    ),
    'guardian_account_roles', EXISTS (
      SELECT 1 FROM information_schema.columns
      WHERE table_schema = 'public' AND table_name = 'users'
        AND column_name = 'account_role'
    ),
    'pending_invitations', (
      SELECT count(*) FROM public.profiles p
      WHERE p.guardian_invitation_token_hash IS NOT NULL
        AND p.guardian_user_id IS NULL
        AND p.guardian_invitation_expires_at > now()
    )
  );
END;
$$;

REVOKE ALL ON FUNCTION public.audit_guardian_invitation_wiring()
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.audit_guardian_invitation_wiring()
  TO service_role;

NOTIFY pgrst, 'reload schema';
