-- ============================================================
-- MIGRATION 003: CORE TABLES
-- users, profiles, profile_preferences
-- ============================================================

-- ------------------------------------------------------------
-- USERS
-- One row per authenticated phone number (linked to Supabase Auth).
-- The Supabase auth.users.id IS this table's id.
-- ------------------------------------------------------------
CREATE TABLE users (
  id                       uuid PRIMARY KEY,            -- Matches auth.users.id exactly
  phone                    text UNIQUE NOT NULL,
  country_code             text NOT NULL REFERENCES countries(code),
  gender                   text NOT NULL CHECK (gender IN ('male','female')),
  preferred_language       text NOT NULL DEFAULT 'en',
  timezone                 text NOT NULL DEFAULT 'UTC',
  subscription_status      text NOT NULL DEFAULT 'none'
                             CHECK (subscription_status IN ('none','active','grace')),
  subscription_expires_at  timestamptz,
  messaging_suspended_until timestamptz,
  deleted_at               timestamptz,
  deletion_status          text NOT NULL DEFAULT 'active'
                             CHECK (deletion_status IN ('active','pending_deletion','purged')),
  last_billing_event_ts    bigint NOT NULL DEFAULT 0,   -- RevenueCat idempotency timestamp (ms)
  created_at               timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_users_phone        ON users(phone);
CREATE INDEX idx_users_deletion     ON users(deletion_status) WHERE deletion_status != 'active';
CREATE INDEX idx_users_subscription ON users(subscription_status, subscription_expires_at);

COMMENT ON COLUMN users.last_billing_event_ts IS
  'Unix timestamp in milliseconds from the last processed RevenueCat webhook event. '
  'Used to prevent out-of-order webhook replays from downgrading active subscriptions.';

COMMENT ON COLUMN users.messaging_suspended_until IS
  'Set when a user accumulates 3 content violations within 24 hours. '
  'Enforced by the assert_messaging_allowed trigger on messages.';

-- Cascade soft-delete side effects
CREATE OR REPLACE FUNCTION cascade_soft_delete()
RETURNS trigger AS $$
BEGIN
  IF NEW.deleted_at IS NOT NULL AND OLD.deleted_at IS NULL THEN
    -- Immediately hide the profile from discovery
    UPDATE profiles SET visibility = 'paused' WHERE user_id = NEW.id;
    -- Expire all pending interests — both sent and received
    UPDATE interests
    SET status = 'expired'
    WHERE status = 'pending'
      AND (sender_id = NEW.id OR receiver_id = NEW.id);
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE TRIGGER trg_cascade_soft_delete
  AFTER UPDATE OF deleted_at ON users
  FOR EACH ROW
  EXECUTE FUNCTION cascade_soft_delete();

-- Handle gender pivot — expire interests and flag for admin review
CREATE OR REPLACE FUNCTION handle_profile_gender_pivot()
RETURNS trigger AS $$
BEGIN
  IF TG_OP = 'UPDATE' AND NEW.gender IS DISTINCT FROM OLD.gender THEN
    UPDATE interests
    SET status = 'expired'
    WHERE status = 'pending'
      AND (sender_id = NEW.id OR receiver_id = NEW.id);

    INSERT INTO admin_audit_log (admin_id, action_type, target_user_id, details)
    VALUES (
      NEW.id,
      'gender_pivot_detected',
      NEW.id,
      jsonb_build_object('action', 'interests_expired', 'matches_flagged', true)
    );
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE TRIGGER trg_handle_gender_pivot
  AFTER UPDATE OF gender ON users
  FOR EACH ROW
  EXECUTE FUNCTION handle_profile_gender_pivot();

-- ------------------------------------------------------------
-- PROFILES
-- The full matrimony profile. One per user.
-- ------------------------------------------------------------
CREATE TABLE profiles (
  id                         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id                    uuid UNIQUE NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  static_rank_score          integer NOT NULL DEFAULT 0,

  -- Identity
  first_name                 text NOT NULL,
  last_name                  text NOT NULL,
  date_of_birth              date NOT NULL,
  gender                     text NOT NULL CHECK (gender IN ('male','female')),

  -- Location
  country_code               text NOT NULL REFERENCES countries(code),
  city_id                    uuid REFERENCES cities(id),
  location                   geography(Point, 4326),    -- PostGIS point: coordinates from city

  -- Islamic Identity
  sect                       text,
  sub_sect                   text,
  deen_level                 text CHECK (deen_level IN ('practicing','moderate','cultural')),
  prays_five_daily           boolean,
  hijab                      text,                      -- Women only: always|sometimes|no|prefer_not_to_say
  beard                      text,                      -- Men only: yes|no|prefer_not_to_say

  -- Background
  education_level            text,
  education_rank             int CHECK (education_rank BETWEEN 1 AND 7),
  profession                 text,
  income_bracket             int REFERENCES income_brackets(id),

  -- Family
  family_type                text CHECK (family_type IN ('nuclear','joint','extended')),
  parents_status             text,
  previously_married         text CHECK (previously_married IN ('no','divorced','widowed')),
  children_count             int,
  is_eldest_child            boolean,
  sibling_count              int,

  -- Self
  bio                        text CHECK (char_length(bio) <= 300),
  languages                  text[],
  interests                  text[],                    -- Max 6 tags
  height_cm                  int,

  -- Photo & Visibility
  photo_privacy              text NOT NULL DEFAULT 'public'
                               CHECK (photo_privacy IN ('public','mutual_only')),
  visibility                 text NOT NULL DEFAULT 'visible'
                               CHECK (visibility IN ('visible','paused','suspended')),
  suspended_reason           text,

  -- Onboarding Progress
  onboarding_step            int NOT NULL DEFAULT 0,    -- 0–14; check on app launch
  completeness_score         int NOT NULL DEFAULT 0,    -- 0–100

  -- Guardian / Wali (Day One data model; full UI in Phase 2)
  guardian_phone_encrypted   bytea,                     -- pgp_sym_encrypted via vault key
  guardian_key_version       text NOT NULL DEFAULT 'v1',
  guardian_name              text,
  guardian_relationship      text
                               CHECK (guardian_relationship IN
                                      ('father','mother','brother','sister','uncle','aunt','other')),
  guardian_mode              text NOT NULL DEFAULT 'none'
                               CHECK (guardian_mode IN ('none','passive','active')),
  guardian_user_id           uuid REFERENCES users(id) ON DELETE SET NULL,

  -- Status Flags
  is_verified                boolean NOT NULL DEFAULT false,
  is_boosted                 boolean NOT NULL DEFAULT false,
  boost_expires_at           timestamptz,
  approved_at                timestamptz,
  last_active_at             timestamptz,
  created_at                 timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_profiles_location    ON profiles USING GIST (location);
CREATE INDEX idx_profiles_visibility  ON profiles(visibility);
CREATE INDEX idx_profiles_last_active ON profiles(last_active_at);
CREATE INDEX idx_profiles_rank        ON profiles(static_rank_score DESC, id DESC);
CREATE INDEX idx_profiles_user        ON profiles(user_id);
CREATE INDEX idx_profiles_country     ON profiles(country_code);
CREATE INDEX idx_profiles_onboarding  ON profiles(onboarding_step);

COMMENT ON COLUMN profiles.location IS
  'geography(Point) derived from the selected city''s lat/lng — NOT live GPS. '
  'Used by ST_DWithin for proximity filtering in the discovery feed.';

COMMENT ON COLUMN profiles.guardian_phone_encrypted IS
  'AES-encrypted using pgp_sym_encrypt() with a vault-stored key. '
  'Never store the raw phone. Decrypted only via the set_guardian_phone() SECURITY DEFINER function.';

-- Enforce that profiles.gender always matches users.gender
CREATE OR REPLACE FUNCTION enforce_profile_gender()
RETURNS trigger AS $$
BEGIN
  SELECT gender INTO NEW.gender FROM users WHERE id = NEW.user_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE TRIGGER trg_enforce_profile_gender
  BEFORE INSERT OR UPDATE OF user_id, gender ON profiles
  FOR EACH ROW
  EXECUTE FUNCTION enforce_profile_gender();

-- Completeness score (0–100) — updated on every profile write
CREATE OR REPLACE FUNCTION trigger_update_completeness()
RETURNS trigger AS $$
DECLARE
  score        integer := 0;
  photo_count  integer;
  bio_length   integer;
BEGIN
  -- 25 pts: has a primary approved photo
  SELECT COUNT(*) INTO photo_count
  FROM photos
  WHERE profile_id = NEW.id
    AND admin_approved = true
    AND nsfw_cleared   = true
    AND order_index    = 0;
  IF photo_count > 0 THEN score := score + 25; END IF;

  -- 15 pts: bio >= 50 characters
  bio_length := coalesce(char_length(NEW.bio), 0);
  IF bio_length >= 50 THEN score := score + 15; END IF;

  -- 15 pts: Islamic fields complete
  IF NEW.deen_level IS NOT NULL AND NEW.prays_five_daily IS NOT NULL THEN
    score := score + 15;
  END IF;

  -- 10 pts: education + profession
  IF NEW.education_level IS NOT NULL AND NEW.profession IS NOT NULL THEN
    score := score + 10;
  END IF;

  -- 10 pts: family background
  IF NEW.family_type IS NOT NULL AND NEW.parents_status IS NOT NULL THEN
    score := score + 10;
  END IF;

  -- 10 pts: partner preferences set
  IF EXISTS (
    SELECT 1 FROM profile_preferences
    WHERE profile_id = NEW.id AND preferred_age_min IS NOT NULL
  ) THEN score := score + 10; END IF;

  -- 8 pts: second approved photo
  SELECT COUNT(*) INTO photo_count
  FROM photos
  WHERE profile_id = NEW.id
    AND admin_approved = true
    AND nsfw_cleared   = true;
  IF photo_count >= 2 THEN score := score + 8; END IF;

  -- 4 pts: income bracket provided
  IF NEW.income_bracket IS NOT NULL THEN score := score + 4; END IF;

  -- 3 pts: at least one language listed
  IF NEW.languages IS NOT NULL AND array_length(NEW.languages, 1) > 0 THEN
    score := score + 3;
  END IF;

  NEW.completeness_score := score;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE TRIGGER update_profile_score
  BEFORE UPDATE ON profiles
  FOR EACH ROW
  WHEN (OLD.* IS DISTINCT FROM NEW.*)
  EXECUTE FUNCTION trigger_update_completeness();

-- Guardian phone setter — uses vault-stored encryption key
CREATE OR REPLACE FUNCTION set_guardian_phone(p_profile_id uuid, p_phone text)
RETURNS void AS $$
DECLARE
  v_secret   text;
  v_key_name text := 'guardian_key_v1';
BEGIN
  -- Fetch the AES key from Supabase Vault
  SELECT decrypted_secret INTO v_secret
  FROM vault.decrypted_secrets
  WHERE name = v_key_name;

  IF v_secret IS NULL THEN
    RAISE EXCEPTION 'Vault key % not found. Cannot encrypt guardian phone.', v_key_name;
  END IF;

  UPDATE profiles
  SET guardian_phone_encrypted = pgp_sym_encrypt(p_phone, v_secret),
      guardian_key_version      = 'v1'
  WHERE id = p_profile_id
    AND user_id = auth.uid();           -- Caller can only update their own profile
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- ------------------------------------------------------------
-- PROFILE PREFERENCES
-- The "Looking For" screen data — used by discovery feed.
-- ------------------------------------------------------------
CREATE TABLE profile_preferences (
  profile_id            uuid PRIMARY KEY REFERENCES profiles(id) ON DELETE CASCADE,
  preferred_age_min     int,
  preferred_age_max     int,
  preferred_city_ids    uuid[],
  preferred_countries   text[],
  sect_preference       text,
  deen_preference       text,
  min_education_rank    int CHECK (min_education_rank BETWEEN 1 AND 7),
  open_to_divorced      boolean NOT NULL DEFAULT false,
  open_to_widowed       boolean NOT NULL DEFAULT false,
  open_to_has_children  boolean NOT NULL DEFAULT false,
  max_distance_km       int,
  diaspora_mode         boolean NOT NULL DEFAULT false,
  open_to_diaspora      boolean NOT NULL DEFAULT false
);

ALTER TABLE profile_preferences
  ADD CONSTRAINT max_preferred_cities
    CHECK (array_length(preferred_city_ids, 1) <= 50),
  ADD CONSTRAINT max_preferred_countries
    CHECK (array_length(preferred_countries, 1) <= 20),
  ADD CONSTRAINT sensible_age_range
    CHECK (
      preferred_age_min IS NULL OR preferred_age_max IS NULL OR
      preferred_age_min <= preferred_age_max
    );
