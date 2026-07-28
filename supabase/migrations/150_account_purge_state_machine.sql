-- Audit 1: idempotent, checkpointed account purge.

CREATE TABLE IF NOT EXISTS private.account_purge_jobs (
  user_id uuid PRIMARY KEY,
  phase text NOT NULL DEFAULT 'storage'
    CHECK (phase IN ('storage','auth','database','completed','dead_letter')),
  status text NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending','processing','failed','completed','dead_letter')),
  attempt_count integer NOT NULL DEFAULT 0,
  next_attempt_at timestamptz NOT NULL DEFAULT now(),
  lease_token uuid,
  processing_at timestamptz,
  last_error_code text,
  created_at timestamptz NOT NULL DEFAULT now(),
  completed_at timestamptz
);
CREATE INDEX IF NOT EXISTS idx_account_purge_jobs_due
  ON private.account_purge_jobs(next_attempt_at, created_at)
  WHERE status IN ('pending','failed');
REVOKE ALL ON private.account_purge_jobs FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.checkout_account_purge_jobs(
  p_limit integer DEFAULT 10
)
RETURNS TABLE(user_id uuid, phase text, lease_token uuid)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  IF auth.role() <> 'service_role' THEN
    RAISE EXCEPTION 'service_role_required' USING ERRCODE = 'P0001';
  END IF;
  INSERT INTO private.account_purge_jobs(user_id)
  SELECT u.id
  FROM public.users u
  WHERE u.deletion_status = 'pending_deletion'
    AND u.deleted_at < now() - interval '30 days'
  ON CONFLICT (user_id) DO NOTHING;

  RETURN QUERY
  WITH candidates AS (
    SELECT j.user_id
    FROM private.account_purge_jobs j
    WHERE (
      j.status IN ('pending','failed') AND j.next_attempt_at <= now()
    ) OR (
      j.status = 'processing' AND j.processing_at < now() - interval '10 minutes'
    )
    ORDER BY j.created_at
    LIMIT least(greatest(p_limit, 1), 25)
    FOR UPDATE SKIP LOCKED
  ), leased AS (
    UPDATE private.account_purge_jobs j
    SET status = 'processing',
        processing_at = now(),
        lease_token = gen_random_uuid(),
        attempt_count = attempt_count + 1
    FROM candidates c
    WHERE j.user_id = c.user_id
    RETURNING j.user_id, j.phase, j.lease_token
  )
  SELECT l.user_id, l.phase, l.lease_token FROM leased l;
END;
$$;

CREATE OR REPLACE FUNCTION public.finish_account_purge_phase(
  p_user_id uuid,
  p_lease_token uuid,
  p_success boolean,
  p_next_phase text DEFAULT NULL,
  p_error_code text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_attempt integer;
BEGIN
  IF auth.role() <> 'service_role' THEN
    RAISE EXCEPTION 'service_role_required' USING ERRCODE = 'P0001';
  END IF;
  SELECT attempt_count INTO v_attempt
  FROM private.account_purge_jobs
  WHERE user_id = p_user_id AND lease_token = p_lease_token
    AND status = 'processing'
  FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'invalid_account_purge_lease' USING ERRCODE = 'P0001';
  END IF;
  IF p_success THEN
    IF p_next_phase NOT IN ('auth','database','completed') THEN
      RAISE EXCEPTION 'invalid_account_purge_phase' USING ERRCODE = 'P0001';
    END IF;
    UPDATE private.account_purge_jobs
    SET phase = p_next_phase,
        status = CASE WHEN p_next_phase = 'completed' THEN 'completed' ELSE 'pending' END,
        next_attempt_at = now(),
        lease_token = NULL,
        processing_at = NULL,
        last_error_code = NULL,
        completed_at = CASE WHEN p_next_phase = 'completed' THEN now() ELSE NULL END
    WHERE user_id = p_user_id;
  ELSE
    UPDATE private.account_purge_jobs
    SET status = CASE WHEN v_attempt >= 12 THEN 'dead_letter' ELSE 'failed' END,
        phase = CASE WHEN v_attempt >= 12 THEN 'dead_letter' ELSE phase END,
        next_attempt_at = now() + make_interval(
          secs => least(43200, (60 * power(2, least(v_attempt, 9)))::integer)
        ),
        lease_token = NULL,
        processing_at = NULL,
        last_error_code = left(coalesce(p_error_code, 'purge_phase_failed'), 80)
    WHERE user_id = p_user_id;
  END IF;
END;
$$;

REVOKE ALL ON FUNCTION public.checkout_account_purge_jobs(integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.finish_account_purge_phase(uuid, uuid, boolean, text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.checkout_account_purge_jobs(integer) TO service_role;
GRANT EXECUTE ON FUNCTION public.finish_account_purge_phase(uuid, uuid, boolean, text, text) TO service_role;
