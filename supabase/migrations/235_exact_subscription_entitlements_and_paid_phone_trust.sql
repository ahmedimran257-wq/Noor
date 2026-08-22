-- Keep the store/provider expiry authoritative and separate a successful SMS
-- ownership proof from the public trust badge unlocked by an actual purchase.

ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS phone_trust_activated_at timestamptz;

COMMENT ON COLUMN public.users.phone_trust_activated_at IS
  'Permanent public phone trust badge activation after both SMS ownership proof and an authoritative paid purchase event.';

UPDATE public.users u
SET phone_trust_activated_at = paid.first_paid_at
FROM (
  SELECT e.user_id,
         min(to_timestamp(e.event_timestamp_ms / 1000.0)) AS first_paid_at
  FROM public.subscription_events e
  WHERE e.event_type IN ('INITIAL_PURCHASE', 'RENEWAL')
  GROUP BY e.user_id
) paid
WHERE paid.user_id = u.id
  AND u.phone_verified_at IS NOT NULL
  AND u.phone_trust_activated_at IS NULL;

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
    OR p_event_timestamp_ms > (extract(epoch FROM now() + interval '5 minutes') * 1000)::bigint THEN
    RAISE EXCEPTION 'invalid_billing_event' USING ERRCODE = 'P0001';
  END IF;

  SELECT last_billing_event_ts INTO v_last_ts
  FROM public.users
  WHERE id = p_user_id
  FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('applied', false, 'reason', 'user_not_found');
  END IF;

  v_dedupe_key := 'revenuecat:' || p_provider_event_id;
  IF EXISTS (
    SELECT 1 FROM public.subscription_events
    WHERE provider_event_id = p_provider_event_id
  ) THEN
    RETURN jsonb_build_object(
      'applied', false,
      'reason', 'duplicate_event',
      'email_dedupe_key', v_dedupe_key
    );
  END IF;

  INSERT INTO public.subscription_events(
    user_id, provider_event_id, event_type, event_timestamp_ms, product_id,
    currency, price, expires_at
  )
  VALUES (
    p_user_id, p_provider_event_id, p_event_type, p_event_timestamp_ms,
    p_product_id, p_currency, p_price, p_event_expires_at
  );

  IF p_event_timestamp_ms <= coalesce(v_last_ts, 0) THEN
    RETURN jsonb_build_object(
      'applied', false,
      'reason', 'stale_event',
      'email_dedupe_key', v_dedupe_key
    );
  END IF;

  UPDATE public.users
  SET subscription_status = p_subscription_status,
      subscription_expires_at = p_subscription_expires_at,
      last_billing_event_ts = p_event_timestamp_ms,
      phone_trust_activated_at = CASE
        WHEN phone_trust_activated_at IS NULL
          AND phone_verified_at IS NOT NULL
          AND p_event_type IN ('INITIAL_PURCHASE', 'RENEWAL')
          AND p_subscription_status = 'active'
        THEN to_timestamp(p_event_timestamp_ms / 1000.0)
        ELSE phone_trust_activated_at
      END
  WHERE id = p_user_id;

  IF p_event_type IN (
    'INITIAL_PURCHASE','RENEWAL','PRODUCT_CHANGE','CANCELLATION',
    'EXPIRATION','REFUND','BILLING_ISSUE'
  ) THEN
    INSERT INTO public.transactional_email_outbox(
      dedupe_key, user_id, email_type, event_type, event_timestamp_ms, payload
    )
    VALUES (
      v_dedupe_key, p_user_id, 'subscription', p_event_type,
      p_event_timestamp_ms,
      jsonb_strip_nulls(jsonb_build_object(
        'provider_event_id', p_provider_event_id,
        'product_id', p_product_id,
        'currency', p_currency,
        'price', p_price,
        'expires_at', p_event_expires_at
      ))
    )
    ON CONFLICT (dedupe_key) DO NOTHING;
  END IF;

  RETURN jsonb_build_object(
    'applied', true,
    'reason', 'applied',
    'email_dedupe_key', v_dedupe_key
  );
END;
$$;

REVOKE ALL ON FUNCTION public.apply_revenuecat_subscription_event(
  uuid, text, text, bigint, text, timestamptz, text, text, numeric, timestamptz
) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.apply_revenuecat_subscription_event(
  uuid, text, text, bigint, text, timestamptz, text, text, numeric, timestamptz
) TO service_role;

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
      FROM public.promotional_premium_grants g
      WHERE g.user_id = p_user_id
        AND g.starts_at <= now()
        AND g.expires_at > now()
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

  SELECT max(g.expires_at)
  INTO v_referral_expires_at
  FROM public.promotional_premium_grants g
  WHERE g.user_id = v_user_id
    AND g.starts_at <= now()
    AND g.expires_at > now();

  is_active := v_paid_active OR v_referral_expires_at IS NOT NULL;
  source := CASE
    WHEN v_paid_active AND v_referral_expires_at IS NOT NULL
      THEN 'paid_and_referral'
    WHEN v_paid_active THEN 'paid'
    WHEN v_referral_expires_at IS NOT NULL THEN 'referral'
    ELSE 'none'
  END;
  expires_at := CASE
    WHEN v_paid_active AND v_subscription_expires_at IS NULL THEN NULL
    WHEN NOT v_paid_active THEN v_referral_expires_at
    WHEN v_referral_expires_at IS NULL THEN v_subscription_expires_at
    ELSE greatest(v_subscription_expires_at, v_referral_expires_at)
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
    SELECT 1
    FROM public.promotional_premium_grants g
    WHERE g.user_id = p_user_id
      AND g.starts_at <= now()
      AND g.expires_at > now()
  ) INTO v_referral_active;

  IF NOT v_paid_active AND NOT v_referral_active THEN
    RAISE EXCEPTION 'subscription_required' USING ERRCODE = 'P0001';
  END IF;
  IF v_paid_active AND v_phone_verified_at IS NULL THEN
    RAISE EXCEPTION 'phone_verification_required' USING ERRCODE = 'P0001';
  END IF;
END;
$$;

REVOKE ALL ON FUNCTION private.assert_outgoing_chat_entitlement(uuid)
  FROM PUBLIC, anon, authenticated;

DROP FUNCTION IF EXISTS public.get_member_trust_summaries(uuid[]);
CREATE FUNCTION public.get_member_trust_summaries(p_user_ids uuid[])
RETURNS TABLE(
  user_id uuid,
  photo_verified boolean,
  phone_verified boolean,
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
    WHERE requested IS NOT NULL
    LIMIT 20
  );
  IF cardinality(v_ids) = 0 THEN RETURN; END IF;

  RETURN QUERY
  SELECT
    p.user_id,
    (p.photo_verified_at IS NOT NULL
      AND p.photo_verification_paused_at IS NULL)::boolean,
    (u.phone_trust_activated_at IS NOT NULL)::boolean,
    (p.guardian_user_id IS NOT NULL
      AND p.guardian_user_id <> p.user_id)::boolean,
    (p.profile_owner_type::text = 'guardian')::boolean,
    (u.created_at <= now() - interval '30 days'
      AND u.deleted_at IS NULL
      AND coalesce(u.is_banned, false) = false)::boolean
  FROM public.profiles p
  JOIN public.users u ON u.id = p.user_id
  WHERE p.user_id = ANY(v_ids)
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
BEGIN
  SELECT pg_get_functiondef(v_signature) INTO v_definition;
  v_updated := replace(
    v_definition,
    'trust_account.phone_verified_at IS NOT NULL',
    'trust_account.phone_trust_activated_at IS NOT NULL'
  );
  IF v_updated = v_definition THEN
    RAISE EXCEPTION 'phone_trust_filter_patch_anchor_not_found';
  END IF;
  EXECUTE v_updated;
END;
$migration$;

NOTIFY pgrst, 'reload schema';
