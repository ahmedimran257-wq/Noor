-- Retire phone identity throughout Silarah. Authentication remains verified
-- email; paid access remains Google Play/RevenueCat; Guardian invitations are
-- one-time, expiring, hash-only codes bound to the invited verified email.

-- ---------------------------------------------------------------------------
-- 1. Messaging and billing no longer depend on phone state.
-- ---------------------------------------------------------------------------
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
  v_subscription_status text;
  v_subscription_expires_at timestamptz;
  v_paid_active boolean := false;
  v_referral_active boolean := false;
  v_test_active boolean := false;
BEGIN
  SELECT lower(trim(u.gender::text)),
         u.subscription_status,
         u.subscription_expires_at
  INTO v_gender, v_subscription_status, v_subscription_expires_at
  FROM public.users u
  WHERE u.id = p_user_id;

  IF NOT FOUND OR v_gender IS NULL OR v_gender NOT IN ('male', 'female') THEN
    RAISE EXCEPTION 'profile_gender_required' USING ERRCODE = 'P0001';
  END IF;
  IF v_gender = 'female' THEN RETURN; END IF;

  v_paid_active := v_subscription_status IN ('active', 'grace')
    AND (v_subscription_expires_at IS NULL OR v_subscription_expires_at > now());
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
END;
$$;

REVOKE ALL ON FUNCTION private.assert_outgoing_chat_entitlement(uuid)
  FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.apply_revenuecat_subscription_event(
  p_user_id uuid,
  p_provider_event_id text,
  p_event_type text,
  p_event_timestamp_ms bigint,
  p_subscription_status text,
  p_subscription_expires_at timestamptz,
  p_product_id text DEFAULT NULL,
  p_currency text DEFAULT NULL,
  p_price numeric DEFAULT NULL,
  p_event_expires_at timestamptz DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_last_ts bigint;
  v_dedupe_key text;
BEGIN
  IF auth.role() <> 'service_role'
    OR p_subscription_status NOT IN ('none', 'active', 'grace')
    OR nullif(trim(p_provider_event_id), '') IS NULL
    OR char_length(p_provider_event_id) > 200
    OR p_event_timestamp_ms < 1514764800000
    OR p_event_timestamp_ms >
      (extract(epoch FROM now() + interval '5 minutes') * 1000)::bigint THEN
    RAISE EXCEPTION 'invalid_billing_event' USING ERRCODE = 'P0001';
  END IF;

  SELECT last_billing_event_ts INTO v_last_ts
  FROM public.users WHERE id = p_user_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('applied', false, 'reason', 'user_not_found');
  END IF;

  v_dedupe_key := 'revenuecat:' || p_provider_event_id;
  IF EXISTS (
    SELECT 1 FROM public.subscription_events
    WHERE provider_event_id = p_provider_event_id
  ) THEN
    RETURN jsonb_build_object(
      'applied', false, 'reason', 'duplicate_event',
      'email_dedupe_key', v_dedupe_key
    );
  END IF;

  INSERT INTO public.subscription_events(
    user_id, provider_event_id, event_type, event_timestamp_ms, product_id,
    currency, price, expires_at
  ) VALUES (
    p_user_id, p_provider_event_id, p_event_type, p_event_timestamp_ms,
    p_product_id, p_currency, p_price, p_event_expires_at
  );

  IF p_event_timestamp_ms <= coalesce(v_last_ts, 0) THEN
    RETURN jsonb_build_object(
      'applied', false, 'reason', 'stale_event',
      'email_dedupe_key', v_dedupe_key
    );
  END IF;

  UPDATE public.users
  SET subscription_status = p_subscription_status,
      subscription_expires_at = p_subscription_expires_at,
      last_billing_event_ts = p_event_timestamp_ms
  WHERE id = p_user_id;

  IF p_event_type IN (
    'INITIAL_PURCHASE','RENEWAL','PRODUCT_CHANGE','CANCELLATION',
    'EXPIRATION','REFUND','BILLING_ISSUE'
  ) THEN
    INSERT INTO public.transactional_email_outbox(
      dedupe_key, user_id, email_type, event_type, event_timestamp_ms, payload
    ) VALUES (
      v_dedupe_key, p_user_id, 'subscription', p_event_type,
      p_event_timestamp_ms,
      jsonb_strip_nulls(jsonb_build_object(
        'provider_event_id', p_provider_event_id,
        'product_id', p_product_id,
        'currency', p_currency,
        'price', p_price,
        'expires_at', p_event_expires_at
      ))
    ) ON CONFLICT (dedupe_key) DO NOTHING;
  END IF;

  RETURN jsonb_build_object(
    'applied', true, 'reason', 'applied',
    'email_dedupe_key', v_dedupe_key
  );
END;
$$;

REVOKE ALL ON FUNCTION public.apply_revenuecat_subscription_event(
  uuid, text, text, bigint, text, timestamptz, text, text, numeric, timestamptz
) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.apply_revenuecat_subscription_event(
  uuid, text, text, bigint, text, timestamptz, text, text, numeric, timestamptz
) TO service_role;

-- ---------------------------------------------------------------------------
-- 2. Guardian configuration and acceptance are email-bound and atomic.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.set_my_guardian_settings(
  p_enabled boolean,
  p_can_reply boolean DEFAULT false,
  p_name text DEFAULT NULL,
  p_relationship text DEFAULT NULL,
  p_phone_country_code text DEFAULT NULL,
  p_email text DEFAULT NULL,
  p_authority_scope text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_user_id uuid := private.assert_authenticated();
  v_profile public.profiles%ROWTYPE;
  v_mode text := CASE
    WHEN NOT p_enabled THEN 'none'
    WHEN p_can_reply THEN 'active'
    ELSE 'passive'
  END;
  v_email text := nullif(lower(trim(p_email)), '');
BEGIN
  PERFORM p_phone_country_code;
  IF p_enabled AND (
    nullif(trim(p_name), '') IS NULL
    OR p_relationship NOT IN (
      'father','mother','brother','sister','uncle','aunt','other'
    )
    OR v_email IS NULL
    OR v_email !~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$'
  ) THEN
    RAISE EXCEPTION 'invalid_guardian_details' USING ERRCODE = 'P0001';
  END IF;

  SELECT * INTO v_profile
  FROM public.profiles WHERE user_id = v_user_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'profile_not_found' USING ERRCODE = 'P0001';
  END IF;

  UPDATE public.profiles
  SET guardian_name = CASE WHEN p_enabled THEN trim(p_name) ELSE NULL END,
      guardian_relationship = CASE WHEN p_enabled THEN p_relationship ELSE NULL END,
      guardian_mode = v_mode,
      guardian_email = CASE WHEN p_enabled THEN v_email ELSE NULL END,
      guardian_authority_scope = CASE WHEN p_enabled
        THEN coalesce(nullif(trim(p_authority_scope), ''), 'full') ELSE NULL END,
      guardian_user_id = CASE WHEN p_enabled THEN guardian_user_id ELSE NULL END,
      guardian_phone_country_code = NULL,
      guardian_phone_encrypted = NULL,
      guardian_invitation_expires_at = CASE
        WHEN p_enabled THEN guardian_invitation_expires_at ELSE NULL END,
      guardian_invitation_consumed_at = CASE
        WHEN p_enabled THEN guardian_invitation_consumed_at ELSE NULL END,
      guardian_invitation_attempts = CASE
        WHEN p_enabled THEN guardian_invitation_attempts ELSE 0 END,
      guardian_invitation_locked_until = CASE
        WHEN p_enabled THEN guardian_invitation_locked_until ELSE NULL END
  WHERE id = v_profile.id;

  INSERT INTO public.admin_audit_log(
    admin_id, action_type, target_user_id, details
  ) VALUES (
    v_user_id,
    CASE WHEN p_enabled THEN 'guardian_settings_updated' ELSE 'guardian_revoked' END,
    v_user_id,
    jsonb_build_object(
      'previous_mode', v_profile.guardian_mode,
      'new_mode', v_mode,
      'had_linked_guardian', v_profile.guardian_user_id IS NOT NULL,
      'email_bound_invitation', p_enabled
    )
  );
END;
$$;

REVOKE ALL ON FUNCTION public.set_my_guardian_settings(
  boolean, boolean, text, text, text, text, text
) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.set_my_guardian_settings(
  boolean, boolean, text, text, text, text, text
) TO authenticated;

DROP FUNCTION IF EXISTS public.save_my_guardian_configuration(
  boolean, boolean, text, text, text
);
CREATE FUNCTION public.save_my_guardian_configuration(
  p_enabled boolean,
  p_can_reply boolean DEFAULT false,
  p_name text DEFAULT NULL,
  p_relationship text DEFAULT NULL,
  p_email text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_user_id uuid := private.assert_authenticated();
  v_profile public.profiles%ROWTYPE;
  v_code text;
  v_email text := nullif(lower(trim(p_email)), '');
  v_my_email text;
BEGIN
  SELECT lower(email) INTO v_my_email FROM auth.users WHERE id = v_user_id;
  IF p_enabled AND (v_email IS NULL OR v_email = v_my_email) THEN
    RAISE EXCEPTION 'valid_distinct_guardian_email_required'
      USING ERRCODE = 'P0001';
  END IF;

  PERFORM public.set_my_guardian_settings(
    p_enabled, p_can_reply, p_name, p_relationship,
    NULL::text, v_email, NULL::text
  );
  SELECT * INTO v_profile
  FROM public.profiles WHERE user_id = v_user_id FOR UPDATE;

  IF NOT p_enabled THEN
    UPDATE public.profiles
    SET guardian_invitation_token_hash = NULL
    WHERE id = v_profile.id;
  ELSIF v_profile.guardian_user_id IS NULL THEN
    v_code := private.new_guardian_invitation_code();
    UPDATE public.profiles
    SET guardian_invitation_token_hash = private.guardian_invitation_hash(v_code),
        guardian_invitation_expires_at = now() + interval '7 days',
        guardian_invitation_consumed_at = NULL,
        guardian_invitation_attempts = 0,
        guardian_invitation_locked_until = NULL
    WHERE id = v_profile.id;
  END IF;

  SELECT * INTO v_profile FROM public.profiles WHERE id = v_profile.id;
  RETURN jsonb_build_object(
    'enabled', p_enabled,
    'mode', v_profile.guardian_mode,
    'linked', v_profile.guardian_user_id IS NOT NULL,
    'email_configured', v_profile.guardian_email IS NOT NULL,
    'invitation_code', v_code,
    'invitation_expires_at', v_profile.guardian_invitation_expires_at
  );
END;
$$;

REVOKE ALL ON FUNCTION public.save_my_guardian_configuration(
  boolean, boolean, text, text, text
) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.save_my_guardian_configuration(
  boolean, boolean, text, text, text
) TO authenticated;

CREATE OR REPLACE FUNCTION public.renew_my_guardian_invitation()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_user_id uuid := private.assert_authenticated();
  v_profile public.profiles%ROWTYPE;
  v_code text := private.new_guardian_invitation_code();
  v_expires_at timestamptz := now() + interval '7 days';
BEGIN
  SELECT * INTO v_profile
  FROM public.profiles WHERE user_id = v_user_id FOR UPDATE;
  IF NOT FOUND
    OR v_profile.guardian_mode NOT IN ('passive', 'active')
    OR nullif(trim(v_profile.guardian_email), '') IS NULL
    OR v_profile.guardian_user_id IS NOT NULL THEN
    RAISE EXCEPTION 'guardian_invitation_unavailable' USING ERRCODE = 'P0001';
  END IF;

  UPDATE public.profiles
  SET guardian_invitation_token_hash = private.guardian_invitation_hash(v_code),
      guardian_invitation_expires_at = v_expires_at,
      guardian_invitation_consumed_at = NULL,
      guardian_invitation_attempts = 0,
      guardian_invitation_locked_until = NULL
  WHERE id = v_profile.id;
  RETURN jsonb_build_object(
    'invitation_code', v_code,
    'invitation_expires_at', v_expires_at
  );
END;
$$;

REVOKE ALL ON FUNCTION public.renew_my_guardian_invitation()
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.renew_my_guardian_invitation()
  TO authenticated;

CREATE OR REPLACE FUNCTION public.accept_my_guardian_invitation(p_code text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_guardian_id uuid := private.assert_authenticated();
  v_profile public.profiles%ROWTYPE;
  v_verified_email text;
  v_email_confirmed_at timestamptz;
  v_role text;
  v_hash text;
BEGIN
  IF upper(trim(coalesce(p_code, ''))) !~ '^[A-F0-9]{10}$' THEN
    RETURN jsonb_build_object('status', 'unavailable');
  END IF;
  v_hash := private.guardian_invitation_hash(p_code);
  PERFORM pg_advisory_xact_lock(hashtextextended(v_guardian_id::text, 253));

  SELECT lower(email), email_confirmed_at
  INTO v_verified_email, v_email_confirmed_at
  FROM auth.users WHERE id = v_guardian_id;
  IF v_email_confirmed_at IS NULL OR v_verified_email IS NULL THEN
    RETURN jsonb_build_object('status', 'unavailable');
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.users
    WHERE id = v_guardian_id AND deleted_at IS NULL
      AND coalesce(is_banned, false) = false
  ) THEN
    RETURN jsonb_build_object('status', 'unavailable');
  END IF;

  SELECT * INTO v_profile
  FROM public.profiles
  WHERE guardian_invitation_token_hash = v_hash
  FOR UPDATE;
  IF NOT FOUND
    OR v_profile.user_id = v_guardian_id
    OR v_profile.guardian_mode NOT IN ('passive', 'active')
    OR v_profile.guardian_user_id IS NOT NULL
    OR v_profile.guardian_invitation_consumed_at IS NOT NULL
    OR v_profile.guardian_invitation_expires_at <= now()
    OR v_profile.guardian_invitation_locked_until > now() THEN
    RETURN jsonb_build_object('status', 'unavailable');
  END IF;

  IF lower(trim(v_profile.guardian_email)) IS DISTINCT FROM v_verified_email THEN
    UPDATE public.profiles
    SET guardian_invitation_attempts = guardian_invitation_attempts + 1,
        guardian_invitation_locked_until = CASE
          WHEN guardian_invitation_attempts + 1 >= 5
            THEN now() + interval '24 hours'
          ELSE guardian_invitation_locked_until
        END
    WHERE id = v_profile.id;
    RETURN jsonb_build_object('status', 'unavailable');
  END IF;

  UPDATE public.profiles
  SET guardian_user_id = v_guardian_id,
      guardian_invitation_consumed_at = now(),
      guardian_invitation_token_hash = NULL,
      guardian_invitation_attempts = 0,
      guardian_invitation_locked_until = NULL
  WHERE id = v_profile.id AND guardian_user_id IS NULL;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('status', 'unavailable');
  END IF;

  v_role := CASE WHEN EXISTS (
    SELECT 1 FROM public.profiles own_profile
    WHERE own_profile.user_id = v_guardian_id
      AND own_profile.onboarding_completed
  ) THEN 'member_guardian' ELSE 'guardian' END;
  UPDATE public.users
  SET account_role = v_role,
      onboarding_completed = CASE
        WHEN v_role = 'guardian' THEN true ELSE onboarding_completed END
  WHERE id = v_guardian_id;

  INSERT INTO public.guardian_chat_mirrors(match_id, guardian_id, ward_id, mode)
  SELECT m.id, v_guardian_id, v_profile.user_id, v_profile.guardian_mode
  FROM public.matches m
  WHERE v_profile.user_id IN (m.user_a, m.user_b) AND m.status = 'active'
  ON CONFLICT (match_id, guardian_id) DO UPDATE
  SET ward_id = EXCLUDED.ward_id, mode = EXCLUDED.mode;

  INSERT INTO public.admin_audit_log(
    admin_id, action_type, target_user_id, details
  ) VALUES (
    v_guardian_id, 'guardian_activated', v_profile.user_id,
    jsonb_build_object(
      'ward_profile_id', v_profile.id,
      'guardian_mode', v_profile.guardian_mode,
      'verified_email_account', true,
      'invitation_code_consumed', true,
      'atomic_activation', true
    )
  );
  RETURN jsonb_build_object(
    'status', 'activated',
    'ward_user_id', v_profile.user_id,
    'mode', v_profile.guardian_mode,
    'account_role', v_role
  );
END;
$$;

REVOKE ALL ON FUNCTION public.accept_my_guardian_invitation(text)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.accept_my_guardian_invitation(text)
  TO authenticated;

-- ---------------------------------------------------------------------------
-- 3. Public trust projections expose only retained trust signals.
-- ---------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.get_member_trust_summaries(uuid[]);
CREATE FUNCTION public.get_member_trust_summaries(p_user_ids uuid[])
RETURNS TABLE(
  user_id uuid,
  photo_verified boolean,
  guardian_connected boolean,
  guardian_managed boolean,
  established_member boolean
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_me uuid := private.assert_authenticated();
  v_ids uuid[];
BEGIN
  v_ids := ARRAY(
    SELECT DISTINCT requested
    FROM unnest(coalesce(p_user_ids, ARRAY[]::uuid[])) requested
    WHERE requested IS NOT NULL LIMIT 20
  );
  IF cardinality(v_ids) = 0 THEN RETURN; END IF;

  RETURN QUERY
  SELECT
    p.user_id,
    (p.photo_verified_at IS NOT NULL
      AND p.photo_verification_paused_at IS NULL)::boolean,
    (p.guardian_user_id IS NOT NULL AND p.guardian_user_id <> p.user_id)::boolean,
    (p.profile_owner_type::text = 'guardian')::boolean,
    (u.created_at <= now() - interval '30 days'
      AND u.deleted_at IS NULL
      AND coalesce(u.is_banned, false) = false)::boolean
  FROM public.profiles p
  JOIN public.users u ON u.id = p.user_id
  WHERE p.user_id = ANY(v_ids)
    AND private.can_access_incognito_profile(v_me, p.user_id)
    AND (
      p.user_id = v_me
      OR EXISTS (
        SELECT 1 FROM public.live_discovery_pool candidate
        WHERE candidate.user_id = p.user_id
      )
      OR EXISTS (
        SELECT 1 FROM public.interests i
        WHERE (i.sender_id = v_me AND i.receiver_id = p.user_id)
           OR (i.receiver_id = v_me AND i.sender_id = p.user_id)
      )
      OR EXISTS (
        SELECT 1 FROM public.matches m
        WHERE (m.user_a = v_me AND m.user_b = p.user_id)
           OR (m.user_b = v_me AND m.user_a = p.user_id)
      )
    );
END;
$$;

REVOKE ALL ON FUNCTION public.get_member_trust_summaries(uuid[])
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_member_trust_summaries(uuid[])
  TO authenticated;

DO $migration$
DECLARE
  v_signature regprocedure :=
    'public.get_discovery_feed(uuid,double precision,uuid,integer,jsonb)'::regprocedure;
  v_definition text;
  v_updated text;
  v_old text := $old$        AND (
          nullif(lower(trim(p_filters->>'trust_filter')), '') IS NULL
          OR (lower(trim(p_filters->>'trust_filter')) = 'photo'
              AND candidate_profile.photo_verified_at IS NOT NULL
              AND candidate_profile.photo_verification_paused_at IS NULL)
          OR (lower(trim(p_filters->>'trust_filter')) = 'phone'
              AND EXISTS (
                SELECT 1 FROM public.users trust_account
                WHERE trust_account.id = dp.user_id
                  AND trust_account.phone_trust_activated_at IS NOT NULL
              ))
          OR (lower(trim(p_filters->>'trust_filter')) = 'both'
              AND candidate_profile.photo_verified_at IS NOT NULL
              AND candidate_profile.photo_verification_paused_at IS NULL
              AND EXISTS (
                SELECT 1 FROM public.users trust_account
                WHERE trust_account.id = dp.user_id
                  AND trust_account.phone_trust_activated_at IS NOT NULL
              ))
          OR (lower(trim(p_filters->>'trust_filter')) = 'guardian'
              AND candidate_profile.guardian_user_id IS NOT NULL)
        )$old$;
  v_new text := $new$        AND (
          nullif(lower(trim(p_filters->>'trust_filter')), '') IS NULL
          OR (lower(trim(p_filters->>'trust_filter')) = 'photo'
              AND candidate_profile.photo_verified_at IS NOT NULL
              AND candidate_profile.photo_verification_paused_at IS NULL)
          OR (lower(trim(p_filters->>'trust_filter')) = 'guardian'
              AND candidate_profile.guardian_user_id IS NOT NULL)
        )$new$;
BEGIN
  SELECT replace(pg_get_functiondef(v_signature), E'\r\n', E'\n')
  INTO v_definition;
  IF position(v_old IN v_definition) > 0 THEN
    v_updated := replace(v_definition, v_old, v_new);
    EXECUTE v_updated;
  ELSIF position('phone_trust_activated_at' IN v_definition) > 0
     OR position('phone_verified_at' IN v_definition) > 0 THEN
    RAISE EXCEPTION 'retired_phone_discovery_filter_anchor_not_found';
  END IF;
END;
$migration$;

-- ---------------------------------------------------------------------------
-- 4. Remove all writable phone-verification boundaries and scrub old data.
-- Legacy nullable columns remain temporarily for reversible migration history,
-- but constraints make them inert and prevent future collection.
-- ---------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.begin_my_paid_phone_verification(text, boolean);
DROP FUNCTION IF EXISTS public.assert_my_phone_verification_intent(text);
DROP FUNCTION IF EXISTS public.complete_paid_phone_verification(uuid, text, text);
DROP FUNCTION IF EXISTS public.assert_my_phone_country_enabled(text);
DROP FUNCTION IF EXISTS public.confirm_my_verified_phone();
DROP FUNCTION IF EXISTS public.confirm_my_verified_phone(text);
DROP FUNCTION IF EXISTS public.set_guardian_phone(uuid, text);
DROP FUNCTION IF EXISTS public.activate_guardian(uuid, text);
DROP FUNCTION IF EXISTS public.assert_guardian_invitation_phone(text, text);
DROP FUNCTION IF EXISTS public.check_guardian_invitation_phone(text, text);
DROP FUNCTION IF EXISTS public.complete_guardian_phone_and_accept(uuid, text, text);
DROP TABLE IF EXISTS private.phone_verification_intents;

UPDATE public.users
SET phone = NULL,
    phone_country_code = NULL,
    phone_verified_at = NULL,
    phone_trust_activated_at = NULL
WHERE phone IS NOT NULL
   OR phone_country_code IS NOT NULL
   OR phone_verified_at IS NOT NULL
   OR phone_trust_activated_at IS NOT NULL;

UPDATE public.profiles
SET guardian_phone_encrypted = NULL,
    guardian_phone_country_code = NULL
WHERE guardian_phone_encrypted IS NOT NULL
   OR guardian_phone_country_code IS NOT NULL;

ALTER TABLE public.users
  DROP CONSTRAINT IF EXISTS users_phone_identity_retired;
ALTER TABLE public.users
  ADD CONSTRAINT users_phone_identity_retired CHECK (
    phone IS NULL
    AND phone_country_code IS NULL
    AND phone_verified_at IS NULL
    AND phone_trust_activated_at IS NULL
  );

ALTER TABLE public.profiles
  DROP CONSTRAINT IF EXISTS profiles_guardian_phone_retired;
ALTER TABLE public.profiles
  ADD CONSTRAINT profiles_guardian_phone_retired CHECK (
    guardian_phone_encrypted IS NULL
    AND guardian_phone_country_code IS NULL
  );

COMMENT ON COLUMN public.users.phone IS
  'Retired compatibility column. Silarah does not collect phone numbers.';
COMMENT ON COLUMN public.users.phone_verified_at IS
  'Retired compatibility column; constrained to NULL.';
COMMENT ON COLUMN public.users.phone_trust_activated_at IS
  'Retired compatibility column; constrained to NULL.';
COMMENT ON COLUMN public.profiles.guardian_phone_encrypted IS
  'Retired compatibility column; Guardian invitations are verified-email bound.';

NOTIFY pgrst, 'reload schema';
