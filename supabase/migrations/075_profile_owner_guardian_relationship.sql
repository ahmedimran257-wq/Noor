-- First-class profile ownership for self vs guardian onboarding.
-- Keeps the existing five-step signup short while making guardian/ward
-- ownership explicit for restore, RLS, moderation, and support tooling.

DO $$
BEGIN
  CREATE TYPE public.profile_owner_type AS ENUM ('self', 'guardian');
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS profile_owner_type public.profile_owner_type;

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS profile_owner_type public.profile_owner_type,
  ADD COLUMN IF NOT EXISTS relationship_to_ward text;

ALTER TABLE public.profiles
  DROP CONSTRAINT IF EXISTS profiles_relationship_to_ward_check;

ALTER TABLE public.profiles
  ADD CONSTRAINT profiles_relationship_to_ward_check
  CHECK (
    relationship_to_ward IS NULL
    OR relationship_to_ward IN (
      'father',
      'mother',
      'brother',
      'sister',
      'uncle',
      'aunt',
      'guardian'
    )
  );

UPDATE public.users
SET profile_owner_type =
  CASE
    WHEN onboarding_profile_for = 'guardian' OR is_guardian_path = true
      THEN 'guardian'::public.profile_owner_type
    WHEN onboarding_profile_for = 'myself' OR is_guardian_path = false
      THEN 'self'::public.profile_owner_type
    ELSE profile_owner_type
  END
WHERE profile_owner_type IS NULL;

UPDATE public.profiles
SET profile_owner_type =
  CASE
    WHEN guardian_mode IS NOT NULL
      AND guardian_mode <> 'none'
      AND profile_creator_relation IS DISTINCT FROM 'self'
      THEN 'guardian'::public.profile_owner_type
    ELSE 'self'::public.profile_owner_type
  END
WHERE profile_owner_type IS NULL;

UPDATE public.profiles
SET relationship_to_ward =
  CASE guardian_relationship
    WHEN 'father' THEN 'father'
    WHEN 'mother' THEN 'mother'
    WHEN 'brother' THEN 'brother'
    WHEN 'sister' THEN 'sister'
    WHEN 'uncle' THEN 'uncle'
    WHEN 'aunt' THEN 'aunt'
    WHEN 'other' THEN 'guardian'
    ELSE relationship_to_ward
  END
WHERE relationship_to_ward IS NULL
  AND guardian_relationship IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_profiles_guardian_user_id
  ON public.profiles(guardian_user_id)
  WHERE guardian_user_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_profiles_profile_owner_type
  ON public.profiles(profile_owner_type);

CREATE OR REPLACE FUNCTION public.save_onboarding_profile_type(
  p_profile_for text,
  p_profile_creator_relation text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_profile_for text := lower(trim(coalesce(p_profile_for, '')));
  v_relation text := lower(trim(coalesce(p_profile_creator_relation, '')));
  v_owner_type public.profile_owner_type;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required.';
  END IF;

  IF v_profile_for NOT IN ('myself', 'guardian') THEN
    RAISE EXCEPTION 'Invalid profile type.';
  END IF;

  IF v_profile_for = 'myself' THEN
    v_relation := 'self';
    v_owner_type := 'self'::public.profile_owner_type;
  ELSE
    IF v_relation = '' THEN
      RAISE EXCEPTION 'Guardian relationship is required.';
    END IF;
    v_owner_type := 'guardian'::public.profile_owner_type;
  END IF;

  UPDATE public.users
  SET
    onboarding_profile_for = v_profile_for,
    onboarding_profile_creator_relation = v_relation,
    is_guardian_path = (v_owner_type = 'guardian'::public.profile_owner_type),
    profile_owner_type = v_owner_type
  WHERE id = v_user_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'User row missing.';
  END IF;
END;
$$;

REVOKE ALL ON FUNCTION public.save_onboarding_profile_type(text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.save_onboarding_profile_type(text, text) TO authenticated;

DROP POLICY IF EXISTS profiles_guardian_select ON public.profiles;
CREATE POLICY profiles_guardian_select ON public.profiles
  FOR SELECT TO authenticated
  USING (guardian_user_id = auth.uid());

DROP POLICY IF EXISTS profiles_guardian_insert ON public.profiles;
CREATE POLICY profiles_guardian_insert ON public.profiles
  FOR INSERT TO authenticated
  WITH CHECK (guardian_user_id = auth.uid());

DROP POLICY IF EXISTS profiles_guardian_update ON public.profiles;
CREATE POLICY profiles_guardian_update ON public.profiles
  FOR UPDATE TO authenticated
  USING (guardian_user_id = auth.uid())
  WITH CHECK (guardian_user_id = auth.uid());

DROP POLICY IF EXISTS profile_preferences_guardian_select ON public.profile_preferences;
CREATE POLICY profile_preferences_guardian_select ON public.profile_preferences
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.profiles p
      WHERE p.id = profile_preferences.profile_id
        AND p.guardian_user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS profile_preferences_guardian_insert ON public.profile_preferences;
CREATE POLICY profile_preferences_guardian_insert ON public.profile_preferences
  FOR INSERT TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM public.profiles p
      WHERE p.id = profile_preferences.profile_id
        AND p.guardian_user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS profile_preferences_guardian_update ON public.profile_preferences;
CREATE POLICY profile_preferences_guardian_update ON public.profile_preferences
  FOR UPDATE TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.profiles p
      WHERE p.id = profile_preferences.profile_id
        AND p.guardian_user_id = auth.uid()
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM public.profiles p
      WHERE p.id = profile_preferences.profile_id
        AND p.guardian_user_id = auth.uid()
    )
  );

COMMENT ON COLUMN public.users.profile_owner_type IS
  'Fast-start owner type: self or guardian. Mirrors onboarding_profile_for for robust app restore.';

COMMENT ON COLUMN public.profiles.profile_owner_type IS
  'Whether this profile is self-managed or managed by a guardian.';

COMMENT ON COLUMN public.profiles.relationship_to_ward IS
  'Exact guardian relationship to the ward profile: father, mother, brother, sister, uncle, aunt, guardian.';
