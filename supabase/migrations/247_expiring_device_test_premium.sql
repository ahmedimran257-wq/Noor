-- Explicit, expiring Premium access for owner-supervised physical-device QA.
--
-- This entitlement is deliberately separate from RevenueCat subscription
-- columns and referral rewards. It can never create revenue, phone-trust, or
-- referral history, and it is available only through service-role RPCs.

CREATE TABLE IF NOT EXISTS private.test_premium_grants (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  batch_id text NOT NULL,
  user_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  starts_at timestamptz NOT NULL DEFAULT now(),
  expires_at timestamptz NOT NULL,
  revoked_at timestamptz,
  reason text NOT NULL DEFAULT 'owner_supervised_device_qa',
  granted_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT test_premium_grants_batch_user_unique UNIQUE (batch_id, user_id),
  CONSTRAINT test_premium_grants_batch_format CHECK (
    batch_id ~ '^device-test-[a-z0-9-]{8,80}$'
  ),
  CONSTRAINT test_premium_grants_window CHECK (
    expires_at > starts_at
    AND expires_at <= starts_at + interval '7 days'
  ),
  CONSTRAINT test_premium_grants_reason CHECK (
    reason = 'owner_supervised_device_qa'
  )
);

CREATE INDEX IF NOT EXISTS idx_test_premium_grants_active_user
  ON private.test_premium_grants(user_id, expires_at DESC)
  WHERE revoked_at IS NULL;

REVOKE ALL ON TABLE private.test_premium_grants
  FROM PUBLIC, anon, authenticated, service_role;

CREATE OR REPLACE FUNCTION public.grant_device_test_premium(
  p_batch_id text,
  p_user_ids uuid[],
  p_duration_hours integer DEFAULT 72
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_ids uuid[];
  v_expires_at timestamptz;
  v_inserted integer := 0;
BEGIN
  IF auth.role() <> 'service_role' THEN
    RAISE EXCEPTION 'service_role_required' USING ERRCODE = '42501';
  END IF;
  IF p_batch_id IS NULL
    OR p_batch_id !~ '^device-test-[a-z0-9-]{8,80}$' THEN
    RAISE EXCEPTION 'invalid_test_premium_batch' USING ERRCODE = '22023';
  END IF;
  IF p_duration_hours NOT BETWEEN 1 AND 168 THEN
    RAISE EXCEPTION 'invalid_test_premium_duration' USING ERRCODE = '22023';
  END IF;

  v_ids := ARRAY(
    SELECT DISTINCT requested
    FROM unnest(coalesce(p_user_ids, ARRAY[]::uuid[])) requested
    WHERE requested IS NOT NULL
    ORDER BY requested
  );
  IF cardinality(v_ids) NOT BETWEEN 1 AND 5 THEN
    RAISE EXCEPTION 'invalid_test_premium_audience' USING ERRCODE = '22023';
  END IF;

  -- A test grant is for real, recently registered physical-device accounts,
  -- never for the synthetic discovery inventory created by the fixture tool.
  IF EXISTS (
    SELECT 1 FROM unnest(v_ids) requested
    LEFT JOIN public.users account ON account.id = requested
    LEFT JOIN public.profiles profile ON profile.user_id = requested
    WHERE account.id IS NULL
      OR account.deleted_at IS NOT NULL
      OR coalesce(account.is_banned, false)
      OR coalesce(account.is_shadowbanned, false)
      OR profile.id IS NULL
      OR coalesce(profile.onboarding_completed, false) = false
      OR NOT EXISTS (
        SELECT 1 FROM public.user_fcm_tokens token
        WHERE token.user_id = requested
          AND token.platform IN ('android', 'ios')
          AND token.updated_at >= now() - interval '24 hours'
      )
      OR EXISTS (
        SELECT 1 FROM public.test_fixture_members fixture
        JOIN public.test_fixture_batches batch
          ON batch.batch_id = fixture.batch_id
        WHERE fixture.user_id = requested
          AND batch.status IN ('creating', 'active')
      )
  ) THEN
    RAISE EXCEPTION 'test_premium_device_not_eligible' USING ERRCODE = 'P0001';
  END IF;

  v_expires_at := now() + make_interval(hours => p_duration_hours);
  INSERT INTO private.test_premium_grants(
    batch_id, user_id, starts_at, expires_at
  )
  SELECT p_batch_id, requested, now(), v_expires_at
  FROM unnest(v_ids) requested
  ON CONFLICT (batch_id, user_id) DO NOTHING;
  GET DIAGNOSTICS v_inserted = ROW_COUNT;

  RETURN jsonb_build_object(
    'batch_id', p_batch_id,
    'requested', cardinality(v_ids),
    'inserted', v_inserted,
    'expires_at', v_expires_at
  );
END;
$$;

REVOKE ALL ON FUNCTION public.grant_device_test_premium(
  text, uuid[], integer
) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.grant_device_test_premium(
  text, uuid[], integer
) TO service_role;

CREATE OR REPLACE FUNCTION public.revoke_device_test_premium(p_batch_id text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_revoked integer := 0;
BEGIN
  IF auth.role() <> 'service_role' THEN
    RAISE EXCEPTION 'service_role_required' USING ERRCODE = '42501';
  END IF;
  UPDATE private.test_premium_grants
  SET revoked_at = coalesce(revoked_at, now())
  WHERE batch_id = p_batch_id
    AND revoked_at IS NULL;
  GET DIAGNOSTICS v_revoked = ROW_COUNT;
  RETURN jsonb_build_object('batch_id', p_batch_id, 'revoked', v_revoked);
END;
$$;

REVOKE ALL ON FUNCTION public.revoke_device_test_premium(text)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.revoke_device_test_premium(text)
  TO service_role;

CREATE OR REPLACE FUNCTION public.has_active_premium(p_user_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT
    coalesce((
      SELECT u.subscription_status IN ('active', 'grace')
        AND (
          u.subscription_expires_at IS NULL
          OR u.subscription_expires_at > now()
        )
      FROM public.users u
      WHERE u.id = p_user_id
    ), false)
    OR EXISTS (
      SELECT 1
      FROM public.promotional_premium_grants grant_row
      WHERE grant_row.user_id = p_user_id
        AND grant_row.starts_at <= now()
        AND grant_row.expires_at > now()
    )
    OR EXISTS (
      SELECT 1
      FROM private.test_premium_grants test_grant
      WHERE test_grant.user_id = p_user_id
        AND test_grant.revoked_at IS NULL
        AND test_grant.starts_at <= now()
        AND test_grant.expires_at > now()
    );
$$;

REVOKE ALL ON FUNCTION public.has_active_premium(uuid)
  FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.get_my_premium_entitlement()
RETURNS TABLE (
  is_active boolean,
  source text,
  expires_at timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_user_id uuid := private.assert_authenticated();
  v_subscription_status text;
  v_subscription_expires_at timestamptz;
  v_paid_active boolean := false;
  v_referral_expires_at timestamptz;
  v_test_expires_at timestamptz;
BEGIN
  SELECT u.subscription_status, u.subscription_expires_at
  INTO v_subscription_status, v_subscription_expires_at
  FROM public.users u
  WHERE u.id = v_user_id;

  v_paid_active := v_subscription_status IN ('active', 'grace')
    AND (
      v_subscription_expires_at IS NULL
      OR v_subscription_expires_at > now()
    );

  SELECT max(grant_row.expires_at)
  INTO v_referral_expires_at
  FROM public.promotional_premium_grants grant_row
  WHERE grant_row.user_id = v_user_id
    AND grant_row.starts_at <= now()
    AND grant_row.expires_at > now();

  SELECT max(test_grant.expires_at)
  INTO v_test_expires_at
  FROM private.test_premium_grants test_grant
  WHERE test_grant.user_id = v_user_id
    AND test_grant.revoked_at IS NULL
    AND test_grant.starts_at <= now()
    AND test_grant.expires_at > now();

  is_active := v_paid_active
    OR v_referral_expires_at IS NOT NULL
    OR v_test_expires_at IS NOT NULL;
  source := CASE
    WHEN v_paid_active AND v_referral_expires_at IS NOT NULL
      THEN 'paid_and_referral'
    WHEN v_paid_active THEN 'paid'
    WHEN v_referral_expires_at IS NOT NULL THEN 'referral'
    WHEN v_test_expires_at IS NOT NULL THEN 'test'
    ELSE 'none'
  END;
  expires_at := CASE
    WHEN v_paid_active AND v_subscription_expires_at IS NULL THEN NULL
    ELSE (
      SELECT max(candidate_expiry)
      FROM unnest(ARRAY[
        CASE WHEN v_paid_active THEN v_subscription_expires_at END,
        v_referral_expires_at,
        v_test_expires_at
      ]) candidate_expiry
    )
  END;

  RETURN NEXT;
END;
$$;

REVOKE ALL ON FUNCTION public.get_my_premium_entitlement()
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_my_premium_entitlement()
  TO authenticated;

CREATE OR REPLACE FUNCTION private.assert_outgoing_chat_entitlement(
  p_user_id uuid
)
RETURNS void
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_gender text;
  v_phone_verified_at timestamptz;
  v_subscription_status text;
  v_subscription_expires_at timestamptz;
  v_paid_active boolean := false;
  v_referral_active boolean := false;
  v_test_active boolean := false;
BEGIN
  SELECT lower(trim(u.gender::text)),
         u.phone_verified_at,
         u.subscription_status,
         u.subscription_expires_at
  INTO v_gender,
       v_phone_verified_at,
       v_subscription_status,
       v_subscription_expires_at
  FROM public.users u
  WHERE u.id = p_user_id;

  IF NOT FOUND OR v_gender IS NULL OR v_gender NOT IN ('male', 'female') THEN
    RAISE EXCEPTION 'profile_gender_required' USING ERRCODE = 'P0001';
  END IF;
  IF v_gender = 'female' THEN RETURN; END IF;

  v_paid_active := v_subscription_status IN ('active', 'grace')
    AND (
      v_subscription_expires_at IS NULL
      OR v_subscription_expires_at > now()
    );
  SELECT EXISTS (
    SELECT 1 FROM public.promotional_premium_grants grant_row
    WHERE grant_row.user_id = p_user_id
      AND grant_row.starts_at <= now()
      AND grant_row.expires_at > now()
  ) INTO v_referral_active;
  SELECT EXISTS (
    SELECT 1 FROM private.test_premium_grants test_grant
    WHERE test_grant.user_id = p_user_id
      AND test_grant.revoked_at IS NULL
      AND test_grant.starts_at <= now()
      AND test_grant.expires_at > now()
  ) INTO v_test_active;

  IF NOT v_paid_active AND NOT v_referral_active AND NOT v_test_active THEN
    RAISE EXCEPTION 'subscription_required' USING ERRCODE = 'P0001';
  END IF;
  IF v_paid_active
    AND NOT v_referral_active
    AND NOT v_test_active
    AND v_phone_verified_at IS NULL THEN
    RAISE EXCEPTION 'phone_verification_required' USING ERRCODE = 'P0001';
  END IF;
END;
$$;

REVOKE ALL ON FUNCTION private.assert_outgoing_chat_entitlement(uuid)
  FROM PUBLIC, anon, authenticated;

COMMENT ON TABLE private.test_premium_grants IS
  'Auditable, expiring physical-device QA entitlements; never a paid or referral subscription.';
COMMENT ON FUNCTION public.grant_device_test_premium(text, uuid[], integer) IS
  'Service-only grant for up to five recently registered physical-device accounts, capped at seven days.';

NOTIFY pgrst, 'reload schema';
