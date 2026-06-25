-- Phase 1: staff-readable operations data and audited moderator actions.
ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS is_banned boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS banned_at timestamptz,
  ADD COLUMN IF NOT EXISTS banned_reason text;

ALTER TABLE public.photos
  ADD COLUMN IF NOT EXISTS moderation_status text NOT NULL DEFAULT 'pending'
    CHECK (moderation_status IN ('pending', 'approved', 'rejected')),
  ADD COLUMN IF NOT EXISTS moderation_reason text,
  ADD COLUMN IF NOT EXISTS moderated_at timestamptz,
  ADD COLUMN IF NOT EXISTS moderated_by uuid REFERENCES auth.users(id);

CREATE OR REPLACE FUNCTION public.admin_dashboard_metrics()
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT CASE WHEN public.is_active_admin() THEN jsonb_build_object(
    'totalUsers', (SELECT count(*) FROM profiles),
    'signupsToday', (SELECT count(*) FROM users WHERE created_at >= current_date),
    'activeSevenDays', (SELECT count(*) FROM profiles WHERE last_active_at >= now() - interval '7 days'),
    'pendingKyc', (SELECT count(*) FROM profiles WHERE verification_status = 'pending_review'),
    'openReports', (SELECT count(*) FROM reports WHERE status = 'pending'),
    'activeSubscriptions', (SELECT count(*) FROM users WHERE subscription_status = 'active'),
    'matchesToday', (SELECT count(*) FROM matches WHERE created_at >= current_date),
    'messagesToday', (SELECT count(*) FROM messages WHERE created_at >= current_date)
  ) ELSE NULL END;
$$;

CREATE OR REPLACE FUNCTION public.admin_user_directory(p_query text DEFAULT '', p_limit integer DEFAULT 50)
RETURNS TABLE(user_id uuid, profile_id uuid, name text, email text, country_code text,
  gender text, joined_at timestamptz, last_active_at timestamptz, onboarding_step int,
  completeness_score int, visibility text, is_banned boolean, subscription_status text,
  verification_status text, has_verification_badge boolean)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT u.id, p.id, concat_ws(' ', p.first_name, p.last_name), u.email, p.country_code,
    p.gender, u.created_at, p.last_active_at, p.onboarding_step, p.completeness_score,
    p.visibility, u.is_banned, u.subscription_status, p.verification_status,
    coalesce(p.has_verification_badge, false)
  FROM users u JOIN profiles p ON p.user_id = u.id
  WHERE public.is_active_admin()
    AND (coalesce(trim(p_query), '') = '' OR concat_ws(' ', p.first_name, p.last_name, u.email, u.id::text) ILIKE '%' || trim(p_query) || '%')
  ORDER BY u.created_at DESC LIMIT least(greatest(p_limit, 1), 100);
$$;

CREATE OR REPLACE FUNCTION public.admin_kyc_queue(p_limit integer DEFAULT 50)
RETURNS TABLE(user_id uuid, profile_id uuid, name text, country_code text, kyc_id_type text,
  face_similarity numeric, created_at timestamptz, selfie_path text, id_path text)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT p.user_id, p.id, concat_ws(' ', p.first_name, p.last_name), p.country_code,
    p.kyc_id_type, p.face_similarity, p.created_at, p.kyc_selfie_storage_path, p.kyc_id_photo_storage_path
  FROM profiles p
  WHERE public.is_active_admin(ARRAY['super_admin','moderator'])
    AND p.verification_status = 'pending_review'
  ORDER BY p.created_at ASC LIMIT least(greatest(p_limit, 1), 100);
$$;

CREATE OR REPLACE FUNCTION public.admin_reports_queue(p_limit integer DEFAULT 100)
RETURNS TABLE(report_id uuid, reporter_id uuid, reported_user_id uuid, reason text,
  description text, created_at timestamptz, report_count bigint, reported_name text)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT r.id, r.reporter_id, r.reported_user_id, r.reason, r.description, r.created_at,
    (SELECT count(*) FROM reports r2 WHERE r2.reported_user_id = r.reported_user_id AND r2.status = 'pending'),
    concat_ws(' ', p.first_name, p.last_name)
  FROM reports r JOIN profiles p ON p.user_id = r.reported_user_id
  WHERE public.is_active_admin(ARRAY['super_admin','moderator']) AND r.status = 'pending'
  ORDER BY r.created_at ASC LIMIT least(greatest(p_limit, 1), 100);
$$;

CREATE OR REPLACE FUNCTION public.admin_photo_queue(p_limit integer DEFAULT 100)
RETURNS TABLE(photo_id uuid, user_id uuid, name text, storage_path text, nsfw_score numeric,
  nsfw_category text, created_at timestamptz, moderation_status text)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT ph.id, p.user_id, concat_ws(' ', p.first_name, p.last_name), ph.storage_path,
    ph.nsfw_score, ph.nsfw_category, ph.created_at, ph.moderation_status
  FROM photos ph JOIN profiles p ON p.id = ph.profile_id
  WHERE public.is_active_admin(ARRAY['super_admin','moderator'])
    AND ph.moderation_status = 'pending'
  ORDER BY ph.created_at ASC LIMIT least(greatest(p_limit, 1), 100);
$$;

CREATE OR REPLACE FUNCTION public.admin_account_action(p_user_id uuid, p_action text, p_reason text DEFAULT NULL)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.is_active_admin(ARRAY['super_admin','moderator']) THEN RAISE EXCEPTION 'Staff authorization required'; END IF;
  IF p_action = 'suspend' THEN
    UPDATE profiles SET visibility = 'suspended', suspended_reason = coalesce(p_reason, 'admin_suspension') WHERE user_id = p_user_id;
  ELSIF p_action = 'restore' THEN
    UPDATE profiles SET visibility = 'visible', suspended_reason = NULL WHERE user_id = p_user_id;
  ELSIF p_action = 'ban' THEN
    IF NOT public.is_active_admin(ARRAY['super_admin']) THEN RAISE EXCEPTION 'Super admin authorization required'; END IF;
    UPDATE users SET is_banned = true, banned_at = now(), banned_reason = coalesce(p_reason, 'admin_ban') WHERE id = p_user_id;
    UPDATE profiles SET visibility = 'suspended', suspended_reason = coalesce(p_reason, 'admin_ban') WHERE user_id = p_user_id;
  ELSE RAISE EXCEPTION 'Unsupported account action'; END IF;
  INSERT INTO admin_audit_log(admin_id, actor_role, action_type, target_user_id, details)
  VALUES (auth.uid(), public.current_admin_role(), p_action, p_user_id, jsonb_build_object('reason', p_reason));
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_review_kyc(p_user_id uuid, p_decision text, p_reason text DEFAULT NULL)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT public.is_active_admin(ARRAY['super_admin','moderator']) THEN RAISE EXCEPTION 'Staff authorization required'; END IF;
  IF p_decision = 'approve' THEN
    UPDATE profiles SET kyc_verified = true, is_verified = true, verification_status = 'verified', verified_at = now() WHERE user_id = p_user_id;
  ELSIF p_decision IN ('reject','resubmit') THEN
    UPDATE profiles SET kyc_verified = false, verification_status = 'unverified' WHERE user_id = p_user_id;
  ELSE RAISE EXCEPTION 'Unsupported KYC decision'; END IF;
  INSERT INTO admin_audit_log(admin_id, actor_role, action_type, target_user_id, details)
  VALUES (auth.uid(), public.current_admin_role(), 'kyc_' || p_decision, p_user_id, jsonb_build_object('reason', p_reason));
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_resolve_report(p_report_id uuid, p_action text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_target uuid;
BEGIN
  IF NOT public.is_active_admin(ARRAY['super_admin','moderator']) THEN RAISE EXCEPTION 'Staff authorization required'; END IF;
  IF p_action NOT IN ('actioned','dismissed') THEN RAISE EXCEPTION 'Unsupported report action'; END IF;
  UPDATE reports SET status = p_action WHERE id = p_report_id RETURNING reported_user_id INTO v_target;
  INSERT INTO admin_audit_log(admin_id, actor_role, action_type, target_user_id, details)
  VALUES (auth.uid(), public.current_admin_role(), 'report_' || p_action, v_target, jsonb_build_object('report_id', p_report_id));
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_review_photo(p_photo_id uuid, p_decision text, p_reason text DEFAULT NULL)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_target uuid;
BEGIN
  IF NOT public.is_active_admin(ARRAY['super_admin','moderator']) THEN RAISE EXCEPTION 'Staff authorization required'; END IF;
  IF p_decision = 'approve' THEN
    UPDATE photos SET moderation_status = 'approved', moderation_reason = p_reason, moderated_at = now(), moderated_by = auth.uid(), admin_approved = true, nsfw_cleared = true, status = 'active' WHERE id = p_photo_id RETURNING (SELECT user_id FROM profiles WHERE id = photos.profile_id) INTO v_target;
  ELSIF p_decision = 'reject' THEN
    UPDATE photos SET moderation_status = 'rejected', moderation_reason = p_reason, moderated_at = now(), moderated_by = auth.uid(), admin_approved = false, nsfw_cleared = false WHERE id = p_photo_id RETURNING (SELECT user_id FROM profiles WHERE id = photos.profile_id) INTO v_target;
  ELSE RAISE EXCEPTION 'Unsupported photo decision'; END IF;
  INSERT INTO admin_audit_log(admin_id, actor_role, action_type, target_user_id, details)
  VALUES (auth.uid(), public.current_admin_role(), 'photo_' || p_decision, v_target, jsonb_build_object('photo_id', p_photo_id, 'reason', p_reason));
END;
$$;

REVOKE ALL ON FUNCTION public.admin_dashboard_metrics() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_user_directory(text, integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_kyc_queue(integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_reports_queue(integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_photo_queue(integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_account_action(uuid, text, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_review_kyc(uuid, text, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_resolve_report(uuid, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_review_photo(uuid, text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_dashboard_metrics() TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_user_directory(text, integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_kyc_queue(integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_reports_queue(integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_photo_queue(integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_account_action(uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_review_kyc(uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_resolve_report(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_review_photo(uuid, text, text) TO authenticated;
