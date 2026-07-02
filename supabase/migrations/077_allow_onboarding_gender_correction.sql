-- Allow gender corrections only while onboarding is incomplete.
--
-- The first gender value is still mirrored from public.users into profiles.
-- A user may correct an accidental tap during onboarding, but once either
-- public.users or profiles marks onboarding complete, client-side changes are
-- blocked unless performed by service-role/admin tooling.

CREATE OR REPLACE FUNCTION public.prevent_user_gender_change()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_gender_locked boolean := false;
BEGIN
  IF TG_OP = 'UPDATE'
      AND OLD.gender IS NOT NULL
      AND NEW.gender IS DISTINCT FROM OLD.gender THEN
    IF auth.role() = 'service_role'
        OR public.is_active_admin(ARRAY['super_admin']) THEN
      RETURN NEW;
    END IF;

    SELECT
      COALESCE(NEW.onboarding_completed, OLD.onboarding_completed, false)
      OR EXISTS (
        SELECT 1
        FROM public.profiles p
        WHERE p.user_id = NEW.id
          AND p.onboarding_completed = true
      )
    INTO v_gender_locked;

    IF v_gender_locked THEN
      RAISE EXCEPTION
        'gender_change_locked: gender cannot be changed after onboarding is complete without admin approval'
        USING ERRCODE = '42501';
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.prevent_user_gender_change() IS
  'Allows gender correction during incomplete onboarding, then locks client-side changes after onboarding completion.';
