-- Phase 2: durable RevenueCat event ledger and staff-only match/subscriber views.
CREATE TABLE IF NOT EXISTS public.subscription_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  event_type text NOT NULL,
  event_timestamp_ms bigint NOT NULL,
  product_id text,
  currency text,
  price numeric(12,2),
  expires_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, event_type, event_timestamp_ms)
);
CREATE INDEX IF NOT EXISTS idx_subscription_events_time ON public.subscription_events(created_at DESC);

CREATE OR REPLACE FUNCTION public.admin_match_metrics()
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT CASE WHEN public.is_active_admin() THEN jsonb_build_object(
    'activeMatches', (SELECT count(*) FROM matches),
    'interestsThirtyDays', (SELECT count(*) FROM interests WHERE created_at >= now() - interval '30 days'),
    'acceptedThirtyDays', (SELECT count(*) FROM interests WHERE status = 'accepted' AND created_at >= now() - interval '30 days'),
    'messagesThirtyDays', (SELECT count(*) FROM messages WHERE created_at >= now() - interval '30 days'),
    'discoveryProfiles', (SELECT count(*) FROM discovery_pool)
  ) ELSE NULL END;
$$;

CREATE OR REPLACE FUNCTION public.admin_active_matches(p_limit integer DEFAULT 100)
RETURNS TABLE(match_id uuid, user_a_name text, user_b_name text, created_at timestamptz, message_count bigint, last_message_at timestamptz)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT m.id, concat_ws(' ', pa.first_name, pa.last_name), concat_ws(' ', pb.first_name, pb.last_name),
    m.created_at, count(msg.id), max(msg.created_at)
  FROM matches m
  JOIN profiles pa ON pa.user_id = m.user_a JOIN profiles pb ON pb.user_id = m.user_b
  LEFT JOIN messages msg ON msg.match_id = m.id
  WHERE public.is_active_admin()
  GROUP BY m.id, pa.first_name, pa.last_name, pb.first_name, pb.last_name, m.created_at
  ORDER BY m.created_at DESC LIMIT least(greatest(p_limit,1),100);
$$;

CREATE OR REPLACE FUNCTION public.admin_subscribers(p_limit integer DEFAULT 100)
RETURNS TABLE(user_id uuid, name text, country_code text, subscription_status text, subscription_expires_at timestamptz, product_id text, total_paid numeric)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT u.id, concat_ws(' ', p.first_name, p.last_name), p.country_code, u.subscription_status, u.subscription_expires_at,
    (SELECT se.product_id FROM subscription_events se WHERE se.user_id = u.id ORDER BY se.event_timestamp_ms DESC LIMIT 1),
    coalesce((SELECT sum(se.price) FROM subscription_events se WHERE se.user_id = u.id AND se.event_type IN ('INITIAL_PURCHASE','RENEWAL')), 0)
  FROM users u JOIN profiles p ON p.user_id = u.id
  WHERE public.is_active_admin() AND u.subscription_status IN ('active','grace')
  ORDER BY u.subscription_expires_at NULLS LAST LIMIT least(greatest(p_limit,1),100);
$$;

REVOKE ALL ON FUNCTION public.admin_match_metrics() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_active_matches(integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_subscribers(integer) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_match_metrics() TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_active_matches(integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_subscribers(integer) TO authenticated;
