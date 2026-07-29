-- Second audit: remove internal database machinery from the Data API.
-- PostgreSQL grants EXECUTE to PUBLIC for new functions unless it is revoked,
-- so every internal definer/maintenance routine is contained explicitly here.

REVOKE ALL ON FUNCTION public.record_chat_safety_violation(uuid, text, text)
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.queue_notification(uuid, text, text, text, text)
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.compute_casual_penalties()
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.compute_creep_scores()
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.compute_glicko2_batch()
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.compute_glicko_tiers()
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.compute_global_rank_scores()
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.expire_stale_matches()
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.hide_inactive_profiles()
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.get_new_arrivals(text, uuid)
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.update_guardian_last_seen(uuid)
  FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION public.queue_notification(
  uuid, text, text, text, text
) TO service_role;
GRANT EXECUTE ON FUNCTION public.record_chat_safety_violation(
  uuid, text, text
) TO service_role;

-- These are server-owned datasets. Definer functions and service workers keep
-- their owner/service access; member API roles receive no direct relation ACL.
REVOKE ALL ON TABLE public.discovery_pool
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON TABLE public.user_glicko_ratings
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON TABLE public.glicko_interactions
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON TABLE public.subscription_events
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON TABLE public.storage_cleanup_queue
  FROM PUBLIC, anon, authenticated;

GRANT ALL ON TABLE public.user_glicko_ratings TO service_role;
GRANT ALL ON TABLE public.glicko_interactions TO service_role;
GRANT SELECT, INSERT ON TABLE public.subscription_events TO service_role;
GRANT ALL ON TABLE public.storage_cleanup_queue TO service_role;

-- Silent blocks are visible only to the member who created them. The blocked
-- member still disappears through server-side exclusion without learning why.
DROP POLICY IF EXISTS blocks_select ON public.blocks;
CREATE POLICY blocks_select ON public.blocks
  FOR SELECT TO authenticated
  USING (blocker_id = auth.uid());

-- The old registration-status RPCs were a bulk account-enumeration oracle.
-- OTP requests now use a uniform provider response and never preflight email
-- existence through the Data API.
REVOKE ALL ON FUNCTION public.email_registration_status(text)
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.email_is_registered(text)
  FROM PUBLIC, anon, authenticated;

-- Notification destinations are internal but still constrained at the storage
-- boundary. NOT VALID preserves historical rows while checking every new row.
ALTER TABLE public.notifications
  DROP CONSTRAINT IF EXISTS notifications_deep_link_allowlist_check;
ALTER TABLE public.notifications
  ADD CONSTRAINT notifications_deep_link_allowlist_check
  CHECK (
    deep_link IS NULL
    OR (
      char_length(deep_link) BETWEEN 10 AND 300
      AND deep_link ~ '^silarah://[A-Za-z0-9/_?&=.%:-]+$'
    )
  ) NOT VALID;

-- City creation remains available to the authenticated location-search Edge
-- Function through service_role only. API clients can no longer poison the
-- shared catalogue by calling the definer function themselves.
REVOKE ALL ON FUNCTION public.get_or_create_city(
  character varying,
  character varying,
  character varying,
  character varying,
  numeric,
  numeric
) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.get_or_create_city(
  character varying,
  character varying,
  character varying,
  character varying,
  numeric,
  numeric
) TO service_role;

-- Remove SELECT-then-INSERT races and reject malformed provider material even
-- on the service path.
CREATE OR REPLACE FUNCTION public.get_or_create_city(
  p_city_name varchar(100),
  p_region_name varchar(100),
  p_country_name varchar(100),
  p_country_code varchar(2),
  p_latitude numeric(9,6),
  p_longitude numeric(9,6)
)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_country_code text := upper(trim(coalesce(p_country_code, '')));
  v_country_name text := trim(coalesce(p_country_name, ''));
  v_region_name text := trim(coalesce(p_region_name, ''));
  v_city_name text := trim(coalesce(p_city_name, ''));
  v_region_id integer;
  v_city_id integer;
BEGIN
  IF auth.role() <> 'service_role'
    OR v_country_code !~ '^[A-Z]{2}$'
    OR char_length(v_country_name) NOT BETWEEN 2 AND 100
    OR char_length(v_region_name) NOT BETWEEN 2 AND 100
    OR char_length(v_city_name) NOT BETWEEN 2 AND 100
    OR p_latitude NOT BETWEEN -90 AND 90
    OR p_longitude NOT BETWEEN -180 AND 180 THEN
    RAISE EXCEPTION 'invalid_location_resolution' USING ERRCODE = 'P0001';
  END IF;

  INSERT INTO public.countries(
    iso_code, name, dialing_code, currency, default_lang, rtl, show_sect,
    show_sub_sect, wali_requirement, pricing_tier
  )
  VALUES (
    v_country_code, v_country_name, '', '', 'en', false, true, false,
    'optional', 'tier_3'
  )
  ON CONFLICT (iso_code) DO UPDATE
  SET name = public.countries.name
  RETURNING iso_code INTO v_country_code;

  INSERT INTO public.regions(country_code, name)
  VALUES (v_country_code, v_region_name)
  ON CONFLICT (country_code, name) DO UPDATE
  SET name = EXCLUDED.name
  RETURNING id INTO v_region_id;

  INSERT INTO public.cities(region_id, name, latitude, longitude)
  VALUES (v_region_id, v_city_name, p_latitude, p_longitude)
  ON CONFLICT (region_id, name) DO UPDATE
  SET latitude = EXCLUDED.latitude,
      longitude = EXCLUDED.longitude
  RETURNING id INTO v_city_id;

  RETURN v_city_id;
END;
$$;

REVOKE ALL ON FUNCTION public.get_or_create_city(
  character varying,
  character varying,
  character varying,
  character varying,
  numeric,
  numeric
) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.get_or_create_city(
  character varying,
  character varying,
  character varying,
  character varying,
  numeric,
  numeric
) TO service_role;
