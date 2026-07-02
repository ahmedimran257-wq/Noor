-- Store the ward relationship captured on the first guardian onboarding screen.
-- This is distinct from guardian contact metadata and prevents asking the
-- same relationship question again on Basic Identity.

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS ward_relationship text;

ALTER TABLE public.profiles
  DROP CONSTRAINT IF EXISTS profiles_ward_relationship_check;

ALTER TABLE public.profiles
  ADD CONSTRAINT profiles_ward_relationship_check
  CHECK (
    ward_relationship IS NULL
    OR ward_relationship IN ('son', 'daughter', 'brother', 'sister')
  );

UPDATE public.profiles
SET ward_relationship =
  CASE
    WHEN profile_creator_relation = 'parent' AND gender = 'female' THEN 'daughter'
    WHEN profile_creator_relation = 'parent' AND gender = 'male' THEN 'son'
    WHEN profile_creator_relation = 'sibling' AND gender = 'female' THEN 'sister'
    WHEN profile_creator_relation = 'sibling' AND gender = 'male' THEN 'brother'
    WHEN profile_creator_relation IN ('son', 'daughter', 'brother', 'sister')
      THEN profile_creator_relation
    ELSE ward_relationship
  END
WHERE ward_relationship IS NULL
  AND (
    profile_owner_type = 'guardian'::public.profile_owner_type
    OR guardian_mode IS DISTINCT FROM 'none'
  );

CREATE INDEX IF NOT EXISTS idx_profiles_ward_relationship
  ON public.profiles(ward_relationship)
  WHERE ward_relationship IS NOT NULL;

COMMENT ON COLUMN public.profiles.ward_relationship IS
  'Guardian path ward relationship captured once on ProfileForWhom: son, daughter, brother, sister.';
