-- ============================================================
-- MIGRATION 046: DISPOSABLE EMAIL PROTECTION
-- Blocks known disposable inbox providers for Mithaq account creation.
--
-- The Flutter guard improves UX. This table is the authoritative, maintainable
-- server-side list consumed by the Before User Created Auth Hook scaffold.
-- Configure that hook in Supabase Auth before relying on this protection.
-- ============================================================

CREATE TABLE IF NOT EXISTS public.disposable_email_domains (
  domain text PRIMARY KEY,
  created_at timestamptz NOT NULL DEFAULT now(),
  CHECK (domain = lower(domain))
);

ALTER TABLE public.disposable_email_domains ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.disposable_email_domains FROM anon, authenticated;
GRANT SELECT ON TABLE public.disposable_email_domains TO service_role;

INSERT INTO public.disposable_email_domains (domain) VALUES
  ('10minutemail.com'),
  ('10minutemail.net'),
  ('dispostable.com'),
  ('emailondeck.com'),
  ('fakeinbox.com'),
  ('getnada.com'),
  ('grr.la'),
  ('guerrillamail.com'),
  ('guerrillamail.net'),
  ('guerrillamail.org'),
  ('harakirimail.com'),
  ('maildrop.cc'),
  ('mailinator.com'),
  ('mailinator.net'),
  ('minuteinbox.com'),
  ('moakt.com'),
  ('sharklasers.com'),
  ('spam4.me'),
  ('temp-mail.io'),
  ('temp-mail.org'),
  ('tempail.com'),
  ('tempmail.com'),
  ('throwawaymail.com'),
  ('trashmail.com'),
  ('yopmail.com'),
  ('yopmail.fr')
ON CONFLICT (domain) DO NOTHING;

COMMENT ON TABLE public.disposable_email_domains IS
  'Authoritative disposable-email denylist. Maintain this table as providers change; Gmail, Outlook, Yahoo, iCloud, Proton, Zoho, and normal business domains are intentionally not allowlisted.';

-- Used by trusted server code and useful for smoke tests. Do not expose this
-- as a signup authorization boundary: enable the Auth Hook below for that.
CREATE OR REPLACE FUNCTION public.is_disposable_email_domain(p_email text)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  WITH email_domain AS (
    SELECT lower(split_part(trim(p_email), '@', 2)) AS domain
  )
  SELECT EXISTS (
    SELECT 1
    FROM public.disposable_email_domains blocked, email_domain input
    WHERE input.domain = blocked.domain
       OR input.domain LIKE '%.' || blocked.domain
  );
$$;

REVOKE ALL ON FUNCTION public.is_disposable_email_domain(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.is_disposable_email_domain(text) TO service_role;
