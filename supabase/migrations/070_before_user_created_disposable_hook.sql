-- Server-side Auth Hook for disposable-email blocking.
--
-- Flutter validation is UX only. This Postgres hook is wired via
-- [auth.hook.before_user_created] so direct Supabase Auth API calls cannot
-- bypass the disposable-domain denylist.

CREATE OR REPLACE FUNCTION public.hook_before_user_created(event jsonb)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_email text;
BEGIN
  v_email := lower(trim(coalesce(event->'user'->>'email', '')));

  IF v_email = '' OR position('@' IN v_email) = 0 THEN
    RETURN jsonb_build_object(
      'error', jsonb_build_object(
        'http_code', 400,
        'message', 'Please enter a valid email address.'
      )
    );
  END IF;

  IF public.is_disposable_email_domain(v_email) THEN
    RETURN jsonb_build_object(
      'error', jsonb_build_object(
        'http_code', 400,
        'message', 'Temporary or disposable email addresses are not allowed. Please use a real personal email address.'
      )
    );
  END IF;

  RETURN '{}'::jsonb;
EXCEPTION
  WHEN others THEN
    -- Fail closed so fake-account protection is not bypassed during lookup
    -- failures. The message is intentionally user-safe.
    RETURN jsonb_build_object(
      'error', jsonb_build_object(
        'http_code', 503,
        'message', 'We could not validate this email address. Please try again.'
      )
    );
END;
$$;

GRANT USAGE ON SCHEMA public TO supabase_auth_admin;
GRANT EXECUTE ON FUNCTION public.hook_before_user_created(jsonb) TO supabase_auth_admin;
GRANT EXECUTE ON FUNCTION public.is_disposable_email_domain(text) TO supabase_auth_admin;

REVOKE EXECUTE ON FUNCTION public.hook_before_user_created(jsonb)
  FROM anon, authenticated, public;

COMMENT ON FUNCTION public.hook_before_user_created(jsonb) IS
  'Before User Created Auth Hook. Blocks disposable email domains before auth.users rows are created.';
