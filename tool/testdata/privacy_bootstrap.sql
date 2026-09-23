-- Disposable local database only. Mimics JWT/auth plumbing, not Supabase itself.
CREATE ROLE anon NOLOGIN;
CREATE ROLE authenticated NOLOGIN;
CREATE SCHEMA auth;
CREATE SCHEMA private;
CREATE TABLE auth.users (id uuid PRIMARY KEY);
CREATE TABLE public.admin_memberships (user_id uuid PRIMARY KEY, role text, status text);
CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS $$
 SELECT nullif(current_setting('request.jwt.claim.sub', true), '')::uuid
$$;
CREATE FUNCTION auth.jwt() RETURNS jsonb LANGUAGE sql STABLE AS $$
 SELECT jsonb_build_object('aal', current_setting('request.jwt.claim.aal', true))
$$;
GRANT USAGE ON SCHEMA public, auth TO authenticated, anon;
CREATE SCHEMA test;
GRANT USAGE ON SCHEMA test TO authenticated, anon;
CREATE FUNCTION test.assert(ok boolean, label text) RETURNS void LANGUAGE plpgsql AS $$
BEGIN
 IF ok IS DISTINCT FROM true THEN RAISE EXCEPTION 'FAIL: %', label; END IF;
 RAISE NOTICE 'PASS: %', label;
END;
$$;
CREATE FUNCTION test.reject(statement text, expected text) RETURNS void LANGUAGE plpgsql AS $$
DECLARE actual text;
BEGIN
 BEGIN
   EXECUTE statement;
 EXCEPTION WHEN OTHERS THEN actual := SQLERRM;
 END;
 IF actual IS NULL OR position(expected IN actual) = 0 THEN
   RAISE EXCEPTION 'FAIL: expected %, received %', expected, coalesce(actual, 'success');
 END IF;
 RAISE NOTICE 'PASS: rejected with %', expected;
END;
$$;
