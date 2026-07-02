-- Gender integrity lock.
--
-- profiles.gender is NOT NULL and is enforced from public.users.gender.
-- Email OTP signup creates public.users before onboarding knows gender, so
-- onboarding must set users.gender before any profile upsert writes gender.

-- Repair accounts created before the app started persisting users.gender first.
UPDATE public.users u
SET gender = p.gender
FROM public.profiles p
WHERE p.user_id = u.id
  AND u.gender IS NULL
  AND p.gender IN ('male', 'female');

UPDATE public.profiles p
SET gender = u.gender
FROM public.users u
WHERE p.user_id = u.id
  AND u.gender IN ('male', 'female')
  AND p.gender IS DISTINCT FROM u.gender;

-- First gender set is allowed. Later changes must come through a privileged
-- admin/service-role path so Islamic matching, referrals, subscription gates,
-- and discovery never see a silent client-side gender pivot.
CREATE OR REPLACE FUNCTION public.prevent_user_gender_change()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF TG_OP = 'UPDATE'
      AND OLD.gender IS NOT NULL
      AND NEW.gender IS DISTINCT FROM OLD.gender THEN
    IF auth.role() = 'service_role'
        OR public.is_active_admin(ARRAY['super_admin']) THEN
      RETURN NEW;
    END IF;

    RAISE EXCEPTION
      'gender_change_locked: gender cannot be changed after it is set without admin approval'
      USING ERRCODE = '42501';
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_prevent_user_gender_change ON public.users;
CREATE TRIGGER trg_prevent_user_gender_change
  BEFORE UPDATE OF gender ON public.users
  FOR EACH ROW
  EXECUTE FUNCTION public.prevent_user_gender_change();

COMMENT ON FUNCTION public.prevent_user_gender_change() IS
  'Allows first gender set, then blocks client-side changes. Approved corrections must use service-role/admin tooling.';

-- Keep the existing gender-pivot audit, but do not treat the first NULL -> set
-- transition as a pivot. Approved corrections cascade back into profiles so the
-- enforced invariant remains true after an admin/service-role change.
CREATE OR REPLACE FUNCTION public.handle_profile_gender_pivot()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF TG_OP = 'UPDATE'
      AND OLD.gender IS NOT NULL
      AND NEW.gender IS DISTINCT FROM OLD.gender THEN
    UPDATE public.profiles
    SET gender = NEW.gender
    WHERE user_id = NEW.id
      AND gender IS DISTINCT FROM NEW.gender;

    UPDATE public.interests
    SET status = 'expired'
    WHERE status = 'pending'
      AND (sender_id = NEW.id OR receiver_id = NEW.id);

    INSERT INTO public.admin_audit_log (
      admin_id,
      action_type,
      target_user_id,
      details
    )
    VALUES (
      COALESCE(auth.uid(), NEW.id),
      'gender_pivot_detected',
      NEW.id,
      jsonb_build_object(
        'old_gender', OLD.gender,
        'new_gender', NEW.gender,
        'actor_role', auth.role(),
        'action', 'interests_expired',
        'matches_flagged', true
      )
    );
  END IF;

  RETURN NEW;
END;
$$;

-- Null-safe profile enforcement. The app now writes users.gender first, but
-- this keeps older clients from breaking profile creation by safely locking in
-- the first supplied profile gender when users.gender is still NULL.
CREATE OR REPLACE FUNCTION public.enforce_profile_gender()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_gender text;
BEGIN
  SELECT gender
  INTO v_user_gender
  FROM public.users
  WHERE id = NEW.user_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'profile_user_missing: public.users row is required before profile write'
      USING ERRCODE = '23503';
  END IF;

  IF v_user_gender IS NULL THEN
    IF NEW.gender NOT IN ('male', 'female') THEN
      RAISE EXCEPTION 'profile_gender_required: public.users.gender must be set before profile write'
        USING ERRCODE = '23514';
    END IF;

    UPDATE public.users
    SET gender = NEW.gender
    WHERE id = NEW.user_id
      AND gender IS NULL
    RETURNING gender INTO v_user_gender;

    IF v_user_gender IS NULL THEN
      SELECT gender
      INTO v_user_gender
      FROM public.users
      WHERE id = NEW.user_id;
    END IF;
  END IF;

  IF v_user_gender IS NULL THEN
    RAISE EXCEPTION 'profile_gender_required: public.users.gender must be set before profile write'
      USING ERRCODE = '23514';
  END IF;

  NEW.gender := v_user_gender;
  RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.enforce_profile_gender() IS
  'Forces profiles.gender to match public.users.gender and safely handles the first onboarding gender set.';
