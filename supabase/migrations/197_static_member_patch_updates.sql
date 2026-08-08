-- Replace the two allowlisted dynamic UPDATE builders with static, typed
-- assignments. `jsonb_populate_record` preserves omitted fields from the
-- locked base row and still supports explicit nulls for nullable fields.

CREATE OR REPLACE FUNCTION public.patch_my_user(p_fields jsonb)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_user_id uuid := private.assert_authenticated();
  v_row public.users%ROWTYPE;
  v_current public.users%ROWTYPE;
  v_allowed constant text[] := ARRAY[
    'preferred_language', 'timezone', 'country_code', 'gender',
    'is_guardian_path', 'profile_owner_type', 'onboarding_step',
    'onboarding_completed', 'onboarding_profile_for',
    'onboarding_profile_creator_relation', 'onboarding_city_id',
    'onboarding_city_name', 'onboarding_state_name',
    'onboarding_postal_code', 'onboarding_lat', 'onboarding_lng'
  ];
BEGIN
  PERFORM private.assert_jsonb_keys(p_fields, v_allowed);

  SELECT * INTO v_current
  FROM public.users
  WHERE id = v_user_id
  FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'user_not_found' USING ERRCODE = 'P0001';
  END IF;

  IF p_fields ? 'gender'
    AND v_current.onboarding_completed IS TRUE
    AND lower(p_fields->>'gender') IS DISTINCT FROM v_current.gender THEN
    RAISE EXCEPTION 'gender_change_locked' USING ERRCODE = 'P0001';
  END IF;

  SELECT populated.* INTO v_row
  FROM jsonb_populate_record(v_current, p_fields) AS populated;

  UPDATE public.users
  SET preferred_language = v_row.preferred_language,
      timezone = v_row.timezone,
      country_code = v_row.country_code,
      gender = v_row.gender,
      is_guardian_path = v_row.is_guardian_path,
      profile_owner_type = v_row.profile_owner_type,
      onboarding_step = v_row.onboarding_step,
      onboarding_completed = v_row.onboarding_completed,
      onboarding_profile_for = v_row.onboarding_profile_for,
      onboarding_profile_creator_relation =
        v_row.onboarding_profile_creator_relation,
      onboarding_city_id = v_row.onboarding_city_id,
      onboarding_city_name = v_row.onboarding_city_name,
      onboarding_state_name = v_row.onboarding_state_name,
      onboarding_postal_code = v_row.onboarding_postal_code,
      onboarding_lat = v_row.onboarding_lat,
      onboarding_lng = v_row.onboarding_lng
  WHERE id = v_user_id
  RETURNING * INTO v_row;

  RETURN to_jsonb(v_row)
    - ARRAY[
      'last_billing_event_ts', 'ban_reason', 'moderation_reason',
      'shadow_banned_at', 'moderated_by'
    ];
END;
$$;

CREATE OR REPLACE FUNCTION public.patch_my_profile(p_fields jsonb)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_user_id uuid := private.assert_authenticated();
  v_row public.profiles%ROWTYPE;
  v_current public.profiles%ROWTYPE;
  v_allowed constant text[] := ARRAY[
    'first_name', 'last_name', 'date_of_birth', 'gender',
    'country_code', 'city_id', 'sect', 'sub_sect', 'deen_level',
    'prays_five_daily', 'hijab', 'beard', 'education_level',
    'education_rank', 'field_of_study', 'profession', 'employment_status',
    'income_bracket', 'income_visibility', 'family_type', 'parents_status',
    'previously_married', 'children_count', 'is_eldest_child',
    'sibling_count', 'bio', 'languages', 'interests', 'height_cm',
    'mother_tongue', 'community', 'residency_status', 'complexion',
    'diet_type', 'smoking_habit', 'vaping_habit', 'hookah_habit',
    'living_expectation', 'quran_memorization', 'religious_education',
    'marriage_timeline', 'willing_to_relocate', 'niqab_preference',
    'mahr_expectation', 'willing_to_work_after_marriage', 'mahr_budget',
    'can_provide_housing', 'can_provide_maintenance', 'debt_status',
    'religious_leadership', 'is_revert', 'polygamy_status',
    'polygamy_acceptance', 'special_needs'
  ];
BEGIN
  PERFORM private.assert_jsonb_keys(p_fields, v_allowed);

  SELECT * INTO v_current
  FROM public.profiles
  WHERE user_id = v_user_id
  FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'profile_not_found' USING ERRCODE = 'P0001';
  END IF;

  SELECT populated.* INTO v_row
  FROM jsonb_populate_record(v_current, p_fields) AS populated;

  UPDATE public.profiles
  SET first_name = v_row.first_name,
      last_name = v_row.last_name,
      date_of_birth = v_row.date_of_birth,
      gender = v_row.gender,
      country_code = v_row.country_code,
      city_id = v_row.city_id,
      sect = v_row.sect,
      sub_sect = v_row.sub_sect,
      deen_level = v_row.deen_level,
      prays_five_daily = v_row.prays_five_daily,
      hijab = v_row.hijab,
      beard = v_row.beard,
      education_level = v_row.education_level,
      education_rank = v_row.education_rank,
      field_of_study = v_row.field_of_study,
      profession = v_row.profession,
      employment_status = v_row.employment_status,
      income_bracket = v_row.income_bracket,
      income_visibility = v_row.income_visibility,
      family_type = v_row.family_type,
      parents_status = v_row.parents_status,
      previously_married = v_row.previously_married,
      children_count = v_row.children_count,
      is_eldest_child = v_row.is_eldest_child,
      sibling_count = v_row.sibling_count,
      bio = v_row.bio,
      languages = v_row.languages,
      interests = v_row.interests,
      height_cm = v_row.height_cm,
      mother_tongue = v_row.mother_tongue,
      community = v_row.community,
      residency_status = v_row.residency_status,
      complexion = v_row.complexion,
      diet_type = v_row.diet_type,
      smoking_habit = v_row.smoking_habit,
      vaping_habit = v_row.vaping_habit,
      hookah_habit = v_row.hookah_habit,
      living_expectation = v_row.living_expectation,
      quran_memorization = v_row.quran_memorization,
      religious_education = v_row.religious_education,
      marriage_timeline = v_row.marriage_timeline,
      willing_to_relocate = v_row.willing_to_relocate,
      niqab_preference = v_row.niqab_preference,
      mahr_expectation = v_row.mahr_expectation,
      willing_to_work_after_marriage = v_row.willing_to_work_after_marriage,
      mahr_budget = v_row.mahr_budget,
      can_provide_housing = v_row.can_provide_housing,
      can_provide_maintenance = v_row.can_provide_maintenance,
      debt_status = v_row.debt_status,
      religious_leadership = v_row.religious_leadership,
      is_revert = v_row.is_revert,
      polygamy_status = v_row.polygamy_status,
      polygamy_acceptance = v_row.polygamy_acceptance,
      special_needs = v_row.special_needs
  WHERE user_id = v_user_id
  RETURNING * INTO v_row;

  RETURN to_jsonb(v_row)
    - ARRAY[
      'guardian_phone_encrypted', 'kyc_document_path', 'kyc_selfie_path',
      'suspended_reason', 'static_rank_score'
    ];
END;
$$;

REVOKE ALL ON FUNCTION public.patch_my_user(jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.patch_my_user(jsonb) TO authenticated;
REVOKE ALL ON FUNCTION public.patch_my_profile(jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.patch_my_profile(jsonb) TO authenticated;
