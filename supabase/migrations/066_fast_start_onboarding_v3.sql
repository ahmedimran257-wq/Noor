-- Fast-start onboarding v3.
-- Required signup flow is now 5 steps for both self and guardian profiles:
-- owner -> location -> basic identity -> Islamic basics -> photo/privacy.
-- Deferred compatibility fields are completed later from the profile editor.

ALTER TABLE public.profiles
  ALTER COLUMN onboarding_flow_version SET DEFAULT 3;

WITH pending AS (
  SELECT
    id,
    onboarding_step AS old_step,
    onboarding_completed AS was_complete,
    country_code IS NOT NULL AND city_id IS NOT NULL AS has_location
  FROM public.profiles
  WHERE onboarding_flow_version < 3
)
UPDATE public.profiles p
SET
  onboarding_flow_version = 3,
  onboarding_completed = CASE
    WHEN pending.was_complete THEN true
    WHEN pending.has_location AND pending.old_step >= 5 THEN true
    ELSE false
  END,
  onboarding_step = CASE
    WHEN pending.was_complete THEN 5
    WHEN NOT pending.has_location THEN 1
    WHEN pending.old_step >= 5 THEN 5
    ELSE greatest(0, least(pending.old_step, 4))
  END
FROM pending
WHERE p.id = pending.id;

COMMENT ON COLUMN public.profiles.onboarding_flow_version IS
  'Versioned app onboarding layout. v3 is fast-start 5-step onboarding; richer fields are completed from profile.';
