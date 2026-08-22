-- Edit Profile must not commit ordinary fields when its canonical location
-- update fails. Both existing hardened RPCs execute inside this wrapper's
-- transaction, so any exception rolls the complete edit back.

CREATE OR REPLACE FUNCTION public.save_my_profile_bundle_with_location(
  p_profile_fields jsonb DEFAULT '{}'::jsonb,
  p_preference_fields jsonb DEFAULT '{}'::jsonb,
  p_city_id int DEFAULT NULL,
  p_country_code text DEFAULT NULL,
  p_postal_code text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  PERFORM private.assert_authenticated();

  -- save_my_profile_bundle retains the strict profile/preference allowlists;
  -- update_profile_location validates the city-country pair and synchronizes
  -- users, profiles and the PostGIS discovery origin.
  PERFORM public.save_my_profile_bundle(
    coalesce(p_profile_fields, '{}'::jsonb),
    coalesce(p_preference_fields, '{}'::jsonb)
  );

  RETURN public.update_profile_location(
    p_city_id,
    p_country_code,
    p_postal_code
  );
END;
$$;

REVOKE ALL ON FUNCTION public.save_my_profile_bundle_with_location(
  jsonb, jsonb, int, text, text
) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.save_my_profile_bundle_with_location(
  jsonb, jsonb, int, text, text
) TO authenticated;

COMMENT ON FUNCTION public.save_my_profile_bundle_with_location(
  jsonb, jsonb, int, text, text
) IS
  'Atomically saves editable profile fields, preferences and canonical location.';

-- Do not allow an edit to erase a required identity name. This trigger is
-- intentionally scoped to name mutations so partially completed onboarding
-- rows created before the identity step remain writable.
CREATE OR REPLACE FUNCTION public.guard_profile_required_name_mutation()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = ''
AS $$
BEGIN
  IF NEW.first_name IS DISTINCT FROM OLD.first_name
    AND nullif(btrim(NEW.first_name), '') IS NULL
  THEN
    RAISE EXCEPTION 'first_name_required' USING ERRCODE = 'P0001';
  END IF;
  IF NEW.last_name IS DISTINCT FROM OLD.last_name
    AND nullif(btrim(NEW.last_name), '') IS NULL
  THEN
    RAISE EXCEPTION 'last_name_required' USING ERRCODE = 'P0001';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS guard_profile_required_name_mutation
  ON public.profiles;
CREATE TRIGGER guard_profile_required_name_mutation
BEFORE UPDATE OF first_name, last_name ON public.profiles
FOR EACH ROW
EXECUTE FUNCTION public.guard_profile_required_name_mutation();

REVOKE ALL ON FUNCTION public.guard_profile_required_name_mutation()
  FROM PUBLIC, anon, authenticated;
