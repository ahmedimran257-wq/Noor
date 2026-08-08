-- Keep Edit Profile compatible with previously released clients while
-- preserving the hardened member-write boundary. Older clients included
-- ownership, guardian and photo-privacy snapshots in the generic edit bundle.
-- Those fields belong to dedicated RPCs and must not be changed here, but
-- rejecting them made every normal profile edit fail as one transaction.

CREATE OR REPLACE FUNCTION public.save_my_profile_bundle(
  p_profile_fields jsonb DEFAULT '{}'::jsonb,
  p_preference_fields jsonb DEFAULT '{}'::jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_user_id uuid := private.assert_authenticated();
  v_requested_profile_fields jsonb :=
    coalesce(p_profile_fields, '{}'::jsonb);
  v_profile_fields jsonb;
  v_profile jsonb;
  v_profile_id uuid;
  v_assignments text;
  v_pref_allowed constant text[] := ARRAY[
    'preferred_age_min', 'preferred_age_max', 'location_preference',
    'diaspora_mode', 'sect_preference', 'deen_preference',
    'min_education_rank', 'open_to_divorced', 'open_to_widowed',
    'open_to_has_children', 'open_to_diaspora',
    'preferred_living_expectation', 'preferred_country_codes',
    'preferred_city_ids', 'max_distance_km'
  ];
BEGIN
  -- Compatibility-only omission. Unknown fields are intentionally retained
  -- here so patch_my_profile still rejects them through its strict allowlist.
  v_profile_fields := v_requested_profile_fields - ARRAY[
    'profile_owner_type',
    'profile_creator_relation',
    'ward_relationship',
    'guardian_mode',
    'guardian_user_id',
    'guardian_name',
    'guardian_relationship',
    'relationship_to_ward',
    'guardian_email',
    'guardian_authority_scope',
    'guardian_phone_country_code',
    'photo_privacy'
  ];

  v_profile := public.patch_my_profile(v_profile_fields);

  SELECT id INTO v_profile_id
  FROM public.profiles
  WHERE user_id = v_user_id
  FOR UPDATE;

  PERFORM private.assert_jsonb_keys(
    coalesce(p_preference_fields, '{}'::jsonb),
    v_pref_allowed
  );

  IF coalesce(p_preference_fields, '{}'::jsonb) <> '{}'::jsonb THEN
    INSERT INTO public.profile_preferences(profile_id)
    VALUES (v_profile_id)
    ON CONFLICT (profile_id) DO NOTHING;

    SELECT string_agg(
      format(
        '%1$I = (jsonb_populate_record(NULL::public.profile_preferences, $1)).%1$I',
        keys.key_name
      ),
      ', '
    )
    INTO v_assignments
    FROM jsonb_object_keys(p_preference_fields) AS keys(key_name);

    EXECUTE format(
      'UPDATE public.profile_preferences SET %s WHERE profile_id = $2',
      v_assignments
    )
    USING p_preference_fields, v_profile_id;
  END IF;

  RETURN v_profile;
END;
$$;

REVOKE ALL ON FUNCTION public.save_my_profile_bundle(jsonb, jsonb)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.save_my_profile_bundle(jsonb, jsonb)
  TO authenticated;

COMMENT ON FUNCTION public.save_my_profile_bundle(jsonb, jsonb) IS
  'Atomically saves editable member fields and preferences. Legacy snapshots of ownership, guardian settings and photo privacy are ignored; those fields use dedicated RPCs.';
