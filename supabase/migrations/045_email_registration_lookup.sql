-- ============================================================
-- MIGRATION 045: EMAIL REGISTRATION LOOKUP
-- Lets the client block duplicate signup before sending email OTP.
-- ============================================================

CREATE OR REPLACE FUNCTION public.email_is_registered(p_email text)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.users
    WHERE lower(email) = lower(trim(p_email))
  ) OR EXISTS (
    SELECT 1
    FROM auth.users
    WHERE lower(email) = lower(trim(p_email))
  );
$$;

REVOKE ALL ON FUNCTION public.email_is_registered(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.email_is_registered(text) TO anon, authenticated;
