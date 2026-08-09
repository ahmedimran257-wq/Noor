-- A copied/restored database can retain the credential hash while its Vault
-- entry is absent or no longer matches. Repair both sides atomically whenever
-- deployment automation configures the environment URL.

CREATE OR REPLACE FUNCTION public.configure_backend_project_url(p_url text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_url text := rtrim(trim(coalesce(p_url, '')), '/');
  v_url_secret_id uuid;
  v_cron_secret_id uuid;
  v_cron_secret text;
BEGIN
  IF auth.role() <> 'service_role' THEN
    RAISE EXCEPTION 'service_role_required' USING ERRCODE = '42501';
  END IF;
  IF v_url !~ '^https://[a-z0-9-]+[.]supabase[.]co$'
    OR char_length(v_url) > 200 THEN
    RAISE EXCEPTION 'invalid_backend_project_url' USING ERRCODE = '22023';
  END IF;

  SELECT id INTO v_url_secret_id
  FROM vault.secrets
  WHERE name = 'silarah_supabase_url'
  LIMIT 1;
  IF v_url_secret_id IS NULL THEN
    PERFORM vault.create_secret(
      v_url,
      'silarah_supabase_url',
      'Current Supabase project URL used by private database workers.'
    );
  ELSE
    PERFORM vault.update_secret(
      v_url_secret_id,
      v_url,
      'silarah_supabase_url',
      'Current Supabase project URL used by private database workers.'
    );
  END IF;

  SELECT id, decrypted_secret
  INTO v_cron_secret_id, v_cron_secret
  FROM vault.decrypted_secrets
  WHERE name = 'silarah_edge_cron_secret'
  LIMIT 1;
  IF v_cron_secret_id IS NULL OR nullif(v_cron_secret, '') IS NULL THEN
    v_cron_secret := encode(extensions.gen_random_bytes(32), 'hex');
    IF v_cron_secret_id IS NULL THEN
      PERFORM vault.create_secret(
        v_cron_secret,
        'silarah_edge_cron_secret',
        'Credential used only by database workers to call private Edge Functions.'
      );
    ELSE
      PERFORM vault.update_secret(
        v_cron_secret_id,
        v_cron_secret,
        'silarah_edge_cron_secret',
        'Credential used only by database workers to call private Edge Functions.'
      );
    END IF;
  END IF;

  INSERT INTO public.internal_cron_credentials(name, secret_hash, rotated_at)
  VALUES (
    'edge_cron',
    encode(extensions.digest(v_cron_secret, 'sha256'), 'hex'),
    now()
  )
  ON CONFLICT (name) DO UPDATE SET
    secret_hash = EXCLUDED.secret_hash,
    rotated_at = CASE
      WHEN public.internal_cron_credentials.secret_hash
        IS DISTINCT FROM EXCLUDED.secret_hash THEN now()
      ELSE public.internal_cron_credentials.rotated_at
    END;

  PERFORM private.invoke_notification_dispatch();
END;
$$;

REVOKE ALL ON FUNCTION public.configure_backend_project_url(text)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.configure_backend_project_url(text)
  TO service_role;
