-- Fast-start onboarding creates the profile row before all deferred profile
-- fields exist. Incomplete profiles must never default to visible.

ALTER TABLE public.profiles
  ALTER COLUMN visibility SET DEFAULT 'paused';

UPDATE public.profiles
SET visibility = 'paused'
WHERE onboarding_completed = false
  AND visibility = 'visible';

COMMENT ON COLUMN public.profiles.visibility IS
  'Incomplete onboarding profiles default to paused. Completed profiles become visible only when required live/discovery gates pass.';
