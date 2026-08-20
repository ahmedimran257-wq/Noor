-- Reversible production discovery fixtures for owner-supervised testing.
--
-- Fixture accounts are never inferred from names, email domains, or profile
-- text. Every destructive cleanup is scoped by this protected registry so a
-- genuine member cannot be selected accidentally.

CREATE TABLE IF NOT EXISTS public.test_fixture_batches (
  batch_id text PRIMARY KEY,
  fixture_kind text NOT NULL
    CHECK (fixture_kind IN ('discovery_profiles')),
  requested_count integer NOT NULL
    CHECK (requested_count BETWEEN 2 AND 500),
  target_project_ref text NOT NULL,
  status text NOT NULL DEFAULT 'creating'
    CHECK (status IN ('creating', 'active', 'failed', 'removing', 'removed')),
  storage_path text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  activated_at timestamptz,
  removed_at timestamptz
);

CREATE TABLE IF NOT EXISTS public.test_fixture_members (
  batch_id text NOT NULL
    REFERENCES public.test_fixture_batches(batch_id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  fixture_index integer NOT NULL CHECK (fixture_index BETWEEN 0 AND 499),
  gender text NOT NULL CHECK (gender IN ('male', 'female')),
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (batch_id, user_id),
  UNIQUE (batch_id, fixture_index)
);

CREATE INDEX IF NOT EXISTS idx_test_fixture_members_user
  ON public.test_fixture_members(user_id);
CREATE INDEX IF NOT EXISTS idx_test_fixture_batches_active
  ON public.test_fixture_batches(created_at DESC)
  WHERE status IN ('creating', 'active', 'failed', 'removing');

ALTER TABLE public.test_fixture_batches ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.test_fixture_members ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE public.test_fixture_batches
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON TABLE public.test_fixture_members
  FROM PUBLIC, anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.test_fixture_batches
  TO service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.test_fixture_members
  TO service_role;

COMMENT ON TABLE public.test_fixture_batches IS
  'Service-only manifest for explicitly authorized, reversible production test data.';
COMMENT ON TABLE public.test_fixture_members IS
  'Exact Auth-user allowlist used to remove test fixtures without name/email heuristics.';

-- Test fixtures must be discoverable for owner testing, but must not create a
-- 500-event push-notification storm for genuine members. They are still added
-- to the eligibility baseline so ordinary discovery remains immediately
-- consistent.
CREATE OR REPLACE FUNCTION private.reconcile_discovery_eligible_member(
  p_user_id uuid,
  p_force_event boolean DEFAULT false
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_current record;
  v_previous record;
  v_is_test_fixture boolean := false;
BEGIN
  IF p_user_id IS NULL THEN RETURN; END IF;

  SELECT pool.profile_id, pool.user_id, lower(pool.gender::text) AS gender,
    nullif(upper(trim(pool.country_code::text)), '') AS country_code
  INTO v_current
  FROM public.live_discovery_pool pool
  WHERE pool.user_id = p_user_id
  LIMIT 1;

  SELECT tracked.user_id, tracked.profile_id, tracked.gender,
    tracked.country_code
  INTO v_previous
  FROM private.discovery_eligible_members tracked
  WHERE tracked.user_id = p_user_id;

  IF v_current.user_id IS NULL THEN
    DELETE FROM private.discovery_eligible_members
    WHERE user_id = p_user_id;
    RETURN;
  END IF;

  INSERT INTO private.discovery_eligible_members(
    user_id, profile_id, gender, country_code, tracked_at
  )
  VALUES (
    v_current.user_id,
    v_current.profile_id,
    v_current.gender,
    v_current.country_code,
    now()
  )
  ON CONFLICT (user_id) DO UPDATE
  SET profile_id = EXCLUDED.profile_id,
      gender = EXCLUDED.gender,
      country_code = EXCLUDED.country_code,
      tracked_at = EXCLUDED.tracked_at;

  SELECT EXISTS (
    SELECT 1
    FROM public.test_fixture_members fixture
    JOIN public.test_fixture_batches batch
      ON batch.batch_id = fixture.batch_id
    WHERE fixture.user_id = p_user_id
      AND batch.status IN ('creating', 'active')
  ) INTO v_is_test_fixture;

  IF v_is_test_fixture THEN
    RETURN;
  END IF;

  IF v_previous.user_id IS NULL
    OR v_previous.gender IS DISTINCT FROM v_current.gender
    OR v_previous.country_code IS DISTINCT FROM v_current.country_code
    OR p_force_event THEN
    PERFORM private.enqueue_discovery_availability_event(
      v_current.user_id,
      v_current.profile_id,
      v_current.gender,
      v_current.country_code
    );
  END IF;
END;
$$;

REVOKE ALL ON FUNCTION private.reconcile_discovery_eligible_member(uuid, boolean)
  FROM PUBLIC;
