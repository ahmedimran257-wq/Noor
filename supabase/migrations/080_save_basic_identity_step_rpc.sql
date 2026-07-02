-- Atomic Basic Identity save for onboarding step 2.
--
-- The Flutter client collects location in Quick Location and profile details
-- in Basic Identity. This SECURITY DEFINER boundary re-resolves country/city,
-- mirrors public.users.gender for the profile gender trigger, stores resume
-- location metadata, and upserts the profile row in one server-side operation.

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
SET search_path = public
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_country_code text := upper(trim(coalesce(p_country_code, '')));
  v_country_name text;
  v_city_name text := trim(coalesce(p_city_name, ''));
  v_region_name text;
  v_city_id int;
  v_owner_type public.profile_owner_type;
  v_creator_relation text;
  v_profile_id uuid;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required.' USING ERRCODE = '42501';
  END IF;

  IF v_country_code = '' OR length(v_country_code) <> 2 THEN
    RAISE EXCEPTION 'Valid country code is required.' USING ERRCODE = '23514';
  END IF;

  IF v_city_name = '' OR p_lat IS NULL OR p_lng IS NULL THEN
    RAISE EXCEPTION 'Resolved city, latitude, and longitude are required.'
      USING ERRCODE = '23514';
  END IF;

  IF trim(coalesce(p_first_name, '')) = '' THEN
    RAISE EXCEPTION 'First name is required.' USING ERRCODE = '23514';
  END IF;

  IF p_date_of_birth IS NULL THEN
    RAISE EXCEPTION 'Date of birth is required.' USING ERRCODE = '23514';
  END IF;

  IF p_gender NOT IN ('male', 'female') THEN
    RAISE EXCEPTION 'Gender must be male or female.' USING ERRCODE = '23514';
  END IF;

  IF p_height_cm IS NULL OR p_height_cm < 120 OR p_height_cm > 230 THEN
    RAISE EXCEPTION 'Valid height is required.' USING ERRCODE = '23514';
  END IF;

  v_owner_type :=
    CASE lower(trim(coalesce(p_profile_owner_type, 'self')))
      WHEN 'guardian' THEN 'guardian'::public.profile_owner_type
      ELSE 'self'::public.profile_owner_type
    END;

  v_creator_relation := lower(trim(coalesce(p_profile_creator_relation, '')));
  IF v_owner_type = 'self'::public.profile_owner_type THEN
    v_creator_relation := 'self';
  ELSIF v_creator_relation NOT IN ('parent', 'sibling', 'guardian') THEN
    v_creator_relation := 'guardian';
  END IF;

  SELECT name
  INTO v_country_name
  FROM public.countries
  WHERE iso_code = v_country_code;

  v_country_name := coalesce(v_country_name, v_country_code);
  v_region_name := coalesce(nullif(trim(coalesce(p_state_name, '')), ''), v_country_name);

  v_city_id := public.get_or_create_city(
    v_city_name,
    v_region_name,
    v_country_name,
    v_country_code,
    p_lat,
    p_lng
  );

  UPDATE public.users
  SET
    gender = p_gender,
    country_code = v_country_code,
    onboarding_city_id = v_city_id,
    onboarding_city_name = v_city_name,
    onboarding_state_name = nullif(trim(coalesce(p_state_name, '')), ''),
    onboarding_postal_code = nullif(trim(coalesce(p_postal_code, '')), ''),
    onboarding_lat = p_lat,
    onboarding_lng = p_lng,
    profile_owner_type = v_owner_type
  WHERE id = v_user_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'User row missing.' USING ERRCODE = '23503';
  END IF;

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
    CASE WHEN v_owner_type = 'guardian'::public.profile_owner_type THEN v_user_id ELSE NULL END,
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
) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.save_basic_identity_step(
  text, text, text, text, text, text, text, text, text, text, date, text,
  int, text, text, text, text, text, text, text, text, text, numeric, numeric
) TO authenticated;
