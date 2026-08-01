-- Keep Basic Identity compatible with the service-only city catalogue boundary.
--
-- Migration 160 correctly prevented member clients from creating shared city
-- rows, but the older Basic Identity definer still called get_or_create_city()
-- under the member JWT. That made every Step 3 save fail with
-- invalid_location_resolution. Quick Location has already resolved and stored
-- the trusted city id, so this transaction reuses that server-owned result.

CREATE OR REPLACE FUNCTION public.save_basic_identity_step(
  p_profile_owner_type text,
  p_profile_creator_relation text,
  p_ward_relationship text,
  p_guardian_mode text,
  p_guardian_relationship text,
  p_relationship_to_ward text,
  p_guardian_email text,
  p_guardian_authority_scope text,
  p_first_name text,
  p_last_name text,
  p_date_of_birth date,
  p_gender text,
  p_height_cm int,
  p_complexion text,
  p_mother_tongue text,
  p_community text,
  p_residency_status text,
  p_special_needs text,
  p_country_code text,
  p_city_name text,
  p_state_name text,
  p_postal_code text,
  p_lat numeric,
  p_lng numeric
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_user_id uuid := private.assert_authenticated();
  v_country_code text := upper(trim(coalesce(p_country_code, '')));
  v_city_name text := trim(coalesce(p_city_name, ''));
  v_city_id integer;
  v_owner_type public.profile_owner_type;
  v_creator_relation text;
  v_profile_id uuid;
BEGIN
  IF v_country_code !~ '^[A-Z]{2}$'
    OR v_city_name = ''
    OR p_lat IS NULL
    OR p_lng IS NULL THEN
    RAISE EXCEPTION 'verified_location_required' USING ERRCODE = '23514';
  END IF;

  IF trim(coalesce(p_first_name, '')) = '' THEN
    RAISE EXCEPTION 'first_name_required' USING ERRCODE = '23514';
  END IF;
  IF p_date_of_birth IS NULL THEN
    RAISE EXCEPTION 'date_of_birth_required' USING ERRCODE = '23514';
  END IF;
  IF p_gender NOT IN ('male', 'female') THEN
    RAISE EXCEPTION 'invalid_gender' USING ERRCODE = '23514';
  END IF;
  IF p_height_cm IS NULL OR p_height_cm NOT BETWEEN 120 AND 230 THEN
    RAISE EXCEPTION 'invalid_height' USING ERRCODE = '23514';
  END IF;

  SELECT u.onboarding_city_id
  INTO v_city_id
  FROM public.users u
  WHERE u.id = v_user_id
    AND u.onboarding_city_id IS NOT NULL
    AND upper(coalesce(u.country_code, '')) = v_country_code
    AND lower(trim(coalesce(u.onboarding_city_name, ''))) =
        lower(v_city_name)
  FOR UPDATE;

  IF v_city_id IS NULL OR NOT EXISTS (
    SELECT 1
    FROM public.cities c
    JOIN public.regions r ON r.id = c.region_id
    WHERE c.id = v_city_id
      AND upper(r.country_code) = v_country_code
  ) THEN
    RAISE EXCEPTION 'verified_location_required' USING ERRCODE = '23514';
  END IF;

  v_owner_type := CASE lower(trim(coalesce(p_profile_owner_type, 'self')))
    WHEN 'guardian' THEN 'guardian'::public.profile_owner_type
    ELSE 'self'::public.profile_owner_type
  END;

  v_creator_relation :=
      lower(trim(coalesce(p_profile_creator_relation, '')));
  IF v_owner_type = 'self'::public.profile_owner_type THEN
    v_creator_relation := 'self';
  ELSIF v_creator_relation NOT IN ('parent', 'sibling', 'guardian') THEN
    v_creator_relation := 'guardian';
  END IF;

  UPDATE public.users
  SET gender = p_gender,
      profile_owner_type = v_owner_type
  WHERE id = v_user_id;

  INSERT INTO public.profiles (
    user_id,
    profile_owner_type,
    profile_creator_relation,
    ward_relationship,
    guardian_mode,
    guardian_user_id,
    guardian_relationship,
    relationship_to_ward,
    guardian_email,
    guardian_authority_scope,
    first_name,
    last_name,
    date_of_birth,
    gender,
    city_id,
    country_code,
    height_cm,
    complexion,
    mother_tongue,
    community,
    residency_status,
    special_needs
  )
  VALUES (
    v_user_id,
    v_owner_type,
    v_creator_relation,
    nullif(trim(coalesce(p_ward_relationship, '')), ''),
    coalesce(nullif(trim(coalesce(p_guardian_mode, '')), ''), 'none'),
    CASE
      WHEN v_owner_type = 'guardian'::public.profile_owner_type
      THEN v_user_id
      ELSE NULL
    END,
    nullif(trim(coalesce(p_guardian_relationship, '')), ''),
    nullif(trim(coalesce(p_relationship_to_ward, '')), ''),
    nullif(trim(coalesce(p_guardian_email, '')), ''),
    nullif(trim(coalesce(p_guardian_authority_scope, '')), ''),
    trim(p_first_name),
    nullif(trim(coalesce(p_last_name, '')), ''),
    p_date_of_birth,
    p_gender,
    v_city_id,
    v_country_code,
    p_height_cm,
    nullif(trim(coalesce(p_complexion, '')), ''),
    nullif(trim(coalesce(p_mother_tongue, '')), ''),
    nullif(trim(coalesce(p_community, '')), ''),
    nullif(trim(coalesce(p_residency_status, '')), ''),
    nullif(trim(coalesce(p_special_needs, '')), '')
  )
  ON CONFLICT (user_id) DO UPDATE SET
    profile_owner_type = EXCLUDED.profile_owner_type,
    profile_creator_relation = EXCLUDED.profile_creator_relation,
    ward_relationship = EXCLUDED.ward_relationship,
    guardian_mode = EXCLUDED.guardian_mode,
    guardian_user_id = EXCLUDED.guardian_user_id,
    guardian_relationship = EXCLUDED.guardian_relationship,
    relationship_to_ward = EXCLUDED.relationship_to_ward,
    guardian_email = EXCLUDED.guardian_email,
    guardian_authority_scope = EXCLUDED.guardian_authority_scope,
    first_name = EXCLUDED.first_name,
    last_name = EXCLUDED.last_name,
    date_of_birth = EXCLUDED.date_of_birth,
    gender = EXCLUDED.gender,
    city_id = EXCLUDED.city_id,
    country_code = EXCLUDED.country_code,
    height_cm = EXCLUDED.height_cm,
    complexion = EXCLUDED.complexion,
    mother_tongue = EXCLUDED.mother_tongue,
    community = EXCLUDED.community,
    residency_status = EXCLUDED.residency_status,
    special_needs = EXCLUDED.special_needs
  RETURNING id INTO v_profile_id;

  RETURN v_profile_id;
END;
$$;

REVOKE ALL ON FUNCTION public.save_basic_identity_step(
  text, text, text, text, text, text, text, text, text, text, date, text,
  int, text, text, text, text, text, text, text, text, text, numeric, numeric
) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.save_basic_identity_step(
  text, text, text, text, text, text, text, text, text, text, date, text,
  int, text, text, text, text, text, text, text, text, text, numeric, numeric
) TO authenticated;

COMMENT ON FUNCTION public.save_basic_identity_step(
  text, text, text, text, text, text, text, text, text, text, date, text,
  int, text, text, text, text, text, text, text, text, text, numeric, numeric
) IS
  'Atomically saves Basic Identity using the service-verified Quick Location city.';
