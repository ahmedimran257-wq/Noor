-- Defense in depth for signup: a user authenticated outside the Flutter app
-- still cannot create a usable public Mithaq account with a blocked domain.
CREATE OR REPLACE FUNCTION public.enforce_non_disposable_public_user_email()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.email IS NOT NULL
      AND public.is_disposable_email_domain(NEW.email) THEN
    RAISE EXCEPTION
      'Temporary or disposable email addresses are not allowed. Please use a real personal email address.';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_enforce_non_disposable_public_user_email ON public.users;
CREATE TRIGGER trg_enforce_non_disposable_public_user_email
  BEFORE INSERT OR UPDATE OF email ON public.users
  FOR EACH ROW
  EXECUTE FUNCTION public.enforce_non_disposable_public_user_email();
