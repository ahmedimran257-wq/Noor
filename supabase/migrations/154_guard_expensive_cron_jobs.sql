-- Audit 1: common overlap guard and durable execution ledger for expensive
-- scheduled database work.

CREATE OR REPLACE FUNCTION private.run_guarded_sql(
  p_job_name text,
  p_command text,
  p_timeout_seconds integer DEFAULT 300
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_run_id uuid;
  v_rows bigint := 0;
BEGIN
  IF nullif(trim(p_job_name), '') IS NULL
    OR char_length(p_job_name) > 80
    OR nullif(trim(p_command), '') IS NULL THEN
    RAISE EXCEPTION 'invalid_guarded_job' USING ERRCODE = 'P0001';
  END IF;
  IF NOT pg_try_advisory_xact_lock(hashtextextended(p_job_name, 154)) THEN
    INSERT INTO private.job_runs(
      job_name, status, finished_at, error_code
    )
    VALUES (p_job_name, 'skipped', now(), 'overlap');
    RETURN false;
  END IF;

  UPDATE private.job_runs
  SET status = 'failed', finished_at = now(), error_code = 'stale_execution'
  WHERE job_name = p_job_name
    AND status = 'running'
    AND started_at < now() - interval '30 minutes';

  INSERT INTO private.job_runs(job_name, status)
  VALUES (p_job_name, 'running')
  RETURNING id INTO v_run_id;

  BEGIN
    PERFORM set_config(
      'statement_timeout',
      (least(greatest(p_timeout_seconds, 5), 900) * 1000)::text,
      true
    );
    EXECUTE p_command;
    GET DIAGNOSTICS v_rows = ROW_COUNT;
    UPDATE private.job_runs
    SET status = 'completed',
        finished_at = now(),
        rows_affected = greatest(v_rows, 0)
    WHERE id = v_run_id;
    RETURN true;
  EXCEPTION WHEN OTHERS THEN
    UPDATE private.job_runs
    SET status = 'failed',
        finished_at = now(),
        error_code = left(SQLSTATE, 80),
        details = jsonb_build_object('error_class', SQLSTATE)
    WHERE id = v_run_id;
    RETURN false;
  END;
END;
$$;
REVOKE ALL ON FUNCTION private.run_guarded_sql(text, text, integer)
  FROM PUBLIC, anon, authenticated;

DO $$
DECLARE
  v_job record;
  v_name text;
BEGIN
  FOREACH v_name IN ARRAY ARRAY[
    'compute_creep_scores_nightly',
    'compute_casual_penalties_nightly',
    'compute_global_rank_scores_nightly',
    'compute_glicko_tiers_nightly',
    'hide_inactive_profiles_daily',
    'capture_operational_health_15m'
  ]
  LOOP
    FOR v_job IN SELECT jobid FROM cron.job WHERE jobname = v_name
    LOOP
      PERFORM cron.unschedule(v_job.jobid);
    END LOOP;
  END LOOP;

  PERFORM cron.schedule(
    'compute_creep_scores_nightly',
    '35 1 * * *',
    $job$SELECT private.run_guarded_sql(
      'compute_creep_scores_nightly',
      'SELECT public.compute_creep_scores()',
      300
    );$job$
  );
  PERFORM cron.schedule(
    'compute_casual_penalties_nightly',
    '50 1 * * *',
    $job$SELECT private.run_guarded_sql(
      'compute_casual_penalties_nightly',
      'SELECT public.compute_casual_penalties()',
      300
    );$job$
  );
  PERFORM cron.schedule(
    'compute_global_rank_scores_nightly',
    '10 2 * * *',
    $job$SELECT private.run_guarded_sql(
      'compute_global_rank_scores_nightly',
      'SELECT public.compute_global_rank_scores()',
      600
    );$job$
  );
  PERFORM cron.schedule(
    'compute_glicko_tiers_nightly',
    '25 2 * * *',
    $job$SELECT private.run_guarded_sql(
      'compute_glicko_tiers_nightly',
      'SELECT public.compute_glicko_tiers()',
      600
    );$job$
  );
  PERFORM cron.schedule(
    'hide_inactive_profiles_daily',
    '10 3 * * *',
    $job$SELECT private.run_guarded_sql(
      'hide_inactive_profiles_daily',
      'SELECT public.hide_inactive_profiles()',
      300
    );$job$
  );
  PERFORM cron.schedule(
    'capture_operational_health_15m',
    '2-59/15 * * * *',
    $job$SELECT private.run_guarded_sql(
      'capture_operational_health_15m',
      'SELECT private.capture_operational_health()',
      120
    );$job$
  );
END;
$$;
