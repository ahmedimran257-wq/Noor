-- Repair live-schema drift for the Basic Identity onboarding write contract.
-- These columns already exist in the migration history, but this idempotent
-- migration guarantees older linked projects have the columns/checks used by
-- ProfileWriteService.saveStep(step: 2).

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
  ADD COLUMN IF NOT EXISTS profile_creator_relation text,
  ADD COLUMN IF NOT EXISTS ward_relationship text,
  ADD COLUMN IF NOT EXISTS guardian_mode text DEFAULT 'none',
  ADD COLUMN IF NOT EXISTS guardian_user_id uuid,
  ADD COLUMN IF NOT EXISTS guardian_relationship text,
  ADD COLUMN IF NOT EXISTS relationship_to_ward text,
  ADD COLUMN IF NOT EXISTS guardian_email text,
  ADD COLUMN IF NOT EXISTS guardian_authority_scope text,
  ADD COLUMN IF NOT EXISTS height_cm int,
  ADD COLUMN IF NOT EXISTS complexion text,
  ADD COLUMN IF NOT EXISTS mother_tongue text,
  ADD COLUMN IF NOT EXISTS community text,
  ADD COLUMN IF NOT EXISTS residency_status text,
  ADD COLUMN IF NOT EXISTS special_needs text;

ALTER TABLE public.profiles
  DROP CONSTRAINT IF EXISTS profiles_profile_creator_relation_check,
  DROP CONSTRAINT IF EXISTS profiles_ward_relationship_check,
  DROP CONSTRAINT IF EXISTS profiles_guardian_mode_check,
  DROP CONSTRAINT IF EXISTS profiles_guardian_relationship_check,
  DROP CONSTRAINT IF EXISTS profiles_relationship_to_ward_check,
  DROP CONSTRAINT IF EXISTS profiles_guardian_authority_scope_check,
  DROP CONSTRAINT IF EXISTS profiles_complexion_check,
  DROP CONSTRAINT IF EXISTS profiles_residency_status_check,
  DROP CONSTRAINT IF EXISTS profiles_special_needs_check;

ALTER TABLE public.profiles
  ADD CONSTRAINT profiles_profile_creator_relation_check
    CHECK (
      profile_creator_relation IS NULL
      OR profile_creator_relation IN ('self', 'parent', 'sibling', 'guardian')
    ) NOT VALID,
  ADD CONSTRAINT profiles_ward_relationship_check
    CHECK (
      ward_relationship IS NULL
      OR ward_relationship IN ('son', 'daughter', 'brother', 'sister')
    ) NOT VALID,
  ADD CONSTRAINT profiles_guardian_mode_check
    CHECK (guardian_mode IN ('none', 'passive', 'active')) NOT VALID,
  ADD CONSTRAINT profiles_guardian_relationship_check
    CHECK (
      guardian_relationship IS NULL
      OR guardian_relationship IN (
        'father', 'mother', 'brother', 'sister', 'uncle', 'aunt', 'other'
      )
    ) NOT VALID,
  ADD CONSTRAINT profiles_relationship_to_ward_check
    CHECK (
      relationship_to_ward IS NULL
      OR relationship_to_ward IN (
        'father', 'mother', 'brother', 'sister', 'uncle', 'aunt', 'guardian'
      )
    ) NOT VALID,
  ADD CONSTRAINT profiles_guardian_authority_scope_check
    CHECK (
      guardian_authority_scope IS NULL
      OR guardian_authority_scope IN ('full', 'advisory', 'limited')
    ) NOT VALID,
  ADD CONSTRAINT profiles_complexion_check
    CHECK (
      complexion IS NULL
      OR complexion IN ('fair', 'medium', 'olive', 'dark', 'prefer_not_to_say')
    ) NOT VALID,
  ADD CONSTRAINT profiles_residency_status_check
    CHECK (
      residency_status IS NULL
      OR residency_status IN (
        'citizen',
        'permanent_resident',
        'work_visa',
        'student_visa',
        'other',
        'prefer_not_to_say'
      )
    ) NOT VALID,
  ADD CONSTRAINT profiles_special_needs_check
    CHECK (
      special_needs IS NULL
      OR special_needs IN (
        'none', 'physical', 'hearing', 'visual', 'other', 'prefer_not_to_say'
      )
    ) NOT VALID;

CREATE INDEX IF NOT EXISTS idx_profiles_guardian_user_id
  ON public.profiles(guardian_user_id)
  WHERE guardian_user_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_profiles_profile_owner_type
  ON public.profiles(profile_owner_type);

CREATE INDEX IF NOT EXISTS idx_profiles_ward_relationship
  ON public.profiles(ward_relationship)
  WHERE ward_relationship IS NOT NULL;
