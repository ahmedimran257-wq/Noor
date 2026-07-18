-- Durable, idempotent transactional email delivery for RevenueCat billing
-- events. The subscription state change and outbox enqueue happen in the same
-- database transaction so an Edge Function crash cannot silently lose email.

CREATE TABLE IF NOT EXISTS public.transactional_email_outbox (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  dedupe_key text NOT NULL UNIQUE,
  user_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  email_type text NOT NULL CHECK (email_type = 'subscription'),
  event_type text NOT NULL,
  event_timestamp_ms bigint NOT NULL,
  payload jsonb NOT NULL DEFAULT '{}'::jsonb,
  status text NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'sending', 'sent', 'failed')),
  attempts smallint NOT NULL DEFAULT 0 CHECK (attempts >= 0),
  last_attempt_at timestamptz,
  sent_at timestamptz,
  provider_message_id text,
  last_error text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_transactional_email_outbox_delivery
  ON public.transactional_email_outbox(status, last_attempt_at, created_at)
  WHERE status <> 'sent';

ALTER TABLE public.transactional_email_outbox ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.transactional_email_outbox FROM anon, authenticated;

COMMENT ON TABLE public.transactional_email_outbox IS
  'Server-only durable email outbox. Never exposed to Flutter clients.';

CREATE OR REPLACE FUNCTION public.claim_transactional_email(
  p_dedupe_key text
)
RETURNS SETOF public.transactional_email_outbox
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  UPDATE public.transactional_email_outbox AS outbox
  SET status = 'sending',
      attempts = outbox.attempts + 1,
      last_attempt_at = now(),
      updated_at = now(),
      last_error = NULL
  WHERE outbox.dedupe_key = p_dedupe_key
    AND outbox.attempts < 8
    AND (
      outbox.status IN ('pending', 'failed')
      OR (
        outbox.status = 'sending'
        AND outbox.last_attempt_at < now() - interval '10 minutes'
      )
    )
  RETURNING outbox.*;
END;
$$;

REVOKE ALL ON FUNCTION public.claim_transactional_email(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.claim_transactional_email(text) TO service_role;

CREATE OR REPLACE FUNCTION public.apply_revenuecat_subscription_event(
  p_user_id uuid,
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
SET search_path = public
AS $$
DECLARE
  v_last_ts bigint;
  v_dedupe_key text;
BEGIN
  IF p_subscription_status NOT IN ('none', 'active', 'grace') THEN
    RAISE EXCEPTION 'Invalid subscription status: %', p_subscription_status;
  END IF;

  SELECT last_billing_event_ts
  INTO v_last_ts
  FROM public.users
  WHERE id = p_user_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('applied', false, 'reason', 'user_not_found');
  END IF;

  v_dedupe_key := format(
    'revenuecat:%s:%s:%s',
    p_user_id,
    p_event_type,
    p_event_timestamp_ms
  );

  IF p_event_timestamp_ms <= coalesce(v_last_ts, 0) THEN
    INSERT INTO public.subscription_events (
      user_id, event_type, event_timestamp_ms, product_id, currency, price,
      expires_at
    )
    VALUES (
      p_user_id, p_event_type, p_event_timestamp_ms, p_product_id, p_currency,
      p_price, p_event_expires_at
    )
    ON CONFLICT (user_id, event_type, event_timestamp_ms) DO NOTHING;

    RETURN jsonb_build_object(
      'applied', false,
      'reason', 'stale_event',
      'email_dedupe_key', v_dedupe_key
    );
  END IF;

  UPDATE public.users
  SET subscription_status = p_subscription_status,
      subscription_expires_at = p_subscription_expires_at,
      last_billing_event_ts = p_event_timestamp_ms
  WHERE id = p_user_id;

  INSERT INTO public.subscription_events (
    user_id, event_type, event_timestamp_ms, product_id, currency, price,
    expires_at
  )
  VALUES (
    p_user_id, p_event_type, p_event_timestamp_ms, p_product_id, p_currency,
    p_price, p_event_expires_at
  )
  ON CONFLICT (user_id, event_type, event_timestamp_ms) DO NOTHING;

  IF p_event_type IN (
    'INITIAL_PURCHASE',
    'RENEWAL',
    'PRODUCT_CHANGE',
    'CANCELLATION',
    'EXPIRATION',
    'REFUND',
    'BILLING_ISSUE'
  ) THEN
    INSERT INTO public.transactional_email_outbox (
      dedupe_key,
      user_id,
      email_type,
      event_type,
      event_timestamp_ms,
      payload
    )
    VALUES (
      v_dedupe_key,
      p_user_id,
      'subscription',
      p_event_type,
      p_event_timestamp_ms,
      jsonb_strip_nulls(jsonb_build_object(
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
  uuid, text, bigint, text, timestamptz, text, text, numeric, timestamptz
) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.apply_revenuecat_subscription_event(
  uuid, text, bigint, text, timestamptz, text, text, numeric, timestamptz
) TO service_role;
