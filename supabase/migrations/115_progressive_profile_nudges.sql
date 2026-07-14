-- Smart profile-completion nudges derived from current database state.
-- Copy and destinations live in a configurable table; Flutter contains no
-- profile-gap messaging and pg_cron contains no static recipient list.

ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS last_nudge_sent_at timestamptz;

ALTER TABLE public.notifications
  ADD COLUMN IF NOT EXISTS deep_link text;

COMMENT ON COLUMN public.users.last_nudge_sent_at IS
  'Last successful progressive profile-completion nudge. Enforces a minimum three-day interval.';

CREATE INDEX IF NOT EXISTS idx_users_profile_nudge_due
  ON public.users(last_nudge_sent_at, id)
  WHERE deleted_at IS NULL AND deletion_status = 'active';

CREATE TABLE IF NOT EXISTS public.profile_nudge_rules (
  gap_type text PRIMARY KEY,
  priority integer NOT NULL UNIQUE CHECK (priority > 0),
  title_template text NOT NULL CHECK (length(trim(title_template)) > 0),
  body_template text NOT NULL CHECK (length(trim(body_template)) > 0),
  deep_link text NOT NULL CHECK (deep_link LIKE 'mithaq://%'),
  enabled boolean NOT NULL DEFAULT true,
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.profile_nudge_rules ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.profile_nudge_rules FROM PUBLIC, anon, authenticated;

-- These are production defaults, not application constants. Operations can
-- change or disable them without a Flutter release or function replacement.
INSERT INTO public.profile_nudge_rules(
  gap_type, priority, title_template, body_template, deep_link
) VALUES
  ('verification_badge', 10, 'Get 3× more responses',
   'Verified profiles get significantly more interest. Verify now — takes 10 seconds.',
   'mithaq://verify'),
  ('photos', 20, 'Add more photos',
   'Profiles with 3+ photos get 5× more matches. Add yours now.',
   'mithaq://photos'),
  ('bio', 30, 'Tell them about yourself',
   'A good bio doubles your chances. Share what makes you, you.',
   'mithaq://complete-profile'),
  ('marriage_timeline', 40, 'When are you hoping to marry?',
   'Setting your timeline helps us show you serious matches.',
   'mithaq://complete-profile'),
  ('partner_preferences', 50, 'Set your partner preferences',
   'Help us find your ideal match — takes 2 minutes.',
   'mithaq://complete-profile'),
  ('completeness', 60, 'Your profile is {{score}}% complete',
   'Complete profiles appear higher in discovery.',
   'mithaq://complete-profile')
ON CONFLICT (gap_type) DO NOTHING;

CREATE OR REPLACE FUNCTION public.dispatch_profile_nudge(p_user_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_profile public.profiles%ROWTYPE;
  v_gap_type text;
  v_title text;
  v_body text;
  v_deep_link text;
  v_photo_count integer;
  v_partner_preferences_set boolean;
  v_claimed integer;
BEGIN
  -- This guard is repeated inside the function so manual calls cannot bypass
  -- inactivity, deletion, completion, or anti-spam policy.
  SELECT p.*
  INTO v_profile
  FROM public.profiles p
  JOIN public.users u ON u.id = p.user_id
  WHERE p.user_id = p_user_id
    AND p.last_active_at > now() - interval '7 days'
    AND coalesce(p.completeness_score, 0) < 95
    AND u.deleted_at IS NULL
    AND u.deletion_status = 'active'
    AND coalesce(u.last_nudge_sent_at, '-infinity'::timestamptz)
        <= now() - interval '3 days';

  IF NOT FOUND THEN
    RETURN;
  END IF;

  SELECT count(*)::integer
  INTO v_photo_count
  FROM public.photos ph
  WHERE ph.profile_id = v_profile.id
    AND ph.status = 'active'
    AND ph.admin_approved = true
    AND ph.nsfw_cleared = true
    AND coalesce(ph.moderation_status, 'approved') = 'approved';

  SELECT EXISTS (
    SELECT 1
    FROM public.profile_preferences pref
    WHERE pref.profile_id = v_profile.id
      AND pref.preferred_age_min IS NOT NULL
      AND pref.preferred_age_max IS NOT NULL
  ) INTO v_partner_preferences_set;

  -- Most valuable configured missing field wins. Priority and enablement are
  -- data, so operations can tune the progression without replacing SQL.
  SELECT candidate.gap_type
  INTO v_gap_type
  FROM (
    VALUES
      ('verification_badge', NOT coalesce(v_profile.has_verification_badge, false)),
      ('photos', v_photo_count < 2),
      ('bio', v_profile.bio IS NULL OR length(trim(v_profile.bio)) < 50),
      ('marriage_timeline', v_profile.marriage_timeline IS NULL),
      ('partner_preferences', NOT v_partner_preferences_set),
      ('completeness', coalesce(v_profile.completeness_score, 0) < 80)
  ) AS candidate(gap_type, is_missing)
  JOIN public.profile_nudge_rules rule USING (gap_type)
  WHERE candidate.is_missing
    AND rule.enabled
  ORDER BY rule.priority
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN;
  END IF;

  SELECT
    replace(r.title_template, '{{score}}', v_profile.completeness_score::text),
    replace(r.body_template, '{{score}}', v_profile.completeness_score::text),
    r.deep_link
  INTO v_title, v_body, v_deep_link
  FROM public.profile_nudge_rules r
  WHERE r.gap_type = v_gap_type;

  IF NOT FOUND THEN
    RETURN;
  END IF;

  -- Claim the send window atomically. Concurrent/manual invocations cannot
  -- create duplicate nudges within the three-day policy window.
  UPDATE public.users
  SET last_nudge_sent_at = now()
  WHERE id = p_user_id
    AND deleted_at IS NULL
    AND deletion_status = 'active'
    AND coalesce(last_nudge_sent_at, '-infinity'::timestamptz)
        <= now() - interval '3 days';
  GET DIAGNOSTICS v_claimed = ROW_COUNT;

  IF v_claimed = 0 THEN
    RETURN;
  END IF;

  INSERT INTO public.notifications(
    user_id, type, title, body, deep_link, scheduled_at
  ) VALUES (
    p_user_id, 'profile_nudge', v_title, v_body, v_deep_link, now()
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.dispatch_profile_nudges()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid;
BEGIN
  FOR v_user_id IN
    SELECT u.id
    FROM public.users u
    JOIN public.profiles p ON p.user_id = u.id
    WHERE p.last_active_at > now() - interval '7 days'
      AND coalesce(p.completeness_score, 0) < 95
      AND u.deleted_at IS NULL
      AND u.deletion_status = 'active'
      AND coalesce(u.last_nudge_sent_at, '-infinity'::timestamptz)
          <= now() - interval '3 days'
    ORDER BY p.last_active_at DESC
  LOOP
    PERFORM public.dispatch_profile_nudge(v_user_id);
  END LOOP;
END;
$$;

REVOKE ALL ON FUNCTION public.dispatch_profile_nudge(uuid) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.dispatch_profile_nudges() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.dispatch_profile_nudge(uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.dispatch_profile_nudges() TO service_role;

DO $$
BEGIN
  PERFORM cron.unschedule(jobid)
  FROM cron.job
  WHERE jobname = 'profile-nudge-daily';
END;
$$;

-- pg_cron uses the database timezone (10:00 UTC in hosted Supabase). The
-- dispatcher is woken once after the batch; it atomically checks out every
-- newly queued row and delivers it through FCM.
SELECT cron.schedule(
  'profile-nudge-daily',
  '0 10 * * *',
  $$
    SELECT public.dispatch_profile_nudges();
    SELECT net.http_post(
      url := current_setting('app.supabase_url', true) || '/functions/v1/dispatch-notifications',
      body := '{}'::jsonb,
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'x-cron-secret', (
          SELECT decrypted_secret
          FROM vault.decrypted_secrets
          WHERE name = 'mithaq_edge_cron_secret'
        )
      )
    );
  $$
);
