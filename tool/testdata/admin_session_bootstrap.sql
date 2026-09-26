-- Synthetic local auth plumbing only; production auth.sessions is Auth-owned.
CREATE ROLE service_role NOLOGIN;
CREATE TABLE auth.sessions (
  id uuid PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES auth.users(id),
  created_at timestamptz NOT NULL DEFAULT now(),
  not_after timestamptz
);
CREATE OR REPLACE FUNCTION auth.jwt() RETURNS jsonb LANGUAGE sql STABLE AS $$
  SELECT jsonb_build_object(
    'aal', current_setting('request.jwt.claim.aal', true),
    'session_id', current_setting('request.jwt.claim.session_id', true)
  );
$$;
CREATE FUNCTION auth.role() RETURNS text LANGUAGE sql STABLE AS $$
  SELECT current_setting('request.jwt.claim.role', true);
$$;
