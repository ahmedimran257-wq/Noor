-- Disposable local PostgreSQL only. No Supabase credentials or CLI linkage.
CREATE ROLE anon NOLOGIN;
CREATE ROLE authenticated NOLOGIN;
CREATE SCHEMA auth;
CREATE SCHEMA private;
CREATE SCHEMA extensions;
CREATE EXTENSION pgcrypto WITH SCHEMA extensions;
CREATE TABLE auth.users(id uuid PRIMARY KEY, email text, email_confirmed_at timestamptz, phone text);
CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS $$
  SELECT nullif(current_setting('request.jwt.claim.sub', true), '')::uuid
$$;
CREATE FUNCTION private.assert_authenticated() RETURNS uuid LANGUAGE plpgsql AS $$
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'authentication_required'; END IF;
  RETURN auth.uid();
END;
$$;
CREATE TABLE public.users(id uuid PRIMARY KEY REFERENCES auth.users(id), email text,
  phone text, country_code text, gender text, onboarding_completed boolean DEFAULT false);
CREATE TABLE public.user_consents(user_id uuid REFERENCES public.users(id), consent_type text,
  version text, granted_at timestamptz, revoked_at timestamptz, evidence_source text,
  policy_digest text, UNIQUE(user_id,consent_type,version));
CREATE FUNCTION public.record_onboarding_consents(text) RETURNS void LANGUAGE sql AS $$ SELECT $$;
CREATE FUNCTION public.download_my_data(text DEFAULT NULL) RETURNS jsonb LANGUAGE sql AS $$
  SELECT jsonb_build_object('consents', coalesce((SELECT jsonb_agg(to_jsonb(c))
    FROM public.user_consents c WHERE user_id = auth.uid()), '[]'::jsonb))
$$;
CREATE TABLE private.rate_calls(scope text, attempts integer, seconds integer);
CREATE FUNCTION private.enforce_pre_auth_rate_limit(text,integer,integer) RETURNS void LANGUAGE sql AS $$
  INSERT INTO private.rate_calls VALUES ($1,$2,$3)
$$;
GRANT USAGE ON SCHEMA public, auth TO anon, authenticated;
CREATE SCHEMA test;
GRANT USAGE ON SCHEMA test TO anon, authenticated;
CREATE FUNCTION test.assert(ok boolean, label text) RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  IF ok IS DISTINCT FROM true THEN RAISE EXCEPTION 'FAIL: %', label; END IF;
  RAISE NOTICE 'PASS: %', label;
END;
$$;
CREATE FUNCTION test.reject(statement text, expected text) RETURNS void LANGUAGE plpgsql AS $$
DECLARE actual text;
BEGIN
  BEGIN EXECUTE statement; EXCEPTION WHEN OTHERS THEN actual := SQLERRM; END;
  IF actual IS NULL OR position(expected IN actual) = 0 THEN
    RAISE EXCEPTION 'FAIL: expected %, received %', expected, coalesce(actual,'success');
  END IF;
  RAISE NOTICE 'PASS: rejected with %', expected;
END;
$$;
