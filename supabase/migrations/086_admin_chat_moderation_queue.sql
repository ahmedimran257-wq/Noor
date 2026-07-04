-- ============================================================
-- MITHAQ — Admin chat moderation queue
-- ============================================================

ALTER TABLE public.admin_work_locks
  DROP CONSTRAINT IF EXISTS admin_work_locks_item_type_check;

ALTER TABLE public.admin_work_locks
  ADD CONSTRAINT admin_work_locks_item_type_check
  CHECK (item_type IN ('kyc', 'report', 'photo', 'message_report'));

CREATE OR REPLACE FUNCTION public.admin_message_reports_queue(p_limit integer DEFAULT 100)
RETURNS TABLE (
  report_id uuid,
  message_id uuid,
  match_id uuid,
  reporter_id uuid,
  reported_user_id uuid,
  reported_name text,
  reason text,
  description text,
  message_content text,
  created_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT public.is_active_admin(ARRAY['super_admin','moderator']) THEN
    RAISE EXCEPTION 'Moderator authorization required';
  END IF;

  INSERT INTO public.admin_audit_log(admin_id, actor_role, action_type, details)
  VALUES (
    auth.uid(),
    public.current_admin_role(),
    'message_reports_queue_read',
    jsonb_build_object('limit', greatest(1, least(coalesce(p_limit, 100), 100)))
  );

  RETURN QUERY
  SELECT
    mr.id,
    mr.message_id,
    mr.match_id,
    mr.reporter_id,
    mr.reported_user_id,
    trim(concat(coalesce(p.first_name, ''), ' ', left(coalesce(p.last_name, ''), 1))) AS reported_name,
    mr.reason,
    mr.description,
    m.content,
    mr.created_at
  FROM public.message_reports mr
  JOIN public.messages m ON m.id = mr.message_id
  LEFT JOIN public.profiles p ON p.user_id = mr.reported_user_id
  WHERE mr.status = 'pending'
  ORDER BY mr.created_at ASC
  LIMIT greatest(1, least(coalesce(p_limit, 100), 100));
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_resolve_message_report(
  p_report_id uuid,
  p_action text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_target uuid;
  v_action text := lower(coalesce(p_action, 'reviewed'));
BEGIN
  IF NOT public.is_active_admin(ARRAY['super_admin','moderator']) THEN
    RAISE EXCEPTION 'Moderator authorization required';
  END IF;

  IF v_action NOT IN ('reviewed', 'dismissed', 'actioned') THEN
    RAISE EXCEPTION 'Invalid message report action';
  END IF;

  UPDATE public.message_reports
  SET status = v_action
  WHERE id = p_report_id
  RETURNING reported_user_id INTO v_target;

  IF v_target IS NULL THEN
    RAISE EXCEPTION 'Message report not found';
  END IF;

  DELETE FROM public.admin_work_locks
  WHERE item_type = 'message_report' AND item_id = p_report_id;

  INSERT INTO public.admin_audit_log(admin_id, actor_role, action_type, target_user_id, details)
  VALUES (
    auth.uid(),
    public.current_admin_role(),
    'message_report_' || v_action,
    v_target,
    jsonb_build_object('report_id', p_report_id)
  );
END;
$$;

REVOKE ALL ON FUNCTION public.admin_message_reports_queue(integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_resolve_message_report(uuid, text) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.admin_message_reports_queue(integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_resolve_message_report(uuid, text) TO authenticated;
