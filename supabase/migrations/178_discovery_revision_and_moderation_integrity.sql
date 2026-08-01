-- Make discovery immediately consistent without reloading the full feed on
-- every tab change, and close the remaining moderation lifecycle gaps.

-- ---------------------------------------------------------------------------
-- 1. Every profile gets a preference row, but discovery never depends on it.
-- Partner preferences are optional in fast-start onboarding.
-- ---------------------------------------------------------------------------
INSERT INTO public.profile_preferences(profile_id)
SELECT p.id
FROM public.profiles p
LEFT JOIN public.profile_preferences prefs ON prefs.profile_id = p.id
WHERE prefs.profile_id IS NULL
ON CONFLICT (profile_id) DO NOTHING;

CREATE OR REPLACE FUNCTION private.ensure_profile_preferences_row()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  INSERT INTO public.profile_preferences(profile_id)
  VALUES (NEW.id)
  ON CONFLICT (profile_id) DO NOTHING;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_ensure_profile_preferences_row ON public.profiles;
CREATE TRIGGER trg_ensure_profile_preferences_row
  AFTER INSERT ON public.profiles
  FOR EACH ROW
  EXECUTE FUNCTION private.ensure_profile_preferences_row();

CREATE OR REPLACE VIEW public.live_discovery_pool
WITH (security_invoker = true)
AS
SELECT
  p.id AS profile_id,
  p.user_id,
  p.gender,
  p.first_name,
  p.last_name AS last_name_initial,
  extract(year FROM age(p.date_of_birth))::integer AS age,
  c.name AS city_name,
  p.country_code,
  p.city_id,
  p.sect::text AS sect,
  p.deen_level::text AS deen_level,
  p.profession,
  p.bio,
  CASE WHEN p.photo_privacy = 'public' THEN primary_photo.storage_path END
    AS photo_url,
  photo_totals.photo_count,
  p.photo_privacy::text AS photo_privacy,
  p.is_verified,
  p.location,
  p.static_rank_score AS rank_score,
  p.marriage_timeline,
  p.height_cm,
  p.complexion,
  p.mother_tongue,
  p.smoking_habit,
  p.community,
  p.diet_type,
  p.living_expectation,
  p.quran_memorization,
  p.religious_education,
  p.willing_to_relocate,
  p.previously_married,
  p.family_type,
  p.children_count,
  p.education_rank,
  prefs.preferred_age_min,
  prefs.preferred_age_max,
  p.last_active_at,
  CASE WHEN p.photo_privacy = 'public' THEN primary_photo.blurhash END
    AS blurhash
FROM public.profiles p
JOIN public.users account ON account.id = p.user_id
LEFT JOIN public.cities c ON c.id = p.city_id
LEFT JOIN public.profile_preferences prefs ON prefs.profile_id = p.id
JOIN LATERAL (
  SELECT count(*)::integer AS photo_count
  FROM public.photos ph
  WHERE ph.profile_id = p.id
    AND ph.status = 'active'
    AND ph.admin_approved = true
    AND ph.nsfw_cleared = true
) photo_totals ON photo_totals.photo_count > 0
JOIN LATERAL (
  SELECT ph.storage_path, ph.blurhash
  FROM public.photos ph
  WHERE ph.profile_id = p.id
    AND ph.order_index = 0
    AND ph.status = 'active'
    AND ph.admin_approved = true
    AND ph.nsfw_cleared = true
  ORDER BY ph.created_at DESC
  LIMIT 1
) primary_photo ON true
WHERE p.visibility = 'visible'
  AND p.onboarding_completed = true
  AND p.approved_at IS NOT NULL
  AND account.deleted_at IS NULL
  AND coalesce(account.is_banned, false) = false
  AND coalesce(account.is_shadowbanned, false) = false;

REVOKE ALL ON public.live_discovery_pool FROM PUBLIC, anon, authenticated;

COMMENT ON VIEW public.live_discovery_pool IS
  'Canonical immediately consistent discovery source. Preferences are optional; account and primary-photo eligibility are authoritative.';

-- Defensive repair: later function replacements must not move the feed or its
-- photo authorization boundary back to the nightly materialized pool. Reports
-- remain hidden from the reporter even after the local widget is rebuilt.
DO $migration$
DECLARE
  v_signature regprocedure :=
    'public.get_discovery_feed(uuid,double precision,uuid,integer,jsonb)'::regprocedure;
  v_definition text;
  v_updated text;
  v_needle text := $needle$      AND NOT EXISTS (
        SELECT 1 FROM public.interests i$needle$;
  v_replacement text := $replacement$      AND NOT EXISTS (
        SELECT 1 FROM public.reports hidden_report
        WHERE hidden_report.reporter_id = p_viewer_id
          AND hidden_report.reported_user_id = dp.user_id
      )
      AND NOT EXISTS (
        SELECT 1 FROM public.interests i$replacement$;
BEGIN
  SELECT pg_get_functiondef(v_signature) INTO v_definition;
  v_updated := replace(
    v_definition,
    'FROM public.discovery_pool dp',
    'FROM public.live_discovery_pool dp'
  );

  IF position('FROM public.live_discovery_pool dp' IN v_updated) = 0 THEN
    RAISE EXCEPTION 'discovery_feed_live_source_not_found'
      USING ERRCODE = 'P0001';
  END IF;

  IF position('FROM public.reports hidden_report' IN v_updated) = 0 THEN
    v_updated := replace(v_updated, v_needle, v_replacement);
    IF position('FROM public.reports hidden_report' IN v_updated) = 0 THEN
      RAISE EXCEPTION 'discovery_feed_report_exclusion_anchor_not_found'
        USING ERRCODE = 'P0001';
    END IF;
  END IF;

  IF v_updated IS DISTINCT FROM v_definition THEN
    EXECUTE v_updated;
  END IF;
END;
$migration$;

DO $migration$
DECLARE
  v_signature regprocedure :=
    'public.get_authorized_photo_paths(uuid,uuid[],integer)'::regprocedure;
  v_definition text;
  v_updated text;
BEGIN
  SELECT pg_get_functiondef(v_signature) INTO v_definition;
  v_updated := replace(
    v_definition,
    'FROM public.discovery_pool candidate',
    'FROM public.live_discovery_pool candidate'
  );

  IF position('FROM public.live_discovery_pool candidate' IN v_updated) = 0 THEN
    RAISE EXCEPTION 'photo_authorization_live_source_not_found'
      USING ERRCODE = 'P0001';
  END IF;

  IF v_updated IS DISTINCT FROM v_definition THEN
    EXECUTE v_updated;
  END IF;
END;
$migration$;

-- ---------------------------------------------------------------------------
-- 2. Cheap server revision token. Catalog changes are global; relationship
-- changes are scoped to the two affected members. The app polls this tiny RPC
-- on resume/tab selection and reloads the expensive feed only after a change.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS private.discovery_catalog_revision (
  singleton boolean PRIMARY KEY DEFAULT true CHECK (singleton),
  revision bigint NOT NULL DEFAULT 1 CHECK (revision > 0),
  changed_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS private.discovery_member_revisions (
  user_id uuid PRIMARY KEY REFERENCES public.users(id) ON DELETE CASCADE,
  revision bigint NOT NULL DEFAULT 1 CHECK (revision > 0),
  changed_at timestamptz NOT NULL DEFAULT now()
);

INSERT INTO private.discovery_catalog_revision(singleton)
VALUES (true)
ON CONFLICT (singleton) DO NOTHING;

REVOKE ALL ON private.discovery_catalog_revision
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON private.discovery_member_revisions
  FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION private.bump_discovery_catalog_revision()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  UPDATE private.discovery_catalog_revision
  SET revision = revision + 1,
      changed_at = now()
  WHERE singleton = true;
  IF TG_OP = 'DELETE' THEN RETURN OLD; END IF;
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION private.touch_discovery_member(p_user_id uuid)
RETURNS void
LANGUAGE sql
SECURITY DEFINER
SET search_path = ''
AS $$
  INSERT INTO private.discovery_member_revisions(user_id, revision, changed_at)
  SELECT p_user_id, 1, now()
  WHERE p_user_id IS NOT NULL
  ON CONFLICT (user_id) DO UPDATE
  SET revision = private.discovery_member_revisions.revision + 1,
      changed_at = now();
$$;

CREATE OR REPLACE FUNCTION private.bump_discovery_pair_revision()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_user_a uuid;
  v_user_b uuid;
BEGIN
  IF TG_TABLE_NAME = 'blocks' THEN
    v_user_a := CASE WHEN TG_OP = 'DELETE' THEN OLD.blocker_id ELSE NEW.blocker_id END;
    v_user_b := CASE WHEN TG_OP = 'DELETE' THEN OLD.blocked_id ELSE NEW.blocked_id END;
  ELSIF TG_TABLE_NAME = 'interests' THEN
    v_user_a := CASE WHEN TG_OP = 'DELETE' THEN OLD.sender_id ELSE NEW.sender_id END;
    v_user_b := CASE WHEN TG_OP = 'DELETE' THEN OLD.receiver_id ELSE NEW.receiver_id END;
  ELSIF TG_TABLE_NAME = 'matches' THEN
    v_user_a := CASE WHEN TG_OP = 'DELETE' THEN OLD.user_a ELSE NEW.user_a END;
    v_user_b := CASE WHEN TG_OP = 'DELETE' THEN OLD.user_b ELSE NEW.user_b END;
  ELSE
    RAISE EXCEPTION 'unsupported_discovery_pair_table: %', TG_TABLE_NAME;
  END IF;

  PERFORM private.touch_discovery_member(v_user_a);
  PERFORM private.touch_discovery_member(v_user_b);
  IF TG_OP = 'DELETE' THEN RETURN OLD; END IF;
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION private.bump_reporter_discovery_revision()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  PERFORM private.touch_discovery_member(
    CASE WHEN TG_OP = 'DELETE' THEN OLD.reporter_id ELSE NEW.reporter_id END
  );
  IF TG_OP = 'DELETE' THEN RETURN OLD; END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_discovery_catalog_profile_rows ON public.profiles;
CREATE TRIGGER trg_discovery_catalog_profile_rows
  AFTER INSERT OR DELETE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION private.bump_discovery_catalog_revision();

DROP TRIGGER IF EXISTS trg_discovery_catalog_profile_updates ON public.profiles;
CREATE TRIGGER trg_discovery_catalog_profile_updates
  AFTER UPDATE OF gender, visibility, onboarding_completed, approved_at,
    first_name, last_name, date_of_birth, city_id, country_code, sect,
    deen_level, profession, bio, photo_privacy, is_verified, location,
    static_rank_score, marriage_timeline, height_cm, complexion, mother_tongue,
    smoking_habit, community, diet_type, living_expectation,
    quran_memorization, religious_education, willing_to_relocate,
    previously_married, family_type, children_count, education_rank,
    languages, interests
  ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION private.bump_discovery_catalog_revision();

DROP TRIGGER IF EXISTS trg_discovery_catalog_photos ON public.photos;
CREATE TRIGGER trg_discovery_catalog_photos
  AFTER INSERT OR DELETE OR UPDATE OF status, order_index, admin_approved,
    nsfw_cleared, storage_path, blurhash
  ON public.photos
  FOR EACH ROW EXECUTE FUNCTION private.bump_discovery_catalog_revision();

DROP TRIGGER IF EXISTS trg_discovery_catalog_preferences
  ON public.profile_preferences;
CREATE TRIGGER trg_discovery_catalog_preferences
  AFTER INSERT OR UPDATE OR DELETE ON public.profile_preferences
  FOR EACH ROW EXECUTE FUNCTION private.bump_discovery_catalog_revision();

DROP TRIGGER IF EXISTS trg_discovery_catalog_accounts ON public.users;
CREATE TRIGGER trg_discovery_catalog_accounts
  AFTER UPDATE OF gender, is_banned, is_shadowbanned, deleted_at
  ON public.users
  FOR EACH ROW EXECUTE FUNCTION private.bump_discovery_catalog_revision();

DROP TRIGGER IF EXISTS trg_discovery_revision_blocks ON public.blocks;
CREATE TRIGGER trg_discovery_revision_blocks
  AFTER INSERT OR UPDATE OR DELETE ON public.blocks
  FOR EACH ROW EXECUTE FUNCTION private.bump_discovery_pair_revision();

DROP TRIGGER IF EXISTS trg_discovery_revision_interests ON public.interests;
CREATE TRIGGER trg_discovery_revision_interests
  AFTER INSERT OR UPDATE OR DELETE ON public.interests
  FOR EACH ROW EXECUTE FUNCTION private.bump_discovery_pair_revision();

DROP TRIGGER IF EXISTS trg_discovery_revision_matches ON public.matches;
CREATE TRIGGER trg_discovery_revision_matches
  AFTER INSERT OR UPDATE OR DELETE ON public.matches
  FOR EACH ROW EXECUTE FUNCTION private.bump_discovery_pair_revision();

DROP TRIGGER IF EXISTS trg_discovery_revision_reports ON public.reports;
CREATE TRIGGER trg_discovery_revision_reports
  AFTER INSERT OR UPDATE OR DELETE ON public.reports
  FOR EACH ROW EXECUTE FUNCTION private.bump_reporter_discovery_revision();

CREATE OR REPLACE FUNCTION public.get_my_discovery_revision()
RETURNS TABLE (
  revision_token text,
  catalog_revision bigint,
  member_revision bigint,
  changed_at timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_me uuid := auth.uid();
BEGIN
  IF v_me IS NULL THEN
    RAISE EXCEPTION 'authentication_required' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  SELECT
    catalog.revision::text || ':' || coalesce(member.revision, 0)::text,
    catalog.revision,
    coalesce(member.revision, 0)::bigint,
    greatest(catalog.changed_at, coalesce(member.changed_at, catalog.changed_at))
  FROM private.discovery_catalog_revision catalog
  LEFT JOIN private.discovery_member_revisions member ON member.user_id = v_me
  WHERE catalog.singleton = true;
END;
$$;

REVOKE ALL ON FUNCTION public.get_my_discovery_revision()
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_my_discovery_revision()
  TO authenticated;

COMMENT ON FUNCTION public.get_my_discovery_revision() IS
  'Low-cost catalog plus member relationship revision used to invalidate an already loaded discovery feed.';

-- ---------------------------------------------------------------------------
-- 3. Blocks and reports use checked RPC boundaries and preserve evidence.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.sever_ties_on_block()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  UPDATE public.matches
  SET status = 'blocked',
      closed_by = NEW.blocker_id,
      closed_at = now(),
      closure_reason = 'user_blocked'
  WHERE (
      (user_a = NEW.blocker_id AND user_b = NEW.blocked_id)
      OR (user_b = NEW.blocker_id AND user_a = NEW.blocked_id)
    )
    AND status <> 'blocked';

  DELETE FROM public.interests
  WHERE (sender_id = NEW.blocker_id AND receiver_id = NEW.blocked_id)
     OR (sender_id = NEW.blocked_id AND receiver_id = NEW.blocker_id);
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_sever_ties_on_block ON public.blocks;
CREATE TRIGGER trg_sever_ties_on_block
  AFTER INSERT OR UPDATE ON public.blocks
  FOR EACH ROW EXECUTE FUNCTION public.sever_ties_on_block();

CREATE OR REPLACE FUNCTION public.block_member(
  p_user_id uuid,
  p_reason text DEFAULT NULL
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_me uuid := auth.uid();
BEGIN
  IF v_me IS NULL THEN
    RAISE EXCEPTION 'authentication_required' USING ERRCODE = '42501';
  END IF;
  IF p_user_id IS NULL OR p_user_id = v_me THEN
    RAISE EXCEPTION 'invalid_block_target' USING ERRCODE = 'P0001';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.users
    WHERE id = p_user_id AND deleted_at IS NULL
  ) THEN
    RAISE EXCEPTION 'block_target_unavailable' USING ERRCODE = 'P0001';
  END IF;

  INSERT INTO public.blocks(blocker_id, blocked_id, reason)
  VALUES (
    v_me,
    p_user_id,
    nullif(left(trim(coalesce(p_reason, '')), 500), '')
  )
  ON CONFLICT (blocker_id, blocked_id) DO UPDATE
  SET reason = coalesce(EXCLUDED.reason, public.blocks.reason);
  RETURN true;
END;
$$;

CREATE OR REPLACE FUNCTION public.unblock_member(p_user_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_me uuid := auth.uid();
  v_removed boolean;
BEGIN
  IF v_me IS NULL THEN
    RAISE EXCEPTION 'authentication_required' USING ERRCODE = '42501';
  END IF;
  DELETE FROM public.blocks
  WHERE blocker_id = v_me AND blocked_id = p_user_id;
  v_removed := FOUND;
  -- Unblocking never reopens a conversation or restores deleted interests.
  RETURN v_removed;
END;
$$;

CREATE OR REPLACE FUNCTION public.block_chat_user(
  p_user_id uuid,
  p_reason text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  PERFORM public.block_member(p_user_id, p_reason);
END;
$$;

CREATE OR REPLACE FUNCTION public.report_chat_message(
  p_message_id uuid,
  p_reason text,
  p_description text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_me uuid := auth.uid();
  v_msg public.messages%rowtype;
  v_reason text := lower(coalesce(p_reason, 'other'));
BEGIN
  IF v_me IS NULL THEN
    RAISE EXCEPTION 'authentication_required' USING ERRCODE = '42501';
  END IF;

  SELECT * INTO v_msg
  FROM public.messages
  WHERE id = p_message_id;

  IF NOT FOUND OR v_msg.receiver_id <> v_me THEN
    RAISE EXCEPTION 'message_not_reportable' USING ERRCODE = 'P0001';
  END IF;
  IF v_reason NOT IN (
    'harassment', 'inappropriate', 'scam', 'contact_sharing', 'other'
  ) THEN
    v_reason := 'other';
  END IF;

  INSERT INTO public.message_reports(
    message_id, match_id, reporter_id, reported_user_id, reason, description
  )
  VALUES (
    v_msg.id, v_msg.match_id, v_me, v_msg.sender_id, v_reason,
    nullif(left(trim(coalesce(p_description, '')), 1000), '')
  )
  ON CONFLICT (message_id, reporter_id) DO UPDATE
  SET reason = EXCLUDED.reason,
      description = EXCLUDED.description,
      status = 'pending',
      created_at = now();

  UPDATE public.matches
  SET status = 'reported',
      closed_by = v_me,
      closed_at = coalesce(closed_at, now()),
      closure_reason = 'message_report_submitted'
  WHERE id = v_msg.match_id
    AND status = 'active';

  INSERT INTO public.admin_notifications(type, message, related_user_id)
  VALUES (
    'message_report_received',
    'A reported chat message requires moderation review.',
    v_msg.sender_id
  );
END;
$$;

REVOKE INSERT, UPDATE, DELETE ON public.blocks FROM anon, authenticated;
DROP POLICY IF EXISTS blocks_insert ON public.blocks;
DROP POLICY IF EXISTS blocks_delete ON public.blocks;

REVOKE ALL ON FUNCTION public.block_member(uuid, text)
  FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.unblock_member(uuid)
  FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.block_chat_user(uuid, text)
  FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.report_chat_message(uuid, text, text)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.block_member(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.unblock_member(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.block_chat_user(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.report_chat_message(uuid, text, text)
  TO authenticated;

-- ---------------------------------------------------------------------------
-- 4. Staff diagnostics and actions say exactly what they do.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.admin_discovery_eligibility(
  p_search text DEFAULT NULL,
  p_limit integer DEFAULT 50
)
RETURNS TABLE (
  profile_id uuid,
  user_id uuid,
  member_name text,
  gender text,
  created_at timestamptz,
  eligible boolean,
  exclusion_reasons text[],
  diagnostic_notes text[],
  approved_photo_count integer
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  IF NOT public.is_active_admin(ARRAY['super_admin', 'moderator']) THEN
    RAISE EXCEPTION 'staff_authorization_required' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  SELECT
    p.id,
    p.user_id,
    trim(concat_ws(' ', p.first_name, p.last_name)),
    p.gender::text,
    p.created_at,
    p.visibility = 'visible'
      AND coalesce(p.onboarding_completed, false)
      AND p.approved_at IS NOT NULL
      AND account.deleted_at IS NULL
      AND coalesce(account.is_banned, false) = false
      AND coalesce(account.is_shadowbanned, false) = false
      AND photos.primary_count > 0,
    array_remove(ARRAY[
      CASE WHEN p.visibility <> 'visible'
        THEN 'profile_' || p.visibility::text END,
      CASE WHEN NOT coalesce(p.onboarding_completed, false)
        THEN 'onboarding_incomplete' END,
      CASE WHEN p.approved_at IS NULL THEN 'profile_not_approved' END,
      CASE WHEN account.deleted_at IS NOT NULL THEN 'account_deleted' END,
      CASE WHEN coalesce(account.is_banned, false) THEN 'account_banned' END,
      CASE WHEN coalesce(account.is_shadowbanned, false)
        THEN 'account_shadowbanned' END,
      CASE WHEN photos.primary_count = 0 THEN 'approved_primary_photo_missing' END
    ]::text[], NULL),
    array_remove(ARRAY[
      CASE WHEN prefs.profile_id IS NULL
        THEN 'preferences_missing_defaults_are_used' END
    ]::text[], NULL),
    photos.approved_count
  FROM public.profiles p
  JOIN public.users account ON account.id = p.user_id
  LEFT JOIN public.profile_preferences prefs ON prefs.profile_id = p.id
  JOIN LATERAL (
    SELECT
      count(*) FILTER (
        WHERE ph.status = 'active'
          AND ph.admin_approved = true
          AND ph.nsfw_cleared = true
      )::integer AS approved_count,
      count(*) FILTER (
        WHERE ph.order_index = 0
          AND ph.status = 'active'
          AND ph.admin_approved = true
          AND ph.nsfw_cleared = true
      )::integer AS primary_count
    FROM public.photos ph
    WHERE ph.profile_id = p.id
  ) photos ON true
  WHERE nullif(trim(coalesce(p_search, '')), '') IS NULL
     OR p.id::text = trim(p_search)
     OR p.user_id::text = trim(p_search)
     OR concat_ws(' ', p.first_name, p.last_name)
          ILIKE '%' || trim(p_search) || '%'
  ORDER BY p.created_at DESC
  LIMIT greatest(1, least(coalesce(p_limit, 50), 100));
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_resolve_report(
  p_report_id uuid,
  p_action text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_target uuid;
  v_action text := lower(coalesce(p_action, ''));
BEGIN
  IF NOT public.is_active_admin(ARRAY['super_admin', 'moderator']) THEN
    RAISE EXCEPTION 'staff_authorization_required' USING ERRCODE = '42501';
  END IF;
  IF v_action NOT IN ('actioned', 'dismissed') THEN
    RAISE EXCEPTION 'unsupported_report_action' USING ERRCODE = 'P0001';
  END IF;

  UPDATE public.reports
  SET status = v_action
  WHERE id = p_report_id AND status = 'pending'
  RETURNING reported_user_id INTO v_target;
  IF v_target IS NULL THEN
    RAISE EXCEPTION 'report_not_pending' USING ERRCODE = 'P0001';
  END IF;

  IF v_action = 'actioned' THEN
    UPDATE public.profiles
    SET visibility = 'suspended',
        suspended_reason = 'moderation_report_actioned'
    WHERE user_id = v_target;
  END IF;

  DELETE FROM public.admin_work_locks
  WHERE item_type = 'report' AND item_id = p_report_id;
  INSERT INTO public.admin_audit_log(
    admin_id, actor_role, action_type, target_user_id, details
  ) VALUES (
    auth.uid(), public.current_admin_role(), 'report_' || v_action, v_target,
    jsonb_build_object(
      'report_id', p_report_id,
      'profile_suspended', v_action = 'actioned'
    )
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_resolve_message_report(
  p_report_id uuid,
  p_action text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_target uuid;
  v_action text := lower(coalesce(p_action, ''));
BEGIN
  IF NOT public.is_active_admin(ARRAY['super_admin', 'moderator']) THEN
    RAISE EXCEPTION 'staff_authorization_required' USING ERRCODE = '42501';
  END IF;
  IF v_action NOT IN ('reviewed', 'dismissed', 'actioned') THEN
    RAISE EXCEPTION 'invalid_message_report_action' USING ERRCODE = 'P0001';
  END IF;

  UPDATE public.message_reports
  SET status = v_action
  WHERE id = p_report_id AND status = 'pending'
  RETURNING reported_user_id INTO v_target;
  IF v_target IS NULL THEN
    RAISE EXCEPTION 'message_report_not_pending' USING ERRCODE = 'P0001';
  END IF;

  IF v_action = 'actioned' THEN
    UPDATE public.users
    SET messaging_suspended_until = greatest(
      coalesce(messaging_suspended_until, now()),
      now() + interval '7 days'
    )
    WHERE id = v_target;
  END IF;

  DELETE FROM public.admin_work_locks
  WHERE item_type = 'message_report' AND item_id = p_report_id;
  INSERT INTO public.admin_audit_log(
    admin_id, actor_role, action_type, target_user_id, details
  ) VALUES (
    auth.uid(), public.current_admin_role(),
    'message_report_' || v_action, v_target,
    jsonb_build_object(
      'report_id', p_report_id,
      'messaging_restricted_days', CASE WHEN v_action = 'actioned' THEN 7 ELSE 0 END
    )
  );
END;
$$;

REVOKE ALL ON FUNCTION public.admin_discovery_eligibility(text, integer)
  FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.admin_resolve_report(uuid, text)
  FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.admin_resolve_message_report(uuid, text)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_discovery_eligibility(text, integer)
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_resolve_report(uuid, text)
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_resolve_message_report(uuid, text)
  TO authenticated;

COMMENT ON FUNCTION public.admin_discovery_eligibility(text, integer) IS
  'Auditable staff diagnostic explaining base discovery eligibility for recent or searched profiles.';
