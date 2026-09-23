-- Resolved privacy cases expire after 12 months. Legal holds are separately
-- restricted, time-bounded, documented and renewable by AAL2 super admins only.
CREATE TABLE private.privacy_request_holds (
  request_id uuid PRIMARY KEY REFERENCES public.privacy_requests(id) ON DELETE CASCADE,
  hold_until timestamptz NOT NULL,
  reason text NOT NULL CHECK (char_length(reason) BETWEEN 10 AND 500),
  updated_by uuid NOT NULL,
  updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE private.privacy_retention_events (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  request_id uuid NOT NULL REFERENCES public.privacy_requests(id) ON DELETE CASCADE,
  actor_id uuid NOT NULL,
  hold_until timestamptz,
  reason text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE private.privacy_request_holds ENABLE ROW LEVEL SECURITY;
ALTER TABLE private.privacy_retention_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE private.privacy_request_events ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON private.privacy_request_holds, private.privacy_retention_events FROM PUBLIC, anon, authenticated;
CREATE INDEX privacy_retention_events_request ON private.privacy_retention_events(request_id, created_at);
CREATE INDEX privacy_requests_expiry ON public.privacy_requests(resolved_at, id) WHERE status = 'resolved';

CREATE FUNCTION public.set_privacy_request_hold(p_id uuid, p_until timestamptz, p_reason text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_old private.privacy_request_holds%ROWTYPE;
BEGIN
  IF NOT public.is_active_admin(ARRAY['super_admin']) THEN RAISE EXCEPTION 'privacy_super_admin_required'; END IF;
  IF p_reason IS NULL OR char_length(trim(p_reason)) NOT BETWEEN 10 AND 500
    OR (p_until IS NOT NULL AND (p_until <= now() OR p_until > now() + interval '1 year')) THEN
    RAISE EXCEPTION 'invalid_privacy_hold';
  END IF;
  PERFORM 1 FROM public.privacy_requests WHERE id = p_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'privacy_request_missing'; END IF;
  SELECT * INTO v_old FROM private.privacy_request_holds WHERE request_id = p_id;
  IF p_until IS NULL AND NOT FOUND THEN RETURN; END IF;
  IF p_until IS NOT NULL AND v_old.hold_until = p_until AND v_old.reason = trim(p_reason) THEN RETURN; END IF;
  IF p_until IS NULL THEN
    DELETE FROM private.privacy_request_holds WHERE request_id = p_id;
  ELSE
    INSERT INTO private.privacy_request_holds(request_id, hold_until, reason, updated_by)
    VALUES (p_id, p_until, trim(p_reason), auth.uid())
    ON CONFLICT (request_id) DO UPDATE SET hold_until = EXCLUDED.hold_until,
      reason = EXCLUDED.reason, updated_by = EXCLUDED.updated_by, updated_at = clock_timestamp();
  END IF;
  INSERT INTO private.privacy_retention_events(request_id, actor_id, hold_until, reason)
  VALUES (p_id, auth.uid(), p_until, trim(p_reason));
END;
$$;
CREATE FUNCTION public.get_privacy_request_holds(p_ids uuid[])
RETURNS TABLE(request_id uuid, hold_until timestamptz, reason text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = '' AS $$
BEGIN
  IF NOT public.is_active_admin(ARRAY['super_admin']) THEN RAISE EXCEPTION 'privacy_super_admin_required'; END IF;
  IF coalesce(cardinality(p_ids),0) > 30 THEN RAISE EXCEPTION 'privacy_hold_page_limit'; END IF;
  RETURN QUERY SELECT h.request_id, h.hold_until, h.reason
  FROM private.privacy_request_holds h WHERE h.request_id = ANY(p_ids);
END;
$$;
CREATE FUNCTION private.purge_expired_privacy_requests()
RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_deleted integer;
BEGIN
  WITH expired AS (
    SELECT r.id FROM public.privacy_requests r
    WHERE r.status = 'resolved' AND r.resolved_at < now() - interval '12 months'
      AND NOT EXISTS (SELECT 1 FROM private.privacy_request_holds h
        WHERE h.request_id = r.id AND h.hold_until > now())
    ORDER BY r.resolved_at, r.id LIMIT 500 FOR UPDATE OF r SKIP LOCKED
  ) DELETE FROM public.privacy_requests r USING expired e WHERE r.id = e.id;
  GET DIAGNOSTICS v_deleted = ROW_COUNT;
  RETURN v_deleted;
END;
$$;
REVOKE ALL ON FUNCTION public.set_privacy_request_hold(uuid,timestamptz,text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.get_privacy_request_holds(uuid[]) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.set_privacy_request_hold(uuid,timestamptz,text), public.get_privacy_request_holds(uuid[]) TO authenticated;
REVOKE ALL ON FUNCTION private.purge_expired_privacy_requests() FROM PUBLIC, anon, authenticated;
DO $$
BEGIN
  IF to_regclass('cron.job') IS NOT NULL THEN
    PERFORM cron.schedule('purge_expired_privacy_requests', '17 * * * *',
      'SELECT private.purge_expired_privacy_requests();');
  END IF;
END;
$$;
NOTIFY pgrst, 'reload schema';
