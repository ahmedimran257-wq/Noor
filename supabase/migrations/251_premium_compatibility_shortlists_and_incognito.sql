-- Premium relationship tools with server-enforced privacy and bounded cost.
--
--  * Compatibility is calculated only on an explicit profile-detail request.
--    The RPC returns explanations, never another member's raw preferences.
--  * Existing bookmarks remain free. Premium adds private organization,
--    private notes, and one-shot reminders without duplicating profile data.
--  * Incognito eligibility is enforced in every member/profile projection.
--    A compact entitlement projection avoids has_active_premium() per card.

-- ---------------------------------------------------------------------------
-- 1. Private shortlist metadata. A bookmark remains the source of truth.
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS private.premium_shortlist_details (
  user_id uuid NOT NULL,
  saved_user_id uuid NOT NULL,
  list_key text NOT NULL DEFAULT 'saved' CHECK (
    list_key IN ('saved', 'strong_match', 'discuss_with_family', 'follow_up')
  ),
  private_note text,
  remind_at timestamptz,
  reminder_sent_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, saved_user_id),
  CONSTRAINT premium_shortlist_bookmark_fk
    FOREIGN KEY (user_id, saved_user_id)
    REFERENCES public.profile_bookmarks(user_id, saved_user_id)
    ON DELETE CASCADE,
  CONSTRAINT premium_shortlist_note_length CHECK (
    private_note IS NULL OR char_length(private_note) <= 1000
  )
);

CREATE INDEX IF NOT EXISTS idx_premium_shortlist_details_user_updated
  ON private.premium_shortlist_details(user_id, updated_at DESC);
CREATE INDEX IF NOT EXISTS idx_premium_shortlist_details_due
  ON private.premium_shortlist_details(remind_at, user_id)
  WHERE remind_at IS NOT NULL AND reminder_sent_at IS NULL;

REVOKE ALL ON TABLE private.premium_shortlist_details
  FROM PUBLIC, anon, authenticated, service_role;

CREATE OR REPLACE FUNCTION private.enforce_member_feature_rate_limit(
  p_scope text,
  p_user_id uuid,
  p_max_requests integer,
  p_window_seconds integer
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_allowed boolean;
BEGIN
  SELECT limit_result.allowed
  INTO v_allowed
  FROM public.consume_edge_rate_limit(
    p_scope,
    p_user_id::text,
    p_max_requests,
    p_window_seconds
  ) AS limit_result;

  IF NOT coalesce(v_allowed, false) THEN
    RAISE EXCEPTION 'rate_limit_exceeded' USING ERRCODE = 'P0001';
  END IF;
END;
$$;

REVOKE ALL ON FUNCTION private.enforce_member_feature_rate_limit(
  text, uuid, integer, integer
) FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.get_my_premium_shortlist_details()
RETURNS SETOF jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_user_id uuid := private.assert_authenticated();
BEGIN
  IF NOT public.has_active_premium(v_user_id) THEN
    RAISE EXCEPTION 'premium_required' USING ERRCODE = 'P0001';
  END IF;

  RETURN QUERY
  SELECT jsonb_build_object(
    'saved_user_id', details.saved_user_id,
    'list_key', details.list_key,
    'private_note', details.private_note,
    'remind_at', details.remind_at,
    'reminder_sent_at', details.reminder_sent_at,
    'created_at', details.created_at,
    'updated_at', details.updated_at
  )
  FROM private.premium_shortlist_details details
  WHERE details.user_id = v_user_id
  ORDER BY details.updated_at DESC, details.saved_user_id
  LIMIT 50;
END;
$$;

REVOKE ALL ON FUNCTION public.get_my_premium_shortlist_details()
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_my_premium_shortlist_details()
  TO authenticated;

CREATE OR REPLACE FUNCTION public.save_my_premium_shortlist_detail(
  p_saved_user_id uuid,
  p_list_key text DEFAULT 'saved',
  p_private_note text DEFAULT NULL,
  p_remind_at timestamptz DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_user_id uuid := private.assert_authenticated();
  v_list_key text := lower(trim(coalesce(p_list_key, 'saved')));
  v_note text := nullif(trim(coalesce(p_private_note, '')), '');
  v_result private.premium_shortlist_details%rowtype;
BEGIN
  IF NOT public.has_active_premium(v_user_id) THEN
    RAISE EXCEPTION 'premium_required' USING ERRCODE = 'P0001';
  END IF;
  PERFORM private.enforce_member_feature_rate_limit(
    'premium_shortlist_write', v_user_id, 120, 3600
  );

  IF p_saved_user_id IS NULL OR p_saved_user_id = v_user_id THEN
    RAISE EXCEPTION 'invalid_saved_profile' USING ERRCODE = '22023';
  END IF;
  IF v_list_key NOT IN (
    'saved', 'strong_match', 'discuss_with_family', 'follow_up'
  ) THEN
    RAISE EXCEPTION 'invalid_shortlist_category' USING ERRCODE = '22023';
  END IF;
  IF char_length(coalesce(v_note, '')) > 1000 THEN
    RAISE EXCEPTION 'shortlist_note_too_long' USING ERRCODE = '22023';
  END IF;
  IF p_remind_at IS NOT NULL AND (
    p_remind_at <= now() OR p_remind_at > now() + interval '365 days'
  ) THEN
    RAISE EXCEPTION 'invalid_shortlist_reminder' USING ERRCODE = '22023';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.profile_bookmarks bookmark
    WHERE bookmark.user_id = v_user_id
      AND bookmark.saved_user_id = p_saved_user_id
  ) THEN
    RAISE EXCEPTION 'bookmark_required' USING ERRCODE = 'P0001';
  END IF;
  IF NOT EXISTS (
    SELECT 1
    FROM private.premium_shortlist_details details
    WHERE details.user_id = v_user_id
      AND details.saved_user_id = p_saved_user_id
  ) AND (
    SELECT count(*)
    FROM private.premium_shortlist_details details
    WHERE details.user_id = v_user_id
  ) >= 50 THEN
    RAISE EXCEPTION 'shortlist_limit_reached' USING ERRCODE = 'P0001';
  END IF;

  INSERT INTO private.premium_shortlist_details AS details (
    user_id,
    saved_user_id,
    list_key,
    private_note,
    remind_at,
    reminder_sent_at,
    updated_at
  ) VALUES (
    v_user_id,
    p_saved_user_id,
    v_list_key,
    v_note,
    p_remind_at,
    NULL,
    now()
  )
  ON CONFLICT (user_id, saved_user_id) DO UPDATE SET
    list_key = EXCLUDED.list_key,
    private_note = EXCLUDED.private_note,
    remind_at = EXCLUDED.remind_at,
    reminder_sent_at = CASE
      WHEN details.remind_at IS DISTINCT FROM EXCLUDED.remind_at THEN NULL
      ELSE details.reminder_sent_at
    END,
    updated_at = now()
  RETURNING * INTO v_result;

  RETURN jsonb_build_object(
    'saved_user_id', v_result.saved_user_id,
    'list_key', v_result.list_key,
    'private_note', v_result.private_note,
    'remind_at', v_result.remind_at,
    'reminder_sent_at', v_result.reminder_sent_at,
    'created_at', v_result.created_at,
    'updated_at', v_result.updated_at
  );
END;
$$;

REVOKE ALL ON FUNCTION public.save_my_premium_shortlist_detail(
  uuid, text, text, timestamptz
) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.save_my_premium_shortlist_detail(
  uuid, text, text, timestamptz
) TO authenticated;

CREATE OR REPLACE FUNCTION public.clear_my_premium_shortlist_detail(
  p_saved_user_id uuid
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_user_id uuid := private.assert_authenticated();
  v_deleted integer;
BEGIN
  IF NOT public.has_active_premium(v_user_id) THEN
    RAISE EXCEPTION 'premium_required' USING ERRCODE = 'P0001';
  END IF;
  PERFORM private.enforce_member_feature_rate_limit(
    'premium_shortlist_write', v_user_id, 120, 3600
  );

  DELETE FROM private.premium_shortlist_details details
  WHERE details.user_id = v_user_id
    AND details.saved_user_id = p_saved_user_id;
  GET DIAGNOSTICS v_deleted = ROW_COUNT;
  RETURN v_deleted > 0;
END;
$$;

REVOKE ALL ON FUNCTION public.clear_my_premium_shortlist_detail(uuid)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.clear_my_premium_shortlist_detail(uuid)
  TO authenticated;

-- ---------------------------------------------------------------------------
-- 2. Incognito entitlement projection and privacy boundary.
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS private.premium_privacy_settings (
  user_id uuid PRIMARY KEY REFERENCES public.users(id) ON DELETE CASCADE,
  incognito_requested boolean NOT NULL DEFAULT false,
  entitlement_active boolean NOT NULL DEFAULT false,
  entitlement_expires_at timestamptz,
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_premium_privacy_incognito_expiry
  ON private.premium_privacy_settings(entitlement_expires_at, user_id)
  WHERE incognito_requested = true AND entitlement_active = true
    AND entitlement_expires_at IS NOT NULL;

REVOKE ALL ON TABLE private.premium_privacy_settings
  FROM PUBLIC, anon, authenticated, service_role;

CREATE OR REPLACE FUNCTION private.current_premium_expiry(p_user_id uuid)
RETURNS timestamptz
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_paid_lifetime boolean := false;
  v_paid_expiry timestamptz;
  v_promo_expiry timestamptz;
  v_test_expiry timestamptz;
BEGIN
  SELECT
    u.subscription_status IN ('active', 'grace')
      AND u.subscription_expires_at IS NULL,
    CASE
      WHEN u.subscription_status IN ('active', 'grace')
        AND u.subscription_expires_at > now()
      THEN u.subscription_expires_at
      ELSE NULL
    END
  INTO v_paid_lifetime, v_paid_expiry
  FROM public.users u
  WHERE u.id = p_user_id;

  IF coalesce(v_paid_lifetime, false) THEN
    RETURN NULL;
  END IF;

  SELECT max(grant_row.expires_at)
  INTO v_promo_expiry
  FROM public.promotional_premium_grants grant_row
  WHERE grant_row.user_id = p_user_id
    AND grant_row.starts_at <= now()
    AND grant_row.expires_at > now();

  IF to_regclass('private.test_premium_grants') IS NOT NULL THEN
    SELECT max(test_grant.expires_at)
    INTO v_test_expiry
    FROM private.test_premium_grants test_grant
    WHERE test_grant.user_id = p_user_id
      AND test_grant.revoked_at IS NULL
      AND test_grant.starts_at <= now()
      AND test_grant.expires_at > now();
  END IF;

  RETURN greatest(v_paid_expiry, v_promo_expiry, v_test_expiry);
END;
$$;

REVOKE ALL ON FUNCTION private.current_premium_expiry(uuid)
  FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION private.incognito_effective(
  p_requested boolean,
  p_entitlement_active boolean,
  p_entitlement_expires_at timestamptz
)
RETURNS boolean
LANGUAGE sql
STABLE
SET search_path = ''
AS $$
  SELECT coalesce(p_requested, false)
    AND coalesce(p_entitlement_active, false)
    AND (
      p_entitlement_expires_at IS NULL
      OR p_entitlement_expires_at > now()
    );
$$;

REVOKE ALL ON FUNCTION private.incognito_effective(
  boolean, boolean, timestamptz
) FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION private.touch_member_discovery_segment(
  p_user_id uuid
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_gender text;
  v_country text;
BEGIN
  SELECT p.gender::text, p.country_code::text
  INTO v_gender, v_country
  FROM public.profiles p
  WHERE p.user_id = p_user_id;

  IF v_gender IS NOT NULL THEN
    PERFORM private.touch_discovery_catalog_segment(v_gender, v_country);
  END IF;
END;
$$;

REVOKE ALL ON FUNCTION private.touch_member_discovery_segment(uuid)
  FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION private.sync_incognito_entitlement(p_user_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_old_effective boolean;
  v_new_effective boolean;
  v_active boolean := public.has_active_premium(p_user_id);
  v_expiry timestamptz;
BEGIN
  SELECT private.incognito_effective(
    settings.incognito_requested,
    settings.entitlement_active,
    settings.entitlement_expires_at
  )
  INTO v_old_effective
  FROM private.premium_privacy_settings settings
  WHERE settings.user_id = p_user_id;

  IF NOT FOUND THEN
    RETURN;
  END IF;

  IF v_active THEN
    v_expiry := private.current_premium_expiry(p_user_id);
  ELSE
    v_expiry := now();
  END IF;

  UPDATE private.premium_privacy_settings settings
  SET entitlement_active = v_active,
      entitlement_expires_at = v_expiry,
      updated_at = now()
  WHERE settings.user_id = p_user_id
  RETURNING private.incognito_effective(
    settings.incognito_requested,
    settings.entitlement_active,
    settings.entitlement_expires_at
  ) INTO v_new_effective;

  IF coalesce(v_old_effective, false) IS DISTINCT FROM
     coalesce(v_new_effective, false) THEN
    PERFORM private.touch_member_discovery_segment(p_user_id);
  END IF;
END;
$$;

REVOKE ALL ON FUNCTION private.sync_incognito_entitlement(uuid)
  FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION private.sync_incognito_entitlement_trigger()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  PERFORM private.sync_incognito_entitlement(
    CASE WHEN TG_OP = 'DELETE' THEN OLD.user_id ELSE NEW.user_id END
  );
  IF TG_OP = 'DELETE' THEN
    RETURN OLD;
  END IF;
  RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION private.sync_incognito_entitlement_trigger()
  FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS trg_sync_incognito_subscription ON public.users;
CREATE TRIGGER trg_sync_incognito_subscription
AFTER UPDATE OF subscription_status, subscription_expires_at ON public.users
FOR EACH ROW
WHEN (
  OLD.subscription_status IS DISTINCT FROM NEW.subscription_status
  OR OLD.subscription_expires_at IS DISTINCT FROM NEW.subscription_expires_at
)
EXECUTE FUNCTION private.sync_incognito_entitlement_trigger();

DROP TRIGGER IF EXISTS trg_sync_incognito_promotional_grant
  ON public.promotional_premium_grants;
CREATE TRIGGER trg_sync_incognito_promotional_grant
AFTER INSERT OR UPDATE OR DELETE ON public.promotional_premium_grants
FOR EACH ROW
EXECUTE FUNCTION private.sync_incognito_entitlement_trigger();

DO $migration$
BEGIN
  IF to_regclass('private.test_premium_grants') IS NOT NULL THEN
    EXECUTE 'DROP TRIGGER IF EXISTS trg_sync_incognito_test_grant '
      'ON private.test_premium_grants';
    EXECUTE 'CREATE TRIGGER trg_sync_incognito_test_grant '
      'AFTER INSERT OR UPDATE OR DELETE ON private.test_premium_grants '
      'FOR EACH ROW EXECUTE FUNCTION '
      'private.sync_incognito_entitlement_trigger()';
  END IF;
END;
$migration$;

CREATE OR REPLACE FUNCTION private.can_access_incognito_profile(
  p_viewer_user_id uuid,
  p_candidate_user_id uuid
)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT
    p_viewer_user_id IS NOT NULL
    AND p_candidate_user_id IS NOT NULL
    AND (
      p_viewer_user_id = p_candidate_user_id
      OR NOT EXISTS (
        SELECT 1
        FROM private.premium_privacy_settings settings
        WHERE settings.user_id = p_candidate_user_id
          AND private.incognito_effective(
            settings.incognito_requested,
            settings.entitlement_active,
            settings.entitlement_expires_at
          )
      )
      OR EXISTS (
        SELECT 1 FROM public.interests interest_row
        WHERE (interest_row.sender_id = p_viewer_user_id
               AND interest_row.receiver_id = p_candidate_user_id)
           OR (interest_row.sender_id = p_candidate_user_id
               AND interest_row.receiver_id = p_viewer_user_id)
      )
      OR EXISTS (
        SELECT 1 FROM public.matches match_row
        WHERE (match_row.user_a = p_viewer_user_id
               AND match_row.user_b = p_candidate_user_id)
           OR (match_row.user_a = p_candidate_user_id
               AND match_row.user_b = p_viewer_user_id)
      )
      OR EXISTS (
        SELECT 1 FROM public.photo_access_requests photo_request
        WHERE photo_request.requester_id = p_viewer_user_id
          AND photo_request.owner_id = p_candidate_user_id
          AND photo_request.status IN ('pending', 'granted')
      )
      OR EXISTS (
        SELECT 1 FROM public.profiles ward
        WHERE ward.user_id = p_candidate_user_id
          AND ward.guardian_user_id = p_viewer_user_id
      )
      OR EXISTS (
        SELECT 1
        FROM public.guardian_chat_mirrors mirror
        JOIN public.matches guarded_match ON guarded_match.id = mirror.match_id
        WHERE mirror.guardian_id = p_viewer_user_id
          AND (
            mirror.ward_id = p_candidate_user_id
            OR (guarded_match.user_a = mirror.ward_id
                AND guarded_match.user_b = p_candidate_user_id)
            OR (guarded_match.user_b = mirror.ward_id
                AND guarded_match.user_a = p_candidate_user_id)
          )
      )
    );
$$;

REVOKE ALL ON FUNCTION private.can_access_incognito_profile(uuid, uuid)
  FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.get_my_incognito_setting()
RETURNS TABLE(
  requested boolean,
  enabled boolean,
  can_enable boolean,
  effective_until timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_user_id uuid := private.assert_authenticated();
  v_requested boolean := false;
  v_entitlement_active boolean := false;
  v_entitlement_expires_at timestamptz;
  v_can_enable boolean := public.has_active_premium(v_user_id);
BEGIN
  SELECT settings.incognito_requested,
         settings.entitlement_active,
         settings.entitlement_expires_at
  INTO v_requested, v_entitlement_active, v_entitlement_expires_at
  FROM private.premium_privacy_settings settings
  WHERE settings.user_id = v_user_id;

  requested := coalesce(v_requested, false);
  can_enable := v_can_enable;
  enabled := requested
    AND v_can_enable
    AND coalesce(v_entitlement_active, false)
    AND (
      v_entitlement_expires_at IS NULL
      OR v_entitlement_expires_at > now()
    );
  effective_until := CASE WHEN enabled THEN v_entitlement_expires_at END;
  RETURN NEXT;
END;
$$;

REVOKE ALL ON FUNCTION public.get_my_incognito_setting()
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_my_incognito_setting()
  TO authenticated;

CREATE OR REPLACE FUNCTION public.set_my_incognito(p_enabled boolean)
RETURNS TABLE(
  requested boolean,
  enabled boolean,
  can_enable boolean,
  effective_until timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_user_id uuid := private.assert_authenticated();
  v_can_enable boolean := public.has_active_premium(v_user_id);
  v_expiry timestamptz;
  v_old_effective boolean := false;
  v_new_effective boolean := false;
BEGIN
  PERFORM private.enforce_member_feature_rate_limit(
    'premium_incognito_write', v_user_id, 20, 3600
  );
  IF coalesce(p_enabled, false) AND NOT v_can_enable THEN
    RAISE EXCEPTION 'premium_required' USING ERRCODE = 'P0001';
  END IF;
  IF v_can_enable THEN
    v_expiry := private.current_premium_expiry(v_user_id);
  ELSE
    v_expiry := now();
  END IF;

  SELECT private.incognito_effective(
    settings.incognito_requested,
    settings.entitlement_active,
    settings.entitlement_expires_at
  )
  INTO v_old_effective
  FROM private.premium_privacy_settings settings
  WHERE settings.user_id = v_user_id;

  INSERT INTO private.premium_privacy_settings AS settings (
    user_id,
    incognito_requested,
    entitlement_active,
    entitlement_expires_at,
    updated_at
  ) VALUES (
    v_user_id,
    coalesce(p_enabled, false),
    v_can_enable,
    v_expiry,
    now()
  )
  ON CONFLICT (user_id) DO UPDATE SET
    incognito_requested = EXCLUDED.incognito_requested,
    entitlement_active = EXCLUDED.entitlement_active,
    entitlement_expires_at = EXCLUDED.entitlement_expires_at,
    updated_at = now()
  RETURNING private.incognito_effective(
    settings.incognito_requested,
    settings.entitlement_active,
    settings.entitlement_expires_at
  ) INTO v_new_effective;

  IF coalesce(v_old_effective, false) IS DISTINCT FROM v_new_effective THEN
    PERFORM private.touch_member_discovery_segment(v_user_id);
  END IF;

  requested := coalesce(p_enabled, false);
  enabled := v_new_effective;
  can_enable := v_can_enable;
  effective_until := CASE WHEN enabled THEN v_expiry END;
  RETURN NEXT;
END;
$$;

REVOKE ALL ON FUNCTION public.set_my_incognito(boolean)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.set_my_incognito(boolean)
  TO authenticated;

-- ---------------------------------------------------------------------------
-- 3. Explainable, mutual compatibility. No raw preference values are returned.
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.get_premium_compatibility_insight(
  p_candidate_user_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_user_id uuid := private.assert_authenticated();
  v_viewer_profile_id uuid;
  v_candidate_profile_id uuid;
  v_result jsonb;
BEGIN
  IF NOT public.has_active_premium(v_user_id) THEN
    RAISE EXCEPTION 'premium_required' USING ERRCODE = 'P0001';
  END IF;
  IF p_candidate_user_id IS NULL OR p_candidate_user_id = v_user_id THEN
    RAISE EXCEPTION 'profile_unavailable' USING ERRCODE = 'P0001';
  END IF;
  IF NOT private.can_access_incognito_profile(
    v_user_id, p_candidate_user_id
  ) THEN
    RAISE EXCEPTION 'profile_unavailable' USING ERRCODE = 'P0001';
  END IF;
  IF EXISTS (
    SELECT 1 FROM public.blocks block_row
    WHERE (block_row.blocker_id = v_user_id
           AND block_row.blocked_id = p_candidate_user_id)
       OR (block_row.blocker_id = p_candidate_user_id
           AND block_row.blocked_id = v_user_id)
  ) OR EXISTS (
    SELECT 1 FROM public.reports report_row
    WHERE report_row.reporter_id = v_user_id
      AND report_row.reported_user_id = p_candidate_user_id
  ) THEN
    RAISE EXCEPTION 'profile_unavailable' USING ERRCODE = 'P0001';
  END IF;

  SELECT viewer.id, candidate.id
  INTO v_viewer_profile_id, v_candidate_profile_id
  FROM public.profiles viewer
  CROSS JOIN public.profiles candidate
  JOIN public.users candidate_account ON candidate_account.id = candidate.user_id
  WHERE viewer.user_id = v_user_id
    AND candidate.user_id = p_candidate_user_id
    AND candidate_account.deleted_at IS NULL
    AND coalesce(candidate_account.is_banned, false) = false
    AND (
      EXISTS (
        SELECT 1 FROM public.live_discovery_pool pool
        WHERE pool.user_id = candidate.user_id
      )
      OR EXISTS (
        SELECT 1 FROM public.interests interest_row
        WHERE (interest_row.sender_id = v_user_id
               AND interest_row.receiver_id = p_candidate_user_id)
           OR (interest_row.sender_id = p_candidate_user_id
               AND interest_row.receiver_id = v_user_id)
      )
      OR EXISTS (
        SELECT 1 FROM public.matches match_row
        WHERE (match_row.user_a = v_user_id
               AND match_row.user_b = p_candidate_user_id)
           OR (match_row.user_a = p_candidate_user_id
               AND match_row.user_b = v_user_id)
      )
      OR EXISTS (
        SELECT 1 FROM public.profile_bookmarks bookmark
        WHERE bookmark.user_id = v_user_id
          AND bookmark.saved_user_id = p_candidate_user_id
      )
    )
  LIMIT 1;

  IF v_viewer_profile_id IS NULL OR v_candidate_profile_id IS NULL THEN
    RAISE EXCEPTION 'profile_unavailable' USING ERRCODE = 'P0001';
  END IF;

  WITH directions AS (
    SELECT
      'age'::text AS criterion_key,
      prefs.preferred_age_min IS NOT NULL
        AND prefs.preferred_age_max IS NOT NULL AS specified,
      extract(year FROM age(candidate.date_of_birth))
        BETWEEN prefs.preferred_age_min AND prefs.preferred_age_max AS matched
    FROM public.profiles seeker
    JOIN public.profile_preferences prefs ON prefs.profile_id = seeker.id
    JOIN public.profiles candidate ON candidate.id = v_candidate_profile_id
    WHERE seeker.id = v_viewer_profile_id
    UNION ALL
    SELECT 'age',
      prefs.preferred_age_min IS NOT NULL
        AND prefs.preferred_age_max IS NOT NULL,
      extract(year FROM age(candidate.date_of_birth))
        BETWEEN prefs.preferred_age_min AND prefs.preferred_age_max
    FROM public.profiles seeker
    JOIN public.profile_preferences prefs ON prefs.profile_id = seeker.id
    JOIN public.profiles candidate ON candidate.id = v_viewer_profile_id
    WHERE seeker.id = v_candidate_profile_id
    UNION ALL
    SELECT 'sect',
      coalesce(nullif(lower(trim(prefs.sect_preference)), ''), 'any')
        NOT IN ('any', 'no preference', 'no_preference'),
      CASE
        WHEN replace(lower(trim(prefs.sect_preference)), '_', ' ')
          = 'same as mine' THEN
          lower(coalesce(candidate.sect::text, '')) =
            lower(coalesce(seeker.sect::text, ''))
        ELSE lower(coalesce(candidate.sect::text, '')) =
          lower(coalesce(prefs.sect_preference, ''))
      END
    FROM public.profiles seeker
    JOIN public.profile_preferences prefs ON prefs.profile_id = seeker.id
    JOIN public.profiles candidate ON candidate.id = v_candidate_profile_id
    WHERE seeker.id = v_viewer_profile_id
    UNION ALL
    SELECT 'sect',
      coalesce(nullif(lower(trim(prefs.sect_preference)), ''), 'any')
        NOT IN ('any', 'no preference', 'no_preference'),
      CASE
        WHEN replace(lower(trim(prefs.sect_preference)), '_', ' ')
          = 'same as mine' THEN
          lower(coalesce(candidate.sect::text, '')) =
            lower(coalesce(seeker.sect::text, ''))
        ELSE lower(coalesce(candidate.sect::text, '')) =
          lower(coalesce(prefs.sect_preference, ''))
      END
    FROM public.profiles seeker
    JOIN public.profile_preferences prefs ON prefs.profile_id = seeker.id
    JOIN public.profiles candidate ON candidate.id = v_viewer_profile_id
    WHERE seeker.id = v_candidate_profile_id
    UNION ALL
    SELECT 'deen',
      coalesce(nullif(lower(trim(prefs.deen_preference)), ''), 'any')
        NOT IN ('any', 'no preference', 'no_preference'),
      CASE
        WHEN replace(lower(trim(prefs.deen_preference)), '_', ' ')
          = 'same as mine' THEN
          lower(coalesce(candidate.deen_level::text, '')) =
            lower(coalesce(seeker.deen_level::text, ''))
        ELSE lower(coalesce(candidate.deen_level::text, '')) =
          lower(coalesce(prefs.deen_preference, ''))
      END
    FROM public.profiles seeker
    JOIN public.profile_preferences prefs ON prefs.profile_id = seeker.id
    JOIN public.profiles candidate ON candidate.id = v_candidate_profile_id
    WHERE seeker.id = v_viewer_profile_id
    UNION ALL
    SELECT 'deen',
      coalesce(nullif(lower(trim(prefs.deen_preference)), ''), 'any')
        NOT IN ('any', 'no preference', 'no_preference'),
      CASE
        WHEN replace(lower(trim(prefs.deen_preference)), '_', ' ')
          = 'same as mine' THEN
          lower(coalesce(candidate.deen_level::text, '')) =
            lower(coalesce(seeker.deen_level::text, ''))
        ELSE lower(coalesce(candidate.deen_level::text, '')) =
          lower(coalesce(prefs.deen_preference, ''))
      END
    FROM public.profiles seeker
    JOIN public.profile_preferences prefs ON prefs.profile_id = seeker.id
    JOIN public.profiles candidate ON candidate.id = v_viewer_profile_id
    WHERE seeker.id = v_candidate_profile_id
    UNION ALL
    SELECT 'education', prefs.min_education_rank IS NOT NULL
      AND prefs.min_education_rank > 1,
      coalesce(candidate.education_rank, 0) >= prefs.min_education_rank
    FROM public.profile_preferences prefs
    JOIN public.profiles candidate ON candidate.id = v_candidate_profile_id
    WHERE prefs.profile_id = v_viewer_profile_id
    UNION ALL
    SELECT 'education', prefs.min_education_rank IS NOT NULL
      AND prefs.min_education_rank > 1,
      coalesce(candidate.education_rank, 0) >= prefs.min_education_rank
    FROM public.profile_preferences prefs
    JOIN public.profiles candidate ON candidate.id = v_viewer_profile_id
    WHERE prefs.profile_id = v_candidate_profile_id
    UNION ALL
    SELECT 'mother_tongue', cardinality(prefs.preferred_mother_tongue) > 0,
      candidate.mother_tongue = ANY(prefs.preferred_mother_tongue)
    FROM public.profile_preferences prefs
    JOIN public.profiles candidate ON candidate.id = v_candidate_profile_id
    WHERE prefs.profile_id = v_viewer_profile_id
    UNION ALL
    SELECT 'mother_tongue', cardinality(prefs.preferred_mother_tongue) > 0,
      candidate.mother_tongue = ANY(prefs.preferred_mother_tongue)
    FROM public.profile_preferences prefs
    JOIN public.profiles candidate ON candidate.id = v_viewer_profile_id
    WHERE prefs.profile_id = v_candidate_profile_id
    UNION ALL
    SELECT 'community', cardinality(prefs.preferred_community) > 0,
      candidate.community = ANY(prefs.preferred_community)
    FROM public.profile_preferences prefs
    JOIN public.profiles candidate ON candidate.id = v_candidate_profile_id
    WHERE prefs.profile_id = v_viewer_profile_id
    UNION ALL
    SELECT 'community', cardinality(prefs.preferred_community) > 0,
      candidate.community = ANY(prefs.preferred_community)
    FROM public.profile_preferences prefs
    JOIN public.profiles candidate ON candidate.id = v_viewer_profile_id
    WHERE prefs.profile_id = v_candidate_profile_id
    UNION ALL
    SELECT 'height',
      prefs.preferred_height_min IS NOT NULL
        OR prefs.preferred_height_max IS NOT NULL,
      (prefs.preferred_height_min IS NULL
        OR candidate.height_cm >= prefs.preferred_height_min)
      AND (prefs.preferred_height_max IS NULL
        OR candidate.height_cm <= prefs.preferred_height_max)
    FROM public.profile_preferences prefs
    JOIN public.profiles candidate ON candidate.id = v_candidate_profile_id
    WHERE prefs.profile_id = v_viewer_profile_id
    UNION ALL
    SELECT 'height',
      prefs.preferred_height_min IS NOT NULL
        OR prefs.preferred_height_max IS NOT NULL,
      (prefs.preferred_height_min IS NULL
        OR candidate.height_cm >= prefs.preferred_height_min)
      AND (prefs.preferred_height_max IS NULL
        OR candidate.height_cm <= prefs.preferred_height_max)
    FROM public.profile_preferences prefs
    JOIN public.profiles candidate ON candidate.id = v_viewer_profile_id
    WHERE prefs.profile_id = v_candidate_profile_id
    UNION ALL
    SELECT 'marriage_timeline',
      coalesce(prefs.preferred_marriage_timeline, 'no_preference')
        <> 'no_preference',
      candidate.marriage_timeline = prefs.preferred_marriage_timeline
    FROM public.profile_preferences prefs
    JOIN public.profiles candidate ON candidate.id = v_candidate_profile_id
    WHERE prefs.profile_id = v_viewer_profile_id
    UNION ALL
    SELECT 'marriage_timeline',
      coalesce(prefs.preferred_marriage_timeline, 'no_preference')
        <> 'no_preference',
      candidate.marriage_timeline = prefs.preferred_marriage_timeline
    FROM public.profile_preferences prefs
    JOIN public.profiles candidate ON candidate.id = v_viewer_profile_id
    WHERE prefs.profile_id = v_candidate_profile_id
    UNION ALL
    SELECT 'relocation',
      coalesce(prefs.preferred_relocation, 'no_preference')
        <> 'no_preference',
      candidate.willing_to_relocate = prefs.preferred_relocation
    FROM public.profile_preferences prefs
    JOIN public.profiles candidate ON candidate.id = v_candidate_profile_id
    WHERE prefs.profile_id = v_viewer_profile_id
    UNION ALL
    SELECT 'relocation',
      coalesce(prefs.preferred_relocation, 'no_preference')
        <> 'no_preference',
      candidate.willing_to_relocate = prefs.preferred_relocation
    FROM public.profile_preferences prefs
    JOIN public.profiles candidate ON candidate.id = v_viewer_profile_id
    WHERE prefs.profile_id = v_candidate_profile_id
    UNION ALL
    SELECT 'living_expectation',
      coalesce(prefs.preferred_living_expectation, 'no_preference')
        <> 'no_preference',
      candidate.living_expectation = prefs.preferred_living_expectation
    FROM public.profile_preferences prefs
    JOIN public.profiles candidate ON candidate.id = v_candidate_profile_id
    WHERE prefs.profile_id = v_viewer_profile_id
    UNION ALL
    SELECT 'living_expectation',
      coalesce(prefs.preferred_living_expectation, 'no_preference')
        <> 'no_preference',
      candidate.living_expectation = prefs.preferred_living_expectation
    FROM public.profile_preferences prefs
    JOIN public.profiles candidate ON candidate.id = v_viewer_profile_id
    WHERE prefs.profile_id = v_candidate_profile_id
  ), summarized AS (
    SELECT
      criterion_key,
      count(*) FILTER (WHERE specified)::integer AS total_count,
      count(*) FILTER (WHERE specified AND matched)::integer AS matched_count
    FROM directions
    GROUP BY criterion_key
  ), visible AS (
    SELECT * FROM summarized WHERE total_count > 0
  )
  SELECT jsonb_build_object(
    'matched_count', coalesce(sum(matched_count), 0),
    'total_count', coalesce(sum(total_count), 0),
    'criteria', coalesce(jsonb_agg(
      jsonb_build_object(
        'key', criterion_key,
        'matched_count', matched_count,
        'total_count', total_count,
        'status', CASE
          WHEN matched_count = total_count THEN 'aligned'
          WHEN matched_count > 0 THEN 'partial'
          ELSE 'not_aligned'
        END
      ) ORDER BY CASE criterion_key
        WHEN 'age' THEN 1 WHEN 'sect' THEN 2 WHEN 'deen' THEN 3
        WHEN 'education' THEN 4 WHEN 'mother_tongue' THEN 5
        WHEN 'community' THEN 6 WHEN 'height' THEN 7
        WHEN 'marriage_timeline' THEN 8 WHEN 'relocation' THEN 9
        ELSE 10 END
    ), '[]'::jsonb),
    'disclaimer',
      'Compatibility reflects stated preferences only. It is not a safety, character, or marriage-outcome guarantee.'
  )
  INTO v_result
  FROM visible;

  RETURN coalesce(v_result, jsonb_build_object(
    'matched_count', 0,
    'total_count', 0,
    'criteria', '[]'::jsonb,
    'disclaimer',
      'Compatibility reflects stated preferences only. It is not a safety, character, or marriage-outcome guarantee.'
  ));
END;
$$;

REVOKE ALL ON FUNCTION public.get_premium_compatibility_insight(uuid)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_premium_compatibility_insight(uuid)
  TO authenticated;

-- ---------------------------------------------------------------------------
-- 4. Enforce Incognito in all profile, photo, discovery, search and action RPCs.
-- ---------------------------------------------------------------------------

DO $migration$
DECLARE
  v_signature regprocedure;
  v_definition text;
  v_updated text;
  v_anchor text;
  v_replacement text;
BEGIN
  -- Discovery membership and raw age-preference fields.
  v_signature := 'public.get_discovery_feed(uuid,double precision,uuid,integer,jsonb)'::regprocedure;
  SELECT replace(pg_get_functiondef(v_signature), E'\r\n', E'\n') INTO v_definition;
  v_updated := v_definition;
  IF position('private.can_access_incognito_profile(p_viewer_id, dp.user_id)' IN v_updated) = 0 THEN
    v_anchor := '    WHERE dp.user_id <> p_viewer_id';
    v_replacement := v_anchor || E'\n      AND private.can_access_incognito_profile(p_viewer_id, dp.user_id)';
    IF position(v_anchor IN v_updated) = 0 THEN
      RAISE EXCEPTION 'incognito_discovery_anchor_not_found';
    END IF;
    v_updated := replace(v_updated, v_anchor, v_replacement);
  END IF;
  v_anchor := 'r.interests, r.preferred_age_min, r.preferred_age_max,';
  IF position(v_anchor IN v_updated) > 0 THEN
    -- Discovery never needs another member's raw preference values. Premium
    -- explanations come from the dedicated aggregate RPC on profile detail.
    v_replacement := 'r.interests, NULL::integer, NULL::integer,';
    v_updated := replace(v_updated, v_anchor, v_replacement);
  END IF;
  IF position('private.can_access_incognito_profile(p_viewer_id, dp.user_id)' IN v_updated) = 0 THEN
    RAISE EXCEPTION 'incognito_discovery_patch_failed';
  END IF;
  IF position(v_anchor IN v_updated) > 0 THEN
    RAISE EXCEPTION 'premium_discovery_preference_patch_failed';
  END IF;
  IF v_updated IS DISTINCT FROM v_definition THEN EXECUTE v_updated; END IF;

  -- Bounded card relationship context. Raw candidate preferences are Premium-only.
  v_signature := 'public.get_prior_match_context(uuid[])'::regprocedure;
  SELECT replace(pg_get_functiondef(v_signature), E'\r\n', E'\n') INTO v_definition;
  v_updated := v_definition;
  IF position('private.can_access_incognito_profile(v_me, c.candidate_id)' IN v_updated) = 0 THEN
    v_anchor := '  WHERE candidate_profile.visibility = ''visible''';
    v_replacement := v_anchor || E'\n    AND private.can_access_incognito_profile(v_me, c.candidate_id)';
    IF position(v_anchor IN v_updated) = 0 THEN RAISE EXCEPTION 'incognito_context_anchor_not_found'; END IF;
    v_updated := replace(v_updated, v_anchor, v_replacement);
  END IF;
  v_updated := replace(v_updated,
    '    preferences.sect_preference,',
    '    NULL::text,');
  v_updated := replace(v_updated,
    '    preferences.deen_preference,',
    '    NULL::text,');
  v_updated := replace(v_updated,
    '    preferences.min_education_rank',
    '    NULL::integer');
  v_updated := replace(v_updated,
    E'  LEFT JOIN public.profile_preferences preferences\n' ||
      '    ON preferences.profile_id = candidate_profile.id' || E'\n',
    '');
  IF position('preferences.' IN v_updated) > 0 THEN
    RAISE EXCEPTION 'raw_relationship_preference_patch_failed';
  END IF;
  IF v_updated IS DISTINCT FROM v_definition THEN EXECUTE v_updated; END IF;

  -- Batch profile projection.
  v_signature := 'public.get_authorized_member_profiles(uuid[])'::regprocedure;
  SELECT replace(pg_get_functiondef(v_signature), E'\r\n', E'\n') INTO v_definition;
  v_updated := v_definition;
  IF position('private.can_access_incognito_profile(v_me, p.user_id)' IN v_updated) = 0 THEN
    v_anchor := '  WHERE p.user_id = ANY(v_ids)';
    v_replacement := v_anchor || E'\n    AND private.can_access_incognito_profile(v_me, p.user_id)';
    IF position(v_anchor IN v_updated) = 0 THEN RAISE EXCEPTION 'incognito_profile_projection_anchor_not_found'; END IF;
    v_updated := replace(v_updated, v_anchor, v_replacement);
    EXECUTE v_updated;
  END IF;

  -- Batch trust projection.
  v_signature := 'public.get_member_trust_summaries(uuid[])'::regprocedure;
  SELECT replace(pg_get_functiondef(v_signature), E'\r\n', E'\n') INTO v_definition;
  v_updated := v_definition;
  IF position('private.can_access_incognito_profile(v_me, p.user_id)' IN v_updated) = 0 THEN
    v_anchor := '  WHERE p.user_id = ANY(v_ids)';
    v_replacement := v_anchor || E'\n    AND private.can_access_incognito_profile(v_me, p.user_id)';
    IF position(v_anchor IN v_updated) = 0 THEN RAISE EXCEPTION 'incognito_trust_projection_anchor_not_found'; END IF;
    v_updated := replace(v_updated, v_anchor, v_replacement);
    EXECUTE v_updated;
  END IF;

  -- Service-only signed-photo path projection.
  v_signature := 'public.get_authorized_photo_paths(uuid,uuid[],integer)'::regprocedure;
  SELECT replace(pg_get_functiondef(v_signature), E'\r\n', E'\n') INTO v_definition;
  v_updated := v_definition;
  IF position('private.can_access_incognito_profile(p_viewer_user_id, owner.user_id)' IN v_updated) = 0 THEN
    v_anchor := '    AND owner_account.deleted_at IS NULL';
    v_replacement := v_anchor || E'\n    AND private.can_access_incognito_profile(p_viewer_user_id, owner.user_id)';
    IF position(v_anchor IN v_updated) = 0 THEN RAISE EXCEPTION 'incognito_photo_projection_anchor_not_found'; END IF;
    v_updated := replace(v_updated, v_anchor, v_replacement);
    EXECUTE v_updated;
  END IF;

  -- Name/city search.
  v_signature := 'public.search_profiles_by_name_city(uuid,text,integer)'::regprocedure;
  SELECT replace(pg_get_functiondef(v_signature), E'\r\n', E'\n') INTO v_definition;
  v_updated := v_definition;
  IF position('private.can_access_incognito_profile(p_viewer_id, p.user_id)' IN v_updated) = 0 THEN
    v_anchor := '    AND p.user_id <> p_viewer_id';
    v_replacement := v_anchor || E'\n    AND private.can_access_incognito_profile(p_viewer_id, p.user_id)';
    IF position(v_anchor IN v_updated) = 0 THEN RAISE EXCEPTION 'incognito_search_anchor_not_found'; END IF;
    v_updated := replace(v_updated, v_anchor, v_replacement);
    EXECUTE v_updated;
  END IF;

  -- Profile-view recording and its notification side effect.
  v_signature := 'public.record_profile_view(uuid,boolean)'::regprocedure;
  SELECT replace(pg_get_functiondef(v_signature), E'\r\n', E'\n') INTO v_definition;
  v_updated := v_definition;
  IF position('private.can_access_incognito_profile(v_me, p_viewed_user_id)' IN v_updated) = 0 THEN
    v_anchor := $anchor$  SELECT p.id INTO v_viewer_profile_id
  FROM public.profiles p$anchor$;
    v_replacement := $replacement$  IF NOT private.can_access_incognito_profile(v_me, p_viewed_user_id) THEN
    RAISE EXCEPTION 'Profile not found' USING ERRCODE = 'P0001';
  END IF;

  SELECT p.id INTO v_viewer_profile_id
  FROM public.profiles p$replacement$;
    IF position(v_anchor IN v_updated) = 0 THEN RAISE EXCEPTION 'incognito_profile_view_anchor_not_found'; END IF;
    v_updated := replace(v_updated, v_anchor, v_replacement);
    EXECUTE v_updated;
  END IF;

  -- Photo-access request action.
  v_signature := 'public.request_photo_access(uuid)'::regprocedure;
  SELECT replace(pg_get_functiondef(v_signature), E'\r\n', E'\n') INTO v_definition;
  v_updated := v_definition;
  IF position('private.can_access_incognito_profile(v_requester, v_owner)' IN v_updated) = 0 THEN
    v_anchor := $anchor$  IF v_owner IS NULL OR v_owner = v_requester THEN
    RAISE EXCEPTION 'This profile is not accepting photo access requests.';
  END IF;$anchor$;
    v_replacement := v_anchor || E'\n\n  IF NOT private.can_access_incognito_profile(v_requester, v_owner) THEN\n    RAISE EXCEPTION ''This profile is not accepting photo access requests.'';\n  END IF;';
    IF position(v_anchor IN v_updated) = 0 THEN RAISE EXCEPTION 'incognito_photo_request_anchor_not_found'; END IF;
    v_updated := replace(v_updated, v_anchor, v_replacement);
    EXECUTE v_updated;
  END IF;

  -- Interest action: arbitrary UUIDs cannot bypass Incognito.
  v_signature := 'public.send_interest(uuid,text)'::regprocedure;
  SELECT replace(pg_get_functiondef(v_signature), E'\r\n', E'\n') INTO v_definition;
  v_updated := v_definition;
  IF position('private.can_access_incognito_profile(v_sender, p_receiver_id)' IN v_updated) = 0 THEN
    v_anchor := $anchor$  PERFORM pg_advisory_xact_lock($anchor$;
    v_replacement := $replacement$  IF NOT private.can_access_incognito_profile(v_sender, p_receiver_id) THEN
    RAISE EXCEPTION 'profile_unavailable' USING ERRCODE = 'P0001';
  END IF;

  PERFORM pg_advisory_xact_lock($replacement$;
    IF position(v_anchor IN v_updated) = 0 THEN RAISE EXCEPTION 'incognito_interest_anchor_not_found'; END IF;
    v_updated := replace(v_updated, v_anchor, v_replacement);
    EXECUTE v_updated;
  END IF;
END;
$migration$;

-- ---------------------------------------------------------------------------
-- 5. One bounded hourly maintenance job for reminders and timed entitlement
--    expiry. No polling, per-user timers, or per-card background requests.
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION private.process_premium_feature_maintenance(
  p_batch_size integer DEFAULT 200
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_limit integer := greatest(1, least(coalesce(p_batch_size, 200), 500));
  v_row record;
  v_reminders integer := 0;
  v_expired_incognito integer := 0;
BEGIN
  IF NOT pg_try_advisory_xact_lock(hashtext('premium_feature_maintenance')) THEN
    RETURN jsonb_build_object('busy', true, 'reminders', 0, 'incognito_expired', 0);
  END IF;

  FOR v_row IN
    SELECT details.user_id, details.saved_user_id, details.remind_at
    FROM private.premium_shortlist_details details
    WHERE details.remind_at IS NOT NULL
      AND details.reminder_sent_at IS NULL
      AND details.remind_at <= now()
    ORDER BY details.remind_at, details.user_id, details.saved_user_id
    LIMIT v_limit
    FOR UPDATE SKIP LOCKED
  LOOP
    UPDATE private.premium_shortlist_details details
    SET reminder_sent_at = now(), updated_at = now()
    WHERE details.user_id = v_row.user_id
      AND details.saved_user_id = v_row.saved_user_id;

    -- Old reminders are consumed silently instead of surprising a member
    -- after a long device or scheduler outage.
    IF v_row.remind_at > now() - interval '24 hours'
       AND public.has_active_premium(v_row.user_id) THEN
      PERFORM public.queue_notification(
        v_row.user_id,
        'shortlist_reminder',
        'Shortlist reminder',
        'Review a profile you saved for later.',
        'silarah://shortlist'
      );
      v_reminders := v_reminders + 1;
    END IF;
  END LOOP;

  FOR v_row IN
    SELECT settings.user_id
    FROM private.premium_privacy_settings settings
    WHERE settings.incognito_requested = true
      AND settings.entitlement_active = true
      AND settings.entitlement_expires_at IS NOT NULL
      AND settings.entitlement_expires_at <= now()
    ORDER BY settings.entitlement_expires_at, settings.user_id
    LIMIT v_limit
    FOR UPDATE SKIP LOCKED
  LOOP
    UPDATE private.premium_privacy_settings settings
    SET entitlement_active = false, updated_at = now()
    WHERE settings.user_id = v_row.user_id;
    PERFORM private.touch_member_discovery_segment(v_row.user_id);
    v_expired_incognito := v_expired_incognito + 1;
  END LOOP;

  RETURN jsonb_build_object(
    'busy', false,
    'reminders', v_reminders,
    'incognito_expired', v_expired_incognito
  );
END;
$$;

REVOKE ALL ON FUNCTION private.process_premium_feature_maintenance(integer)
  FROM PUBLIC, anon, authenticated;

DO $migration$
DECLARE
  v_job record;
BEGIN
  FOR v_job IN
    SELECT jobid FROM cron.job
    WHERE jobname = 'process_premium_feature_maintenance_hourly'
  LOOP
    PERFORM cron.unschedule(v_job.jobid);
  END LOOP;
END;
$migration$;

SELECT cron.schedule(
  'process_premium_feature_maintenance_hourly',
  '17 * * * *',
  $$SELECT private.process_premium_feature_maintenance(200);$$
);

-- Include member-owned Premium metadata in the existing privacy archive.
DO $migration$
DECLARE
  v_signature regprocedure := 'public.download_my_data(text)'::regprocedure;
  v_definition text;
  v_anchor text := $anchor$    'bookmarks', coalesce((
      SELECT jsonb_agg(to_jsonb(pb) ORDER BY pb.created_at)
      FROM public.profile_bookmarks pb WHERE pb.user_id = v_user_id
    ), '[]'::jsonb),$anchor$;
  v_replacement text := v_anchor || $replacement$
    'private_shortlist_details', coalesce((
      SELECT jsonb_agg(to_jsonb(details) ORDER BY details.updated_at)
      FROM private.premium_shortlist_details details
      WHERE details.user_id = v_user_id
    ), '[]'::jsonb),
    'premium_privacy_settings', coalesce((
      SELECT to_jsonb(settings)
      FROM private.premium_privacy_settings settings
      WHERE settings.user_id = v_user_id
    ), '{}'::jsonb),$replacement$;
BEGIN
  SELECT replace(pg_get_functiondef(v_signature), E'\r\n', E'\n')
  INTO v_definition;
  IF position($needle$'private_shortlist_details'$needle$ IN v_definition) = 0 THEN
    IF position(v_anchor IN v_definition) = 0 THEN
      RAISE EXCEPTION 'premium_export_patch_anchor_not_found';
    END IF;
    EXECUTE replace(v_definition, v_anchor, v_replacement);
  END IF;
END;
$migration$;

COMMENT ON TABLE private.premium_shortlist_details IS
  'Premium-only private category, note and one-shot reminder metadata attached to an existing bookmark.';
COMMENT ON TABLE private.premium_privacy_settings IS
  'Server-only Incognito preference and compact entitlement projection used by discovery authorization.';
COMMENT ON FUNCTION public.get_premium_compatibility_insight(uuid) IS
  'Premium-only mutual stated-preference explanation. Returns aggregate alignment, never raw candidate preference values.';
COMMENT ON FUNCTION public.get_prior_match_context(uuid[]) IS
  'Bounded relationship context for Discovery cards. Legacy preference columns are always null; aggregate compatibility uses its dedicated Premium RPC.';
COMMENT ON FUNCTION private.can_access_incognito_profile(uuid, uuid) IS
  'Central Incognito authorization boundary preserving only self and established relationship access.';
COMMENT ON FUNCTION private.process_premium_feature_maintenance(integer) IS
  'Hourly bounded shortlist reminder and timed Incognito entitlement maintenance.';

NOTIFY pgrst, 'reload schema';
