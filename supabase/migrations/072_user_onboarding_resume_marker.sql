-- Persist early onboarding progress before a profiles row can legally exist.
-- Fast-start onboarding collects profile type/location before Basic Identity,
-- but profiles requires gender and date_of_birth. These user-level markers let
-- returning users resume the correct step without creating incomplete profiles.

ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS onboarding_step integer NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS is_guardian_path boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS onboarding_completed boolean NOT NULL DEFAULT false;

ALTER TABLE public.users
  DROP CONSTRAINT IF EXISTS users_onboarding_step_check;

ALTER TABLE public.users
  ADD CONSTRAINT users_onboarding_step_check
  CHECK (onboarding_step >= 0 AND onboarding_step <= 5);

UPDATE public.users u
SET
  onboarding_step = greatest(coalesce(u.onboarding_step, 0), coalesce(p.onboarding_step, 0)),
  is_guardian_path = coalesce(p.guardian_mode <> 'none', u.is_guardian_path, false),
  onboarding_completed = coalesce(p.onboarding_completed, u.onboarding_completed, false)
FROM public.profiles p
WHERE p.user_id = u.id;

CREATE INDEX IF NOT EXISTS idx_users_onboarding_resume
  ON public.users (onboarding_completed, onboarding_step);

CREATE OR REPLACE FUNCTION public.advance_onboarding_step_monotonic(p_step integer)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid := auth.uid();
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required.';
  END IF;

  -- Monotonic forward-only update: stale async saves cannot regress the step.
  UPDATE public.users
  SET onboarding_step = greatest(coalesce(onboarding_step, 0), p_step)
  WHERE id = v_user_id;

  UPDATE public.profiles
  SET onboarding_step = greatest(coalesce(onboarding_step, 0), p_step)
  WHERE user_id = v_user_id;
END;
$$;

COMMENT ON COLUMN public.users.onboarding_step IS
  'Resume marker for early onboarding before profiles can be inserted.';

COMMENT ON COLUMN public.users.is_guardian_path IS
  'Resume marker for whether the fast-start onboarding path is guardian-created.';

COMMENT ON COLUMN public.users.onboarding_completed IS
  'Auth-routing completion marker mirrored from profiles once profile creation is complete.';
