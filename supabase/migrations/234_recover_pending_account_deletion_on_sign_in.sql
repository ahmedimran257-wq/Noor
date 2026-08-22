-- Honour the documented 30-day recovery period. A valid authenticated sign-in
-- restores the account only while no purge job has started and the recovery
-- deadline has not elapsed.

CREATE OR REPLACE FUNCTION public.cancel_my_account_deletion()
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_user_id uuid := private.assert_authenticated();
  v_job_status text;
BEGIN
  SELECT j.status
  INTO v_job_status
  FROM private.account_purge_jobs j
  WHERE j.user_id = v_user_id
  FOR UPDATE;

  IF v_job_status IS NOT NULL THEN
    -- Once a purge worker has checked out the account, restoration can no
    -- longer be guaranteed to be complete or safe.
    RETURN false;
  END IF;

  UPDATE public.users
  SET deletion_status = 'active',
      deletion_reason = NULL,
      deletion_requested_at = NULL,
      deleted_at = NULL
  WHERE id = v_user_id
    AND deletion_status = 'pending_deletion'
    AND deletion_requested_at > now() - interval '30 days';

  RETURN FOUND;
END;
$$;

REVOKE ALL ON FUNCTION public.cancel_my_account_deletion() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.cancel_my_account_deletion() TO authenticated;
