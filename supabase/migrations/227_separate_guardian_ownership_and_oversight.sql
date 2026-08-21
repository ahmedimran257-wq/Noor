-- A guardian-managed matrimony profile and a connected chat Guardian are two
-- different relationships:
--   * profile_owner_type = guardian: this signed-in account manages a family
--     member's matrimony profile;
--   * guardian_user_id: a distinct account accepted an optional Guardian
--     invitation for chat oversight.
-- Keeping those concepts separate prevents a creator from appearing as their
-- own connected Guardian and unblocks a real invitation later.

UPDATE public.profiles
SET guardian_user_id = NULL,
    guardian_mode = CASE
      WHEN guardian_mode = 'none' THEN guardian_mode
      ELSE 'none'
    END
WHERE profile_owner_type::text = 'guardian'
  AND guardian_user_id = user_id;

CREATE OR REPLACE FUNCTION private.separate_guardian_ownership_from_oversight()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  IF NEW.profile_owner_type::text = 'guardian'
     AND NEW.guardian_user_id = NEW.user_id THEN
    NEW.guardian_user_id := NULL;
    -- Old clients initialized a creator-managed profile as passive oversight.
    -- No oversight exists until a separate Guardian is deliberately invited.
    IF NEW.guardian_mode <> 'none'
       AND NEW.guardian_invitation_token_hash IS NULL THEN
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

-- The public trust projection exposes booleans only. It never exposes a
-- Guardian's name, phone, email, invitation code, or account identifier.
DROP FUNCTION IF EXISTS public.get_member_trust_summaries(uuid[]);
CREATE FUNCTION public.get_member_trust_summaries(p_user_ids uuid[])
RETURNS TABLE(
  user_id uuid,
  photo_verified boolean,
  phone_verified boolean,
  guardian_connected boolean,
  guardian_managed boolean,
  established_member boolean
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_me uuid := private.assert_authenticated();
  v_ids uuid[];
BEGIN
  v_ids := ARRAY(
    SELECT DISTINCT requested
    FROM unnest(coalesce(p_user_ids, ARRAY[]::uuid[])) requested
    WHERE requested IS NOT NULL
    LIMIT 20
  );
  IF cardinality(v_ids) = 0 THEN RETURN; END IF;

  RETURN QUERY
  SELECT
    p.user_id,
    (p.photo_verified_at IS NOT NULL
      AND p.photo_verification_paused_at IS NULL)::boolean,
    (u.phone_verified_at IS NOT NULL)::boolean,
    (p.guardian_user_id IS NOT NULL
      AND p.guardian_user_id <> p.user_id)::boolean,
    (p.profile_owner_type::text = 'guardian')::boolean,
    (u.created_at <= now() - interval '30 days'
      AND u.deleted_at IS NULL
      AND coalesce(u.is_banned, false) = false)::boolean
  FROM public.profiles p
  JOIN public.users u ON u.id = p.user_id
  WHERE p.user_id = ANY(v_ids)
    AND (
      p.user_id = v_me
      OR EXISTS (
        SELECT 1 FROM public.live_discovery_pool candidate
        WHERE candidate.user_id = p.user_id
      )
      OR EXISTS (
        SELECT 1 FROM public.interests i
        WHERE (i.sender_id = v_me AND i.receiver_id = p.user_id)
           OR (i.receiver_id = v_me AND i.sender_id = p.user_id)
      )
      OR EXISTS (
        SELECT 1 FROM public.matches m
        WHERE (m.user_a = v_me AND m.user_b = p.user_id)
           OR (m.user_b = v_me AND m.user_a = p.user_id)
      )
    );
END;
$$;

REVOKE ALL ON FUNCTION public.get_member_trust_summaries(uuid[])
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_member_trust_summaries(uuid[])
  TO authenticated;

CREATE OR REPLACE FUNCTION public.get_authorized_member_profiles(
  p_user_ids uuid[]
)
RETURNS SETOF jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_me uuid := auth.uid();
  v_ids uuid[];
BEGIN
  PERFORM private.assert_authenticated();
  v_ids := ARRAY(
    SELECT DISTINCT requested_id
    FROM unnest(coalesce(p_user_ids, ARRAY[]::uuid[])) requested_id
    WHERE requested_id IS NOT NULL
    LIMIT 50
  );
  IF cardinality(v_ids) = 0 THEN
    RETURN;
  END IF;

  RETURN QUERY
  SELECT jsonb_build_object(
    'id', p.id,
    'user_id', p.user_id,
    'first_name', p.first_name,
    'last_name', p.last_name,
    'last_name_initial', left(coalesce(p.last_name, ''), 1),
    'age', date_part('year', age(current_date, p.date_of_birth))::integer,
    'gender', p.gender,
    'city_name', c.name,
    'country_code', p.country_code,
    'sect', p.sect,
    'deen_level', p.deen_level,
    'photo_privacy', p.photo_privacy,
    'bio', p.bio,
    'profession', p.profession,
    'education_level', p.education_level,
    'education_rank', p.education_rank,
    'family_type', p.family_type,
    'previously_married', p.previously_married,
    'children_count', p.children_count,
    'mother_tongue', p.mother_tongue,
    'community', p.community,
    'diet_type', p.diet_type,
    'living_expectation', p.living_expectation,
    'quran_memorization', p.quran_memorization,
    'religious_education', p.religious_education,
    'marriage_timeline', p.marriage_timeline,
    'willing_to_relocate', p.willing_to_relocate,
    'height_cm', p.height_cm,
    'complexion', p.complexion,
    'smoking_habit', p.smoking_habit,
    'vaping_habit', p.vaping_habit,
    'hookah_habit', p.hookah_habit,
    'languages', coalesce(p.languages, ARRAY[]::text[]),
    'interests', coalesce(p.interests, ARRAY[]::text[]),
    'last_active_at', p.last_active_at,
    'is_verified', p.is_verified,
    'guardian_managed', p.profile_owner_type::text = 'guardian',
    'guardian_connected', p.guardian_user_id IS NOT NULL
      AND p.guardian_user_id <> p.user_id
  )
  FROM public.profiles p
  JOIN public.users u ON u.id = p.user_id
  LEFT JOIN public.cities c ON c.id = p.city_id
  WHERE p.user_id = ANY(v_ids)
    AND coalesce(u.is_banned, false) = false
    AND u.deleted_at IS NULL
    AND (
      p.user_id = v_me
      OR EXISTS (
        SELECT 1 FROM public.profile_view_daily_seen s
        WHERE s.viewer_user_id = v_me
          AND s.viewed_profile_id = p.id
          AND s.viewed_on = current_date
      )
      OR EXISTS (
        SELECT 1 FROM public.interests i
        WHERE (i.sender_id = v_me AND i.receiver_id = p.user_id)
           OR (i.receiver_id = v_me AND i.sender_id = p.user_id)
      )
      OR EXISTS (
        SELECT 1 FROM public.matches m
        WHERE (m.user_a = v_me AND m.user_b = p.user_id)
           OR (m.user_b = v_me AND m.user_a = p.user_id)
      )
      OR EXISTS (
        SELECT 1 FROM public.profile_bookmarks b
        WHERE b.user_id = v_me AND b.saved_user_id = p.user_id
      )
      OR EXISTS (
        SELECT 1 FROM public.photo_access_requests par
        WHERE par.requester_id = v_me
          AND par.owner_id = p.user_id
          AND par.status = 'granted'
      )
      OR EXISTS (
        SELECT 1 FROM public.blocks b
        WHERE (b.blocker_id = v_me AND b.blocked_id = p.user_id)
           OR (b.blocked_id = v_me AND b.blocker_id = p.user_id)
      )
      OR EXISTS (
        SELECT 1 FROM public.reports r
        WHERE r.reporter_id = v_me AND r.reported_user_id = p.user_id
      )
      OR p.guardian_user_id = v_me
      OR EXISTS (
        SELECT 1
        FROM public.guardian_chat_mirrors gcm
        JOIN public.matches gm ON gm.id = gcm.match_id
        WHERE gcm.guardian_id = v_me
          AND (
            p.user_id = gcm.ward_id
            OR (gm.user_a = gcm.ward_id AND p.user_id = gm.user_b)
            OR (gm.user_b = gcm.ward_id AND p.user_id = gm.user_a)
          )
      )
    )
  ORDER BY array_position(v_ids, p.user_id);
END;
$$;

REVOKE ALL ON FUNCTION public.get_authorized_member_profiles(uuid[])
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_authorized_member_profiles(uuid[])
  TO authenticated;

COMMENT ON FUNCTION public.get_member_trust_summaries(uuid[]) IS
  'Returns privacy-safe trust flags, separating guardian-managed ownership from a distinct connected Guardian.';

NOTIFY pgrst, 'reload schema';
