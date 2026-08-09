-- Every hosted environment has a different project URL. Keep that value in
-- Vault and expose a service-role-only bootstrap RPC so deployment automation
-- can configure worker callbacks without committing an environment URL.

CREATE OR REPLACE FUNCTION public.configure_backend_project_url(p_url text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_url text := rtrim(trim(coalesce(p_url, '')), '/');
  v_secret_id uuid;
BEGIN
  IF auth.role() <> 'service_role' THEN
    RAISE EXCEPTION 'service_role_required' USING ERRCODE = '42501';
  END IF;
  IF v_url !~ '^https://[a-z0-9-]+[.]supabase[.]co$'
    OR char_length(v_url) > 200 THEN
    RAISE EXCEPTION 'invalid_backend_project_url' USING ERRCODE = '22023';
  END IF;

  SELECT id INTO v_secret_id
  FROM vault.secrets
  WHERE name = 'silarah_supabase_url'
  LIMIT 1;

  IF v_secret_id IS NULL THEN
    PERFORM vault.create_secret(
      v_url,
      'silarah_supabase_url',
      'Current Supabase project URL used by private database workers.'
    );
  ELSE
    PERFORM vault.update_secret(
      v_secret_id,
      v_url,
      'silarah_supabase_url',
      'Current Supabase project URL used by private database workers.'
    );
  END IF;

  PERFORM private.invoke_notification_dispatch();
END;
$$;

REVOKE ALL ON FUNCTION public.configure_backend_project_url(text)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.configure_backend_project_url(text)
  TO service_role;
