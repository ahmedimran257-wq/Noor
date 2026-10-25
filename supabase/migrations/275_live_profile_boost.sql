-- Profile boost had no live effect: its only reader was the nightly
-- compute_global_rank_scores, so a two-hour boost moved a member only if it
-- overlapped that single run. The feed now applies an active boost live:
-- boosted candidates always make the 300-row shortlist, and their
-- recommendation score gains a bonus that lifts them without overriding
-- compatibility.
--
-- Boost entitlement now matches messaging (private.assert_outgoing_chat_
-- entitlement): women stay free, men qualify with paid, referral or test
-- Premium instead of paid status alone.

DO $migration$
DECLARE
  v_definition text;
  v_repaired text;
BEGIN
  SELECT pg_get_functiondef(
    'public.get_discovery_feed(uuid,double precision,uuid,integer,jsonb)'
      ::regprocedure
  )
  INTO v_definition;

  v_repaired := replace(
    replace(
      v_definition,
      E'    ORDER BY coalesce(dp.rank_score, 0.0) DESC, dp.profile_id DESC\n    LIMIT 300',
      E'    ORDER BY (candidate_profile.is_boosted IS TRUE\n              AND candidate_profile.boost_expires_at > now()) DESC,\n      coalesce(dp.rank_score, 0.0) DESC, dp.profile_id DESC\n    LIMIT 300'
    ),
    E'        + s.location_score * 0.10\n      )::double precision AS recommendation_score',
    E'        + s.location_score * 0.10\n        + CASE WHEN EXISTS (\n            SELECT 1 FROM public.profiles boosted\n            WHERE boosted.id = s.profile_id\n              AND boosted.is_boosted IS TRUE\n              AND boosted.boost_expires_at > now()\n          ) THEN 15.0 ELSE 0.0 END\n      )::double precision AS recommendation_score'
  );

  IF v_repaired = v_definition
     OR position('boosted.boost_expires_at > now()' IN v_repaired) = 0
     OR position('candidate_profile.boost_expires_at > now()' IN v_repaired) = 0
  THEN
    RAISE EXCEPTION 'live_boost_feed_anchor_not_found'
      USING ERRCODE = 'P0001';
  END IF;

  EXECUTE v_repaired;
END;
$migration$;

CREATE OR REPLACE FUNCTION public.activate_profile_boost()
 RETURNS TABLE(boost_expires_at timestamp with time zone)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_gender text;
  v_profile public.profiles%ROWTYPE;
  v_expires timestamptz;
  v_next_available timestamptz;
BEGIN
  PERFORM private.assert_authenticated();

  SELECT lower(u.gender::text)
  INTO v_gender
  FROM public.users u
  WHERE u.id = auth.uid();

  SELECT * INTO v_profile
  FROM public.profiles
  WHERE user_id = auth.uid()
  FOR UPDATE;

  IF NOT FOUND OR v_profile.visibility IS DISTINCT FROM 'visible' THEN
    RAISE EXCEPTION 'Your profile must be live before it can be boosted.'
      USING ERRCODE = 'P0001';
  END IF;
  IF v_gender IS DISTINCT FROM 'female' THEN
    -- Same rule as sending messages: paid, referral or test Premium.
    BEGIN
      PERFORM private.assert_outgoing_chat_entitlement(auth.uid());
    EXCEPTION WHEN OTHERS THEN
      RAISE EXCEPTION 'An active subscription is required to boost this profile.'
        USING ERRCODE = 'P0001';
    END;
  END IF;

  IF v_profile.is_boosted = true
     AND v_profile.boost_expires_at > now() THEN
    RETURN QUERY SELECT v_profile.boost_expires_at;
    RETURN;
  END IF;

  v_next_available := v_profile.boost_last_activated_at + interval '7 days';
  IF v_profile.boost_last_activated_at IS NOT NULL
     AND v_next_available > now() THEN
    RAISE EXCEPTION 'Your next weekly boost is available on %.',
      to_char(v_next_available AT TIME ZONE 'Asia/Kolkata',
              'DD Mon YYYY, HH12:MI AM')
      USING ERRCODE = 'P0001';
  END IF;

  v_expires := now() + interval '2 hours';
  PERFORM set_config('silarah.allow_boost_mutation', 'yes', true);
  UPDATE public.profiles
  SET is_boosted = true,
      boost_expires_at = v_expires,
      boost_last_activated_at = now(),
      boost_ready_notified_at = NULL,
      updated_at = now()
  WHERE id = v_profile.id;

  RETURN QUERY SELECT v_expires;
END;
$function$;
