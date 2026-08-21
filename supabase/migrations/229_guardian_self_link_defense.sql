-- Guardian oversight must always belong to a different signed-in account.
-- Earlier repair logic targeted guardian-managed profiles because that was the
-- known legacy path. This closes the invariant for every profile-owner type.

UPDATE public.profiles
SET guardian_user_id = NULL,
    guardian_mode = CASE
      WHEN guardian_invitation_token_hash IS NULL THEN 'none'
      ELSE guardian_mode
    END
WHERE guardian_user_id = user_id;

CREATE OR REPLACE FUNCTION private.separate_guardian_ownership_from_oversight()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  IF NEW.guardian_user_id IS NOT NULL
     AND NEW.guardian_user_id = NEW.user_id THEN
    NEW.guardian_user_id := NULL;
    IF NEW.guardian_invitation_token_hash IS NULL THEN
      NEW.guardian_mode := 'none';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION private.separate_guardian_ownership_from_oversight()
  FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS trg_separate_guardian_ownership_from_oversight
  ON public.profiles;
CREATE TRIGGER trg_separate_guardian_ownership_from_oversight
BEFORE INSERT OR UPDATE OF profile_owner_type, guardian_user_id, guardian_mode
ON public.profiles
FOR EACH ROW
EXECUTE FUNCTION private.separate_guardian_ownership_from_oversight();

ALTER TABLE public.profiles
  DROP CONSTRAINT IF EXISTS profiles_guardian_account_must_be_distinct;
ALTER TABLE public.profiles
  ADD CONSTRAINT profiles_guardian_account_must_be_distinct
  CHECK (guardian_user_id IS NULL OR guardian_user_id <> user_id)
  NOT VALID;
ALTER TABLE public.profiles
  VALIDATE CONSTRAINT profiles_guardian_account_must_be_distinct;

COMMENT ON CONSTRAINT profiles_guardian_account_must_be_distinct
ON public.profiles IS
  'Guardian oversight requires a distinct account; profile ownership does not imply Guardian connection.';
