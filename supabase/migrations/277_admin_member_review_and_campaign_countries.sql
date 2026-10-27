-- Moderators could see a report but not the profile it was about, so a
-- "fake profile" claim could not be checked. admin_member_review() returns what
-- other members see (first name and last initial, never guardian contacts,
-- exact location or tokens) plus the moderation context needed to decide:
-- every photo with its scan result, account restrictions and report history.
-- Each view is an audited read, like admin_reveal_user_pii().
--
-- admin_campaign_countries() feeds the campaign country picker with each
-- country's reachable audience, using the same eligibility as
-- admin_queue_push_campaign().

CREATE OR REPLACE FUNCTION public.admin_member_review(
  p_user_id uuid,
  p_report_id uuid DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_profile_id uuid;
  v_result jsonb;
BEGIN
  IF NOT public.is_active_admin(ARRAY['super_admin', 'moderator']) THEN
    RAISE EXCEPTION 'staff_authorization_required' USING ERRCODE = '42501';
  END IF;

  SELECT p.id INTO v_profile_id
  FROM public.profiles p
  WHERE p.user_id = p_user_id;

  INSERT INTO public.admin_audit_log(admin_id, actor_role, action_type, target_user_id, details)
  VALUES (
    auth.uid(),
    public.current_admin_role(),
    'admin_member_profile_viewed',
    p_user_id,
    jsonb_build_object('report_id', p_report_id, 'profile_found', v_profile_id IS NOT NULL)
  );

  IF v_profile_id IS NULL THEN
    RETURN NULL;
  END IF;

  SELECT jsonb_build_object(
    'userId', u.id,
    'profileId', p.id,
    'displayName', trim(concat_ws(' ', p.first_name, nullif(left(coalesce(p.last_name, ''), 1), '') || '.')),
    'age', CASE WHEN p.date_of_birth IS NULL THEN NULL ELSE date_part('year', age(p.date_of_birth))::int END,
    'gender', p.gender,
    'countryCode', p.country_code,
    'city', city.name,
    'region', region.name,
    'bio', p.bio,
    'profession', p.profession,
    'employmentStatus', p.employment_status,
    'educationLevel', p.education_level,
    'fieldOfStudy', p.field_of_study,
    'sect', p.sect,
    'deenLevel', p.deen_level,
    'praysFiveDaily', p.prays_five_daily,
    'heightCm', p.height_cm,
    'motherTongue', p.mother_tongue,
    'languages', p.languages,
    'interests', p.interests,
    'previouslyMarried', p.previously_married,
    'childrenCount', p.children_count,
    'marriageTimeline', p.marriage_timeline,
    'profileCreatedBy', coalesce(p.profile_creator_relation, p.profile_owner_type::text),
    'guardianMode', p.guardian_mode,
    'visibility', p.visibility,
    'suspendedReason', p.suspended_reason,
    'onboardingCompleted', coalesce(p.onboarding_completed, false),
    'completenessScore', p.completeness_score,
    'approvedAt', p.approved_at,
    'hasVerificationBadge', coalesce(p.has_verification_badge, false),
    'photoVerifiedAt', p.photo_verified_at,
    'lastActiveAt', p.last_active_at,
    'joinedAt', u.created_at,
    'email', public.mask_admin_email(u.email::text),
    'isBanned', coalesce(u.is_banned, false),
    'isShadowbanned', coalesce(u.is_shadowbanned, false),
    'deletedAt', u.deleted_at,
    'subscriptionStatus', u.subscription_status,
    'photos', coalesce((
      SELECT jsonb_agg(jsonb_build_object(
        'id', ph.id,
        'storagePath', ph.storage_path,
        'orderIndex', ph.order_index,
        'status', ph.status,
        'adminApproved', ph.admin_approved,
        'nsfwCleared', ph.nsfw_cleared,
        'nsfwScore', ph.nsfw_score,
        'nsfwCategory', ph.nsfw_category,
        'moderationStatus', ph.moderation_status,
        'moderationReason', ph.moderation_reason,
        'createdAt', ph.created_at
      ) ORDER BY ph.order_index, ph.created_at)
      FROM public.photos ph
      WHERE ph.profile_id = p.id
    ), '[]'::jsonb),
    'reportsAgainst', coalesce((
      SELECT jsonb_agg(to_jsonb(recent) ORDER BY recent.created_at DESC)
      FROM (
        SELECT r.id, r.reason, r.description, r.status, r.created_at,
               r.reporter_trust_score AS "reporterTrust"
        FROM public.reports r
        WHERE r.reported_user_id = u.id
        ORDER BY r.created_at DESC
        LIMIT 20
      ) recent
    ), '[]'::jsonb),
    'reportCounts', jsonb_build_object(
      'total', (SELECT count(*) FROM public.reports r WHERE r.reported_user_id = u.id),
      'pending', (SELECT count(*) FROM public.reports r WHERE r.reported_user_id = u.id AND r.status = 'pending'),
      'filedByMember', (SELECT count(*) FROM public.reports r WHERE r.reporter_id = u.id),
      'messageReports', (SELECT count(*) FROM public.message_reports mr WHERE mr.reported_user_id = u.id),
      'messageReportsPending', (SELECT count(*) FROM public.message_reports mr WHERE mr.reported_user_id = u.id AND mr.status = 'pending')
    )
  )
  INTO v_result
  FROM public.profiles p
  JOIN public.users u ON u.id = p.user_id
  LEFT JOIN public.cities city ON city.id = p.city_id
  LEFT JOIN public.regions region ON region.id = city.region_id
  WHERE p.id = v_profile_id;

  RETURN v_result;
END;
$$;

REVOKE ALL ON FUNCTION public.admin_member_review(uuid, uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_member_review(uuid, uuid) TO authenticated;

COMMENT ON FUNCTION public.admin_member_review(uuid, uuid) IS
  'Audited moderator view of one member: public profile fields, every photo with scan state, restrictions and report history. No guardian contacts, location or tokens.';

-- Reports against a member are read by reported_user_id on every review.
CREATE INDEX IF NOT EXISTS idx_reports_reported_time
  ON public.reports (reported_user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_reports_reporter
  ON public.reports (reporter_id);
CREATE INDEX IF NOT EXISTS idx_message_reports_reported_user
  ON public.message_reports (reported_user_id, status);

CREATE OR REPLACE FUNCTION public.admin_campaign_countries()
RETURNS TABLE(iso_code text, name text, members bigint)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  IF NOT public.is_active_admin(ARRAY['super_admin', 'support']) THEN
    RAISE EXCEPTION 'staff_authorization_required' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  SELECT c.iso_code::text, c.name, coalesce(reach.members, 0)::bigint
  FROM public.countries c
  LEFT JOIN (
    SELECT p.country_code, count(DISTINCT u.id) AS members
    FROM public.users u
    JOIN public.profiles p ON p.user_id = u.id
    WHERE coalesce(u.is_banned, false) = false
      AND u.deleted_at IS NULL
      AND p.visibility = 'visible'
    GROUP BY p.country_code
  ) reach ON reach.country_code = c.iso_code
  ORDER BY coalesce(reach.members, 0) DESC, c.name;
END;
$$;

REVOKE ALL ON FUNCTION public.admin_campaign_countries() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_campaign_countries() TO authenticated;

NOTIFY pgrst, 'reload schema';
