-- Avoid resetting a 500-recipient availability fanout when a profile save
-- merely writes the same values again. Genuine compatibility changes still
-- enqueue one coalesced event per candidate.

CREATE OR REPLACE FUNCTION private.reconcile_discovery_profile_trigger()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_compatibility_changed boolean := false;
BEGIN
  IF TG_OP = 'DELETE' THEN
    PERFORM private.reconcile_discovery_eligible_member(OLD.user_id, false);
    RETURN OLD;
  END IF;

  IF TG_OP = 'UPDATE' THEN
    v_compatibility_changed :=
      OLD.gender IS DISTINCT FROM NEW.gender
      OR OLD.country_code IS DISTINCT FROM NEW.country_code
      OR OLD.city_id IS DISTINCT FROM NEW.city_id
      OR OLD.date_of_birth IS DISTINCT FROM NEW.date_of_birth
      OR OLD.sect IS DISTINCT FROM NEW.sect
      OR OLD.deen_level IS DISTINCT FROM NEW.deen_level
      OR OLD.marriage_timeline IS DISTINCT FROM NEW.marriage_timeline
      OR OLD.mother_tongue IS DISTINCT FROM NEW.mother_tongue
      OR OLD.community IS DISTINCT FROM NEW.community
      OR OLD.living_expectation IS DISTINCT FROM NEW.living_expectation
      OR OLD.quran_memorization IS DISTINCT FROM NEW.quran_memorization
      OR OLD.willing_to_relocate IS DISTINCT FROM NEW.willing_to_relocate
      OR OLD.previously_married IS DISTINCT FROM NEW.previously_married
      OR OLD.family_type IS DISTINCT FROM NEW.family_type
      OR OLD.children_count IS DISTINCT FROM NEW.children_count
      OR OLD.education_rank IS DISTINCT FROM NEW.education_rank
      OR OLD.visibility IS DISTINCT FROM NEW.visibility
      OR OLD.onboarding_completed IS DISTINCT FROM NEW.onboarding_completed
      OR OLD.approved_at IS DISTINCT FROM NEW.approved_at;
  END IF;

  PERFORM private.reconcile_discovery_eligible_member(
    NEW.user_id,
    v_compatibility_changed
  );
  RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION private.reconcile_discovery_profile_trigger()
  FROM PUBLIC, anon, authenticated;

-- Referral reward delivery is an entitlement/account event. It must not be
-- disabled accidentally by a user's unrelated weekly-boost preference.
CREATE OR REPLACE FUNCTION public.notification_push_enabled(
  p_user_id uuid,
  p_type text
)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT CASE
    WHEN p_type IN (
      'new_message', 'guardian_message_mirror', 'guardian_sent_message'
    ) THEN coalesce(np.new_message, true)
    WHEN p_type IN (
      'interest_received', 'new_interest', 'photo_access_request'
    ) THEN coalesce(np.new_interest, true)
    WHEN p_type IN (
      'interest_accepted', 'photo_access_granted', 'match', 'match_accepted'
    ) THEN coalesce(np.interest_accepted, true)
    WHEN p_type = 'profile_view' THEN coalesce(np.profile_view, true)
    WHEN p_type IN (
      'profile_returned_to_review', 'profile_live',
      'photo_approved', 'photo_rejected'
    ) THEN coalesce(np.profile_live, true)
    WHEN p_type = 'interest_expiring'
      THEN coalesce(np.interest_expiring, true)
    WHEN p_type IN ('inactive_nudge', 'profile_nudge')
      THEN coalesce(np.inactive_nudge, true)
    WHEN p_type IN ('boost_ready', 'boost_available')
      THEN coalesce(np.boost_available, true)
    WHEN p_type IN ('referral_reward', 'referral_completed') THEN true
    WHEN p_type = 'new_compatible_profiles'
      THEN coalesce(np.new_compatible_profiles, true)
    ELSE true
  END
  FROM (SELECT p_user_id AS user_id) target
  LEFT JOIN public.notification_prefs np ON np.user_id = target.user_id;
$$;

REVOKE ALL ON FUNCTION public.notification_push_enabled(uuid, text)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.notification_push_enabled(uuid, text)
  TO service_role;

-- Keep the notification-state filter validator aligned with the canonical
-- India Premium filter contract used by the app and discovery RPC.
DO $migration$
DECLARE
  v_signature regprocedure :=
    'public.record_discovery_inventory(jsonb,boolean)'::regprocedure;
  v_definition text;
  v_updated text;
  v_anchor text :=
    '''gender_pref'', ''sect'', ''deen_level'', ''verified_only'', ''family_type''';
  v_replacement text :=
    '''gender_pref'', ''sect'', ''deen_level'', ''verified_only'', ''trust_filter'', ''state_codes'', ''city_ids'', ''family_type''';
BEGIN
  SELECT pg_get_functiondef(v_signature) INTO v_definition;
  IF position(v_replacement IN v_definition) = 0 THEN
    IF position(v_anchor IN v_definition) = 0 THEN
      RAISE EXCEPTION 'discovery_inventory_filter_anchor_not_found';
    END IF;
    EXECUTE replace(v_definition, v_anchor, v_replacement);
  END IF;
END;
$migration$;

NOTIFY pgrst, 'reload schema';
