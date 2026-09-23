-- Keep RevenueCat retries cheap and deterministic at production concurrency.
-- The provider event ID is already globally unique. This migration adds the
-- read path used by subscriber/admin views and makes the insert itself the
-- idempotency boundary instead of relying on a check-then-insert sequence.

CREATE INDEX IF NOT EXISTS idx_subscription_events_user_time
  ON public.subscription_events(user_id, event_timestamp_ms DESC, id DESC)
  INCLUDE (product_id, event_type, price, currency, expires_at);

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
  v_event_id uuid;
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

  INSERT INTO public.subscription_events(
    user_id, provider_event_id, event_type, event_timestamp_ms, product_id,
    currency, price, expires_at
  ) VALUES (
    p_user_id, p_provider_event_id, p_event_type, p_event_timestamp_ms,
    p_product_id, p_currency, p_price, p_event_expires_at
  )
  ON CONFLICT DO NOTHING
  RETURNING id INTO v_event_id;

  IF v_event_id IS NULL THEN
    RETURN jsonb_build_object(
      'applied', false, 'reason', 'duplicate_event',
      'email_dedupe_key', v_dedupe_key
    );
  END IF;

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

COMMENT ON INDEX public.idx_subscription_events_user_time IS
  'Covers latest-product and per-subscriber billing ledger reads.';
COMMENT ON FUNCTION public.apply_revenuecat_subscription_event(
  uuid, text, text, bigint, text, timestamptz, text, text, numeric, timestamptz
) IS
  'Atomically records one RevenueCat provider event, rejects retries without error, and applies only newer subscription state.';
