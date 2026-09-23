-- Authenticated rights intake with bounded data, retry safety and staff-only review.
CREATE TABLE public.privacy_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  request_key uuid NOT NULL,
  kind text NOT NULL CHECK (kind IN ('access','correction','erasure','withdrawal','nomination','grievance')),
  details text NOT NULL CHECK (char_length(details) BETWEEN 10 AND 2000),
  status text NOT NULL DEFAULT 'received' CHECK (status IN ('received','reviewing','resolved')),
  response text NOT NULL DEFAULT '' CHECK (char_length(response) <= 2000),
  created_at timestamptz NOT NULL DEFAULT now(),
  due_at timestamptz NOT NULL DEFAULT (now() + interval '7 days'),
  updated_at timestamptz NOT NULL DEFAULT now(),
  resolved_at timestamptz,
  UNIQUE (user_id, request_key)
);
CREATE INDEX privacy_requests_member_time ON public.privacy_requests(user_id, created_at DESC);
CREATE INDEX privacy_requests_open_due ON public.privacy_requests(due_at, id) WHERE status <> 'resolved';
ALTER TABLE public.privacy_requests ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.privacy_requests FROM anon, authenticated;
GRANT SELECT ON public.privacy_requests TO authenticated;
CREATE POLICY privacy_requests_read ON public.privacy_requests FOR SELECT TO authenticated
  USING (user_id = (SELECT auth.uid()) OR public.is_active_admin(ARRAY['super_admin','support']));

CREATE TABLE private.privacy_request_events (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  request_id uuid NOT NULL REFERENCES public.privacy_requests(id) ON DELETE CASCADE,
  actor_id uuid,
  from_status text NOT NULL,
  to_status text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX privacy_request_events_request ON private.privacy_request_events(request_id, created_at);
REVOKE ALL ON private.privacy_request_events FROM PUBLIC, anon, authenticated;

CREATE FUNCTION public.submit_my_privacy_request(p_request_key uuid, p_kind text, p_details text)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_user uuid := auth.uid(); v_id uuid; v_existing public.privacy_requests%ROWTYPE;
BEGIN
  IF v_user IS NULL THEN RAISE EXCEPTION 'authentication_required'; END IF;
  IF p_request_key IS NULL OR p_kind IS NULL OR p_kind NOT IN ('access','correction','erasure','withdrawal','nomination','grievance')
    OR p_details IS NULL OR char_length(trim(p_details)) NOT BETWEEN 10 AND 2000 THEN
    RAISE EXCEPTION 'invalid_privacy_request';
  END IF;
  -- Serialize intake per member; retry keys are checked before rate limiting.
  PERFORM pg_advisory_xact_lock(hashtextextended(v_user::text, 262));
  SELECT * INTO v_existing FROM public.privacy_requests WHERE user_id = v_user AND request_key = p_request_key;
  IF FOUND THEN
    IF v_existing.kind <> p_kind OR v_existing.details <> trim(p_details) THEN
      RAISE EXCEPTION 'request_key_conflict';
    END IF;
    RETURN v_existing.id;
  END IF;
  IF (SELECT count(*) FROM public.privacy_requests WHERE user_id = v_user AND created_at > now() - interval '1 day') >= 5 THEN
    RAISE EXCEPTION 'privacy_request_daily_limit';
  END IF;
  INSERT INTO public.privacy_requests(user_id, request_key, kind, details)
  VALUES (v_user, p_request_key, p_kind, trim(p_details)) RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;

CREATE FUNCTION public.review_privacy_request(p_id uuid, p_status text, p_response text, p_expected_updated_at timestamptz)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_before public.privacy_requests%ROWTYPE;
BEGIN
  IF NOT public.is_active_admin(ARRAY['super_admin','support']) THEN RAISE EXCEPTION 'privacy_staff_required'; END IF;
  IF p_status IS NULL OR p_status NOT IN ('reviewing','resolved') OR p_response IS NULL
    OR char_length(trim(p_response)) NOT BETWEEN 10 AND 2000 THEN RAISE EXCEPTION 'response_required'; END IF;
  SELECT * INTO v_before FROM public.privacy_requests WHERE id = p_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'privacy_request_missing'; END IF;
  -- Repeating the exact completed action is harmless, including a network retry.
  IF v_before.status = p_status AND v_before.response = trim(p_response) THEN RETURN; END IF;
  IF p_expected_updated_at IS NULL OR v_before.updated_at <> p_expected_updated_at THEN RAISE EXCEPTION 'privacy_request_changed_reload'; END IF;
  IF v_before.status = 'resolved' THEN RAISE EXCEPTION 'privacy_request_already_resolved'; END IF;
  UPDATE public.privacy_requests SET status = p_status, response = trim(p_response), updated_at = clock_timestamp(),
    resolved_at = CASE WHEN p_status = 'resolved' THEN now() ELSE NULL END WHERE id = p_id;
  INSERT INTO private.privacy_request_events(request_id, actor_id, from_status, to_status)
  VALUES (p_id, auth.uid(), v_before.status, p_status);
END;
$$;
REVOKE ALL ON FUNCTION public.submit_my_privacy_request(uuid,text,text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.review_privacy_request(uuid,text,text,timestamptz) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.submit_my_privacy_request(uuid,text,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.review_privacy_request(uuid,text,text,timestamptz) TO authenticated;
NOTIFY pgrst, 'reload schema';
