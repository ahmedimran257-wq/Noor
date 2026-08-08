-- The welcome screen must verify referral existence before showing success.
-- The result reveals only whether an exact six-character code exists.
CREATE OR REPLACE FUNCTION public.validate_referral_code(p_code text)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT CASE
    WHEN upper(trim(coalesce(p_code, ''))) !~ '^[A-Z0-9]{6}$' THEN false
    ELSE EXISTS (
      SELECT 1
      FROM public.referral_codes rc
      WHERE rc.code = upper(trim(p_code))
    )
  END;
$$;

REVOKE ALL ON FUNCTION public.validate_referral_code(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.validate_referral_code(text)
  TO anon, authenticated;

COMMENT ON FUNCTION public.validate_referral_code(text) IS
  'Exact-code existence check for pre-auth referral validation; returns no owner or usage data.';
