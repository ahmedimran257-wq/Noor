-- An OTP request creates auth.users before the code is verified. Treating
-- mere row existence as a completed registration traps users who leave the
-- OTP screen and later try to continue signup.

CREATE OR REPLACE FUNCTION public.email_registration_status(p_email text)
RETURNS text
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, auth
AS $$
  SELECT CASE
    WHEN EXISTS (
      SELECT 1
      FROM auth.users
      WHERE lower(email) = lower(trim(p_email))
        AND email_confirmed_at IS NOT NULL
    ) THEN 'registered'
    WHEN EXISTS (
      SELECT 1
      FROM auth.users
      WHERE lower(email) = lower(trim(p_email))
    ) THEN 'pending_verification'
    ELSE 'unregistered'
  END;
$$;

REVOKE ALL ON FUNCTION public.email_registration_status(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.email_registration_status(text)
  TO anon, authenticated;

-- Keep the old RPC compatible for older app builds, but make its meaning
-- precise: registered means that the email OTP has actually been verified.
CREATE OR REPLACE FUNCTION public.email_is_registered(p_email text)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, auth
AS $$
  SELECT public.email_registration_status(p_email) = 'registered';
$$;

REVOKE ALL ON FUNCTION public.email_is_registered(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.email_is_registered(text)
  TO anon, authenticated;

COMMENT ON FUNCTION public.email_registration_status(text) IS
  'Returns unregistered, pending_verification, or registered based on authoritative Supabase Auth email confirmation state.';
