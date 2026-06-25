-- Admin boundary hardening:
-- - user directory is paginated and masked by default
-- - PII reveal is a separate audited operation
-- - account actions enforce RBAC inside SQL as well as server actions
-- - bulk account actions are capped and audited
-- - queue locks prevent duplicate KYC/moderation work

ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS is_shadowbanned boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS shadowbanned_at timestamptz,
  ADD COLUMN IF NOT EXISTS shadowban_reason text;

CREATE TABLE IF NOT EXISTS public.admin_work_locks (
  item_type text NOT NULL CHECK (item_type IN ('kyc', 'report', 'photo')),
  item_id uuid NOT NULL,
  locked_by uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  locked_at timestamptz NOT NULL DEFAULT now(),
  expires_at timestamptz NOT NULL DEFAULT (now() + interval '15 minutes'),
  PRIMARY KEY (item_type, item_id)
);

CREATE INDEX IF NOT EXISTS idx_admin_work_locks_expires
  ON public.admin_work_locks (expires_at);

CREATE TABLE IF NOT EXISTS public.admin_export_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  requested_by uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  export_type text NOT NULL CHECK (export_type IN ('users', 'kyc', 'reports', 'audit')),
  purpose text NOT NULL,
  max_rows integer NOT NULL DEFAULT 100 CHECK (max_rows BETWEEN 1 AND 1000),
  status text NOT NULL DEFAULT 'requested' CHECK (status IN ('requested', 'approved', 'rejected', 'fulfilled', 'expired')),
  created_at timestamptz NOT NULL DEFAULT now(),
  reviewed_by uuid REFERENCES auth.users(id),
  reviewed_at timestamptz
);

CREATE INDEX IF NOT EXISTS idx_admin_export_requests_status
  ON public.admin_export_requests(status, created_at DESC);

ALTER TABLE public.admin_work_locks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.admin_export_requests ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS admin_work_locks_staff_read ON public.admin_work_locks;
CREATE POLICY admin_work_locks_staff_read
  ON public.admin_work_locks FOR SELECT
  USING (public.is_active_admin(ARRAY['super_admin','moderator']));

DROP POLICY IF EXISTS admin_export_requests_super_admin_read ON public.admin_export_requests;
CREATE POLICY admin_export_requests_super_admin_read
  ON public.admin_export_requests FOR SELECT
  USING (public.is_active_admin(ARRAY['super_admin']));

CREATE OR REPLACE FUNCTION public.mask_admin_email(p_email text)
RETURNS text
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT CASE
    WHEN p_email IS NULL OR position('@' in p_email) = 0 THEN NULL
    ELSE left(split_part(p_email, '@', 1), 1) || '***@' || split_part(p_email, '@', 2)
  END;
$$;

CREATE OR REPLACE FUNCTION public.mask_admin_name(p_name text)
RETURNS text
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT CASE
    WHEN coalesce(trim(p_name), '') = '' THEN 'Unnamed'
    ELSE left(trim(p_name), 1) || repeat('*', greatest(length(trim(p_name)) - 1, 2))
  END;
$$;

CREATE OR REPLACE FUNCTION public.admin_log_read(
  p_action text,
  p_target_user_id uuid DEFAULT NULL,
  p_details jsonb DEFAULT '{}'::jsonb
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT public.is_active_admin() THEN
    RAISE EXCEPTION 'Staff authorization required';
  END IF;

  INSERT INTO public.admin_audit_log(admin_id, actor_role, action_type, target_user_id, details)
  VALUES (auth.uid(), public.current_admin_role(), p_action, p_target_user_id, p_details);
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_user_directory_page(
  p_query text DEFAULT '',
  p_limit integer DEFAULT 50,
  p_offset integer DEFAULT 0
)
RETURNS TABLE(
  user_id uuid,
  profile_id uuid,
  name text,
  email text,
  country_code text,
  gender text,
  joined_at timestamptz,
  last_active_at timestamptz,
  onboarding_step int,
  completeness_score int,
  visibility text,
  is_banned boolean,
  subscription_status text,
  verification_status text,
  has_verification_badge boolean,
  total_count bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_limit integer := least(greatest(coalesce(p_limit, 50), 1), 50);
  v_offset integer := greatest(coalesce(p_offset, 0), 0);
  v_query text := trim(coalesce(p_query, ''));
BEGIN
  IF NOT public.is_active_admin() THEN
    RAISE EXCEPTION 'Staff authorization required';
  END IF;

  INSERT INTO public.admin_audit_log(admin_id, actor_role, action_type, details)
  VALUES (
    auth.uid(),
    public.current_admin_role(),
    'admin_user_directory_read',
    jsonb_build_object('query_present', v_query <> '', 'limit', v_limit, 'offset', v_offset)
  );

  RETURN QUERY
  WITH filtered AS (
    SELECT
      u.id AS user_id,
      p.id AS profile_id,
      public.mask_admin_name(concat_ws(' ', p.first_name, p.last_name)) AS name,
      public.mask_admin_email(u.email::text) AS email,
      p.country_code,
      p.gender,
      u.created_at AS joined_at,
      p.last_active_at,
      p.onboarding_step,
      p.completeness_score,
      p.visibility,
      u.is_banned,
      u.subscription_status,
      p.verification_status,
      coalesce(p.has_verification_badge, false) AS has_verification_badge,
      count(*) OVER () AS total_count
    FROM public.users u
    JOIN public.profiles p ON p.user_id = u.id
    WHERE
      v_query = ''
      OR concat_ws(' ', p.first_name, p.last_name, u.email, u.id::text) ILIKE '%' || v_query || '%'
    ORDER BY u.created_at DESC
    LIMIT v_limit OFFSET v_offset
  )
  SELECT * FROM filtered;
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_reveal_user_pii(p_user_id uuid, p_reason text)
RETURNS TABLE(user_id uuid, name text, email text, revealed_at timestamptz)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT public.is_active_admin(ARRAY['super_admin','moderator']) THEN
    RAISE EXCEPTION 'Moderator authorization required';
  END IF;

  IF length(trim(coalesce(p_reason, ''))) < 6 THEN
    RAISE EXCEPTION 'PII reveal reason is required';
  END IF;

  INSERT INTO public.admin_audit_log(admin_id, actor_role, action_type, target_user_id, details)
  VALUES (
    auth.uid(),
    public.current_admin_role(),
    'admin_user_pii_revealed',
    p_user_id,
    jsonb_build_object('reason', trim(p_reason))
  );

  RETURN QUERY
  SELECT
    u.id,
    concat_ws(' ', p.first_name, p.last_name),
    u.email::text,
    now()
  FROM public.users u
  JOIN public.profiles p ON p.user_id = u.id
  WHERE u.id = p_user_id
  LIMIT 1;
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_claim_work_item(p_item_type text, p_item_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_existing uuid;
BEGIN
  IF NOT public.is_active_admin(ARRAY['super_admin','moderator']) THEN
    RAISE EXCEPTION 'Moderator authorization required';
  END IF;

  DELETE FROM public.admin_work_locks WHERE expires_at < now();

  SELECT locked_by INTO v_existing
  FROM public.admin_work_locks
  WHERE item_type = p_item_type AND item_id = p_item_id;

  IF v_existing IS NOT NULL AND v_existing <> auth.uid() THEN
    RAISE EXCEPTION 'This item is already being reviewed by another moderator';
  END IF;

  INSERT INTO public.admin_work_locks(item_type, item_id, locked_by)
  VALUES (p_item_type, p_item_id, auth.uid())
  ON CONFLICT (item_type, item_id) DO UPDATE
    SET locked_by = excluded.locked_by,
        locked_at = now(),
        expires_at = now() + interval '15 minutes';

  INSERT INTO public.admin_audit_log(admin_id, actor_role, action_type, details)
  VALUES (
    auth.uid(),
    public.current_admin_role(),
    'admin_work_item_claimed',
    jsonb_build_object('item_type', p_item_type, 'item_id', p_item_id)
  );

  RETURN true;
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_account_action(p_user_id uuid, p_action text, p_reason text DEFAULT NULL)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT public.is_active_admin(ARRAY['super_admin','moderator']) THEN
    RAISE EXCEPTION 'Staff authorization required';
  END IF;

  IF p_action IN ('ban', 'shadowban') AND NOT public.is_active_admin(ARRAY['super_admin']) THEN
    RAISE EXCEPTION 'Super admin authorization required';
  END IF;

  IF p_action = 'suspend' THEN
    UPDATE public.profiles
    SET visibility = 'suspended', suspended_reason = coalesce(nullif(trim(p_reason), ''), 'admin_suspension')
    WHERE user_id = p_user_id;
  ELSIF p_action = 'restore' THEN
    UPDATE public.users
    SET is_shadowbanned = false, shadowbanned_at = NULL, shadowban_reason = NULL
    WHERE id = p_user_id;

    UPDATE public.profiles
    SET visibility = 'visible', suspended_reason = NULL
    WHERE user_id = p_user_id;
  ELSIF p_action = 'shadowban' THEN
    UPDATE public.users
    SET is_shadowbanned = true,
        shadowbanned_at = now(),
        shadowban_reason = coalesce(nullif(trim(p_reason), ''), 'admin_shadowban')
    WHERE id = p_user_id;
  ELSIF p_action = 'ban' THEN
    UPDATE public.users
    SET is_banned = true,
        banned_at = now(),
        banned_reason = coalesce(nullif(trim(p_reason), ''), 'admin_ban')
    WHERE id = p_user_id;

    UPDATE public.profiles
    SET visibility = 'suspended',
        suspended_reason = coalesce(nullif(trim(p_reason), ''), 'admin_ban')
    WHERE user_id = p_user_id;
  ELSE
    RAISE EXCEPTION 'Unsupported account action';
  END IF;

  INSERT INTO public.admin_audit_log(admin_id, actor_role, action_type, target_user_id, details)
  VALUES (
    auth.uid(),
    public.current_admin_role(),
    'account_' || p_action,
    p_user_id,
    jsonb_build_object('reason', p_reason)
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_bulk_account_action(p_user_ids uuid[], p_action text, p_reason text)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid;
  v_count integer := 0;
BEGIN
  IF p_user_ids IS NULL OR array_length(p_user_ids, 1) IS NULL THEN
    RAISE EXCEPTION 'At least one user is required';
  END IF;

  IF array_length(p_user_ids, 1) > 50 THEN
    RAISE EXCEPTION 'Bulk actions are capped at 50 users';
  END IF;

  IF length(trim(coalesce(p_reason, ''))) < 6 THEN
    RAISE EXCEPTION 'Bulk action reason is required';
  END IF;

  FOREACH v_user_id IN ARRAY p_user_ids LOOP
    PERFORM public.admin_account_action(v_user_id, p_action, p_reason);
    v_count := v_count + 1;
  END LOOP;

  INSERT INTO public.admin_audit_log(admin_id, actor_role, action_type, details)
  VALUES (
    auth.uid(),
    public.current_admin_role(),
    'account_bulk_' || p_action,
    jsonb_build_object('count', v_count, 'reason', p_reason)
  );

  RETURN v_count;
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_request_data_export(
  p_export_type text,
  p_purpose text,
  p_max_rows integer DEFAULT 100
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_request_id uuid;
  v_max_rows integer := least(greatest(coalesce(p_max_rows, 100), 1), 1000);
BEGIN
  IF NOT public.is_active_admin(ARRAY['super_admin']) THEN
    RAISE EXCEPTION 'Super admin authorization required';
  END IF;

  IF p_export_type NOT IN ('users', 'kyc', 'reports', 'audit') THEN
    RAISE EXCEPTION 'Unsupported export type';
  END IF;

  IF length(trim(coalesce(p_purpose, ''))) < 12 THEN
    RAISE EXCEPTION 'Export purpose must be specific';
  END IF;

  INSERT INTO public.admin_export_requests(requested_by, export_type, purpose, max_rows)
  VALUES (auth.uid(), p_export_type, trim(p_purpose), v_max_rows)
  RETURNING id INTO v_request_id;

  INSERT INTO public.admin_audit_log(admin_id, actor_role, action_type, details)
  VALUES (
    auth.uid(),
    public.current_admin_role(),
    'admin_export_requested',
    jsonb_build_object('request_id', v_request_id, 'export_type', p_export_type, 'max_rows', v_max_rows)
  );

  RETURN v_request_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_review_kyc(p_user_id uuid, p_decision text, p_reason text DEFAULT NULL)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT public.is_active_admin(ARRAY['super_admin','moderator']) THEN
    RAISE EXCEPTION 'Staff authorization required';
  END IF;

  PERFORM public.admin_claim_work_item('kyc', p_user_id);

  IF p_decision = 'approve' THEN
    UPDATE public.profiles
    SET kyc_verified = true, is_verified = true, verification_status = 'verified', verified_at = now()
    WHERE user_id = p_user_id;
  ELSIF p_decision IN ('reject','resubmit') THEN
    UPDATE public.profiles
    SET kyc_verified = false, verification_status = 'unverified'
    WHERE user_id = p_user_id;
  ELSE
    RAISE EXCEPTION 'Unsupported KYC decision';
  END IF;

  DELETE FROM public.admin_work_locks
  WHERE item_type = 'kyc' AND item_id = p_user_id AND locked_by = auth.uid();

  INSERT INTO public.admin_audit_log(admin_id, actor_role, action_type, target_user_id, details)
  VALUES (
    auth.uid(),
    public.current_admin_role(),
    'kyc_' || p_decision,
    p_user_id,
    jsonb_build_object('reason', p_reason)
  );
END;
$$;

REVOKE ALL ON FUNCTION public.mask_admin_email(text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.mask_admin_name(text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_log_read(text, uuid, jsonb) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_user_directory_page(text, integer, integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_reveal_user_pii(uuid, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_claim_work_item(text, uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_bulk_account_action(uuid[], text, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_request_data_export(text, text, integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_account_action(uuid, text, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_review_kyc(uuid, text, text) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.admin_user_directory_page(text, integer, integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_reveal_user_pii(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_claim_work_item(text, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_bulk_account_action(uuid[], text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_request_data_export(text, text, integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_account_action(uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_review_kyc(uuid, text, text) TO authenticated;
