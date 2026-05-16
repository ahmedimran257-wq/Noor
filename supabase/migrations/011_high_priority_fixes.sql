-- ============================================================
-- MIGRATION 011: REMAINING HIGH-PRIORITY FIXES
--
-- 1. Remove 48-hour probation trigger (product decision)
-- 2. Add message status column (queued → sent → delivered → read → failed)
-- 3. Extend get_discovery_feed to handle all Flutter filter params
-- 4. Add block-aware profiles_select RLS policy
-- ============================================================

-- ============================================================
-- 1. REMOVE 48-HOUR PROBATION
-- Product decision: probation adds friction for new users
-- without meaningfully reducing abuse (which is better handled
-- by the subscription gate + content-violation suspension).
-- ============================================================

DROP TRIGGER IF EXISTS trg_enforce_probation ON messages;
DROP FUNCTION IF EXISTS enforce_probation_period();

-- Update the messages comment to reflect the removed guard
COMMENT ON TABLE messages IS
  'Text-only in Phase 1. Guarded by trg_assert_messaging_allowed '
  '(subscription gate + content-violation suspension). '
  'Probation period removed per product decision — subscription gate '
  'and moderation triggers provide sufficient protection.';

-- ============================================================
-- 2. MESSAGE STATUS COLUMN
-- Aligns with Flutter MessageStatus enum:
--   queued → sent → delivered → read
--   failed (terminal error, e.g. content violation)
-- ============================================================

ALTER TABLE messages
  ADD COLUMN IF NOT EXISTS status text NOT NULL DEFAULT 'sent'
    CHECK (status IN ('queued','sent','delivered','read','failed'));

CREATE INDEX IF NOT EXISTS idx_messages_status
  ON messages(receiver_id, status) WHERE status IN ('sent','delivered');

COMMENT ON COLUMN messages.status IS
  'Client sets to "queued" on optimistic insert, Edge Function or Realtime '
  'callback advances to "sent". Receiver client marks "delivered" on receipt, '
  '"read" on screen view. "failed" is set by trigger rejection.';

-- ============================================================
-- 3. EXTEND get_discovery_feed FILTER HANDLING
-- Adds server-side filtering for all DiscoveryFilter fields:
--   age range, sect, deen_level, verified, family_type,
--   marital_status, education_min, mother_tongue, community,
--   living_expectation, quran_memorization, marriage_timeline,
--   willing_to_relocate, has_children, open_to_divorced
-- ============================================================

CREATE OR REPLACE FUNCTION get_discovery_feed(
  p_viewer_id    uuid,
  p_cursor_score double precision DEFAULT NULL,
  p_cursor_id    uuid DEFAULT NULL,
  p_page_size    integer DEFAULT 10,
  p_filters      jsonb DEFAULT '{}'::jsonb
)
RETURNS TABLE(
  profile_id    uuid,
  first_name    text,
  last_name_initial text,
  age           integer,
  city_name     text,
  country_code  text,
  sect          text,
  deen_level    text,
  profession    text,
  bio           text,
  photo_url     text,
  photo_count   integer,
  photo_privacy text,
  is_verified   boolean,
  distance_km   double precision,
  rank_score    double precision
)
AS $$
DECLARE
  v_sub_status      text;
  v_profile         profiles%ROWTYPE;
  v_prefs           profile_preferences%ROWTYPE;
  -- Parsed filter params
  v_max_km          int;
  v_active_recently boolean;
  v_age_min         int;
  v_age_max         int;
  v_sect            text;
  v_deen_level      text;
  v_verified_only   boolean;
  v_family_type     text;
  v_marital_status  text;
  v_education_min   int;
  v_mother_tongue   text;
  v_community       text;
  v_living_exp      text;
  v_quran_mem       text;
  v_marriage_tl     text;
  v_relocate        text;
  v_has_children    text;
  v_open_divorced   boolean;
BEGIN
  -- Subscription check: free tier page size capped at 15
  SELECT subscription_status INTO v_sub_status FROM users WHERE id = p_viewer_id;

  IF v_sub_status != 'active' AND p_page_size > 15 THEN
    RAISE EXCEPTION 'Page size exceeds free-tier limit of 15.';
  END IF;

  -- Load viewer's profile + preferences
  SELECT * INTO v_profile FROM profiles WHERE user_id = p_viewer_id;
  SELECT * INTO v_prefs   FROM profile_preferences WHERE profile_id = v_profile.id;

  IF v_profile.visibility = 'suspended' THEN
    RAISE EXCEPTION 'Account suspended. Contact support.';
  END IF;

  -- Parse filter params from jsonb
  v_max_km          := LEAST(COALESCE((p_filters->>'max_distance_km')::int, 20000), 20000);
  v_active_recently := COALESCE((p_filters->>'active_recently')::boolean, false);
  v_age_min         := (p_filters->>'age_min')::int;
  v_age_max         := (p_filters->>'age_max')::int;
  v_sect            := p_filters->>'sect';
  v_deen_level      := p_filters->>'deen_level';
  v_verified_only   := COALESCE((p_filters->>'verified_only')::boolean, false);
  v_family_type     := p_filters->>'family_type';
  v_marital_status  := p_filters->>'marital_status';
  v_education_min   := (p_filters->>'education_min')::int;
  v_mother_tongue   := p_filters->>'mother_tongue';
  v_community       := p_filters->>'community';
  v_living_exp      := p_filters->>'living_expectation';
  v_quran_mem       := p_filters->>'quran_memorization';
  v_marriage_tl     := p_filters->>'marriage_timeline';
  v_relocate        := p_filters->>'willing_to_relocate';
  v_has_children    := p_filters->>'has_children';
  v_open_divorced   := COALESCE((p_filters->>'open_to_divorced')::boolean, false);

  RETURN QUERY
  SELECT
    dp.profile_id,
    dp.first_name,
    dp.last_name_initial,
    dp.age,
    dp.city_name,
    dp.country_code,
    dp.sect,
    dp.deen_level,
    dp.profession,
    dp.bio,
    dp.photo_url,
    dp.photo_count,
    dp.photo_privacy,
    dp.is_verified,
    -- Distance in km (null if location unavailable)
    CASE
      WHEN v_profile.location IS NOT NULL AND dp.location IS NOT NULL THEN
        ROUND((ST_Distance(dp.location, v_profile.location) / 1000.0)::numeric, 1)::double precision
      ELSE NULL
    END AS distance_km,
    dp.rank_score
  FROM discovery_pool dp
  WHERE
    -- Exclude the viewer themselves
    dp.user_id != p_viewer_id

    -- Opposite gender only (matrimony context)
    AND dp.gender != v_profile.gender

    -- Exclude blocks in both directions
    AND NOT EXISTS (
      SELECT 1 FROM blocks b
      WHERE (b.blocker_id = p_viewer_id AND b.blocked_id = dp.user_id)
         OR (b.blocker_id = dp.user_id  AND b.blocked_id = p_viewer_id)
    )

    -- Location / diaspora filter
    AND (
      (
        v_prefs.diaspora_mode = true
        AND (
          v_prefs.preferred_countries IS NULL
          OR dp.country_code = ANY(v_prefs.preferred_countries)
        )
        AND dp.open_to_diaspora = true
      )
      OR
      (
        v_prefs.diaspora_mode = false
        AND (
          v_max_km IS NULL
          OR v_profile.location IS NULL
          OR dp.location IS NULL
          OR ST_DWithin(dp.location, v_profile.location, v_max_km * 1000)
        )
      )
    )

    -- Recency filter
    AND (
      v_active_recently = false
      OR dp.last_active_at > NOW() - INTERVAL '7 days'
    )

    -- ── Extended filters ─────────────────────────────────
    -- Age range
    AND (v_age_min IS NULL OR dp.age >= v_age_min)
    AND (v_age_max IS NULL OR dp.age <= v_age_max)

    -- Sect
    AND (v_sect IS NULL OR dp.sect = v_sect)

    -- Deen level
    AND (v_deen_level IS NULL OR dp.deen_level = v_deen_level)

    -- Verified only
    AND (v_verified_only = false OR dp.is_verified = true)

    -- Family type
    AND (v_family_type IS NULL OR dp.family_type = v_family_type)

    -- Marital status (maps to previously_married column)
    AND (v_marital_status IS NULL OR dp.previously_married = v_marital_status)

    -- Education minimum rank
    AND (v_education_min IS NULL OR dp.education_rank >= v_education_min)

    -- Mother tongue
    AND (v_mother_tongue IS NULL OR dp.mother_tongue = v_mother_tongue)

    -- Community
    AND (v_community IS NULL OR dp.community = v_community)

    -- Living expectation
    AND (v_living_exp IS NULL OR dp.living_expectation = v_living_exp)

    -- Quran memorization
    AND (v_quran_mem IS NULL OR dp.quran_memorization = v_quran_mem)

    -- Marriage timeline
    AND (v_marriage_tl IS NULL OR dp.marriage_timeline = v_marriage_tl)

    -- Willing to relocate
    AND (v_relocate IS NULL OR dp.willing_to_relocate = v_relocate)

    -- Has children
    AND (v_has_children IS NULL OR
      CASE v_has_children
        WHEN 'yes' THEN dp.children_count > 0
        WHEN 'no'  THEN COALESCE(dp.children_count, 0) = 0
        ELSE true
      END
    )

    -- Open to divorced (show divorced profiles only if filter is on)
    AND (
      v_open_divorced = true
      OR dp.previously_married IS NULL
      OR dp.previously_married = 'no'
    )

    -- Cursor-based pagination (no offset drift)
    AND (
      p_cursor_score IS NULL
      OR (dp.rank_score < p_cursor_score)
      OR (dp.rank_score = p_cursor_score AND dp.profile_id < p_cursor_id)
    )

  ORDER BY dp.rank_score DESC, dp.profile_id DESC
  LIMIT p_page_size;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- ============================================================
-- 4. FIX PROFILES_SELECT RLS — Block-aware
-- Blocked users cannot read each other's profiles directly.
-- ============================================================

-- Drop the existing permissive policy
DROP POLICY IF EXISTS profiles_select ON profiles;

-- Recreate with block check
CREATE POLICY profiles_select ON profiles
  FOR SELECT USING (
    visibility = 'visible'
    AND NOT EXISTS (
      SELECT 1 FROM blocks b
      WHERE (b.blocker_id = auth.uid() AND b.blocked_id = profiles.user_id)
         OR (b.blocker_id = profiles.user_id AND b.blocked_id = auth.uid())
    )
  );

COMMENT ON POLICY profiles_select ON profiles IS
  'Visible profiles only; blocked pairs cannot see each other. '
  'This closes the privacy leak where a blocked user could still '
  'read the blocker''s profile via a direct query.';
