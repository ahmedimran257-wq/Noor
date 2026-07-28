-- Audit 1: provider event identity, authoritative ordering and grace audience.

ALTER TABLE public.subscription_events
  ADD COLUMN IF NOT EXISTS provider_event_id text;
CREATE UNIQUE INDEX IF NOT EXISTS idx_subscription_events_provider_event
  ON public.subscription_events(provider_event_id)
  WHERE provider_event_id IS NOT NULL;

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
      last_billing_event_ts = p_event_timestamp_ms
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

-- Remove the pre-provider-ID overload. Leaving it executable would preserve a
-- weaker mutation path that can neither prove provider identity nor dedupe a
-- retried RevenueCat delivery reliably.
DROP FUNCTION IF EXISTS public.apply_revenuecat_subscription_event(
  uuid, text, bigint, text, timestamptz, text, text, numeric, timestamptz
);

-- The canonical subscription state is "grace", not the stale
-- "grace_period" spelling used by the old campaign function.
CREATE OR REPLACE FUNCTION public.admin_campaign_recipient_ids(
  p_audience text,
  p_limit integer DEFAULT 1000
)
RETURNS SETOF uuid
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT u.id
  FROM public.users u
  WHERE public.is_active_admin(ARRAY['super_admin','support'])
    AND u.deleted_at IS NULL
    AND coalesce(u.is_banned, false) = false
    AND (
      p_audience = 'all'
      OR (p_audience = 'subscribers' AND u.subscription_status IN ('active','grace'))
      OR (p_audience = 'free' AND u.subscription_status = 'none')
    )
  ORDER BY u.created_at DESC
  LIMIT least(greatest(p_limit, 1), 5000);
$$;
REVOKE ALL ON FUNCTION public.admin_campaign_recipient_ids(text, integer) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_campaign_recipient_ids(text, integer) TO authenticated;

CREATE OR REPLACE FUNCTION public.admin_queue_push_campaign(p_campaign_id uuid)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_campaign public.admin_push_campaigns%ROWTYPE;
  v_count integer := 0;
BEGIN
  IF NOT public.is_active_admin(ARRAY['super_admin','support']) THEN
    RAISE EXCEPTION 'aal2_staff_required' USING ERRCODE = 'P0001';
  END IF;
  SELECT * INTO v_campaign
  FROM public.admin_push_campaigns
  WHERE id = p_campaign_id
  FOR UPDATE;
  IF NOT FOUND OR v_campaign.status <> 'draft' THEN
    RAISE EXCEPTION 'campaign_not_queueable' USING ERRCODE = 'P0001';
  END IF;

  WITH eligible AS (
    SELECT DISTINCT u.id AS user_id
    FROM public.users u
    JOIN public.profiles p ON p.user_id = u.id
    WHERE coalesce(u.is_banned, false) = false
      AND u.deleted_at IS NULL
      AND p.visibility = 'visible'
      AND (
        v_campaign.audience = 'all'
        OR (
          v_campaign.audience = 'active_7d'
          AND p.last_active_at >= now() - interval '7 days'
        )
        OR (
          v_campaign.audience = 'subscribers'
          AND u.subscription_status IN ('active','grace')
        )
        OR (
          v_campaign.audience = 'country'
          AND p.country_code = v_campaign.country_code
        )
      )
  ), recipients AS (
    INSERT INTO public.admin_push_campaign_recipients(campaign_id, user_id)
    SELECT v_campaign.id, e.user_id FROM eligible e
    ON CONFLICT (campaign_id, user_id) DO NOTHING
    RETURNING user_id
  ), queued AS (
    INSERT INTO public.notifications(
      user_id, type, title, body, deep_link, scheduled_at, next_attempt_at
    )
    SELECT
      r.user_id, 'admin_campaign', v_campaign.title, v_campaign.body,
      v_campaign.deep_link, greatest(v_campaign.scheduled_at, now()),
      greatest(v_campaign.scheduled_at, now())
    FROM recipients r
    RETURNING id, user_id
  )
  UPDATE public.admin_push_campaign_recipients r
  SET notification_id = q.id
  FROM queued q
  WHERE r.campaign_id = v_campaign.id AND r.user_id = q.user_id;
  GET DIAGNOSTICS v_count = ROW_COUNT;

  UPDATE public.admin_push_campaigns
  SET status = 'queued', queued_count = v_count, queued_by = auth.uid(),
      queued_at = now()
  WHERE id = v_campaign.id;
  INSERT INTO public.admin_audit_log(
    admin_id, actor_role, action_type, details
  )
  VALUES (
    auth.uid(), public.current_admin_role(), 'campaign_queued',
    jsonb_build_object('campaign_id', v_campaign.id, 'queued_count', v_count)
  );
  RETURN v_count;
END;
$$;
