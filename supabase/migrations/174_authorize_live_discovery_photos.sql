-- Allow the private-media worker to sign photos for candidates returned by
-- the live discovery pool before the member opens (and records a view of) the
-- profile. Migration 131 moved discovery off precomputed recommendations, but
-- the photo authorization boundary in migration 149 still required a recent
-- recommendation or recorded view. That mismatch blanked first-load cards.

CREATE OR REPLACE FUNCTION public.get_authorized_photo_paths(
  p_viewer_user_id uuid,
  p_owner_user_ids uuid[],
  p_order_index integer
)
RETURNS TABLE(owner_user_id uuid, storage_path text)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT owner.user_id, ph.storage_path
  FROM public.profiles owner
  JOIN public.photos ph ON ph.profile_id = owner.id
  JOIN public.users owner_account ON owner_account.id = owner.user_id
  WHERE auth.role() = 'service_role'
    AND p_order_index BETWEEN 0 AND 3
    AND owner.user_id = ANY(
      ARRAY(
        SELECT DISTINCT requested_id
        FROM unnest(coalesce(p_owner_user_ids, ARRAY[]::uuid[])) requested_id
        LIMIT 50
      )
    )
    AND owner_account.deleted_at IS NULL
    AND coalesce(owner_account.is_banned, false) = false
    AND ph.order_index = p_order_index
    AND ph.status = 'active'
    AND ph.admin_approved = true
    AND ph.nsfw_cleared = true
    AND public.can_view_photo(p_viewer_user_id, owner.id)
    AND (
      owner.user_id = p_viewer_user_id
      OR EXISTS (
        SELECT 1 FROM public.recommendations r
        JOIN public.profiles viewer ON viewer.id = r.viewer_profile_id
        WHERE viewer.user_id = p_viewer_user_id
          AND r.candidate_profile_id = owner.id
          AND r.generated_at >= now() - interval '7 days'
      )
      OR EXISTS (
        -- The authoritative feed now reads the live discovery pool. Authorize
        -- the same safe, visible candidates without consuming a daily view.
        SELECT 1
        FROM public.discovery_pool candidate
        JOIN public.profiles viewer
          ON viewer.user_id = p_viewer_user_id
        JOIN public.users viewer_account
          ON viewer_account.id = viewer.user_id
        WHERE candidate.profile_id = owner.id
          AND candidate.user_id = owner.user_id
          AND owner.user_id <> p_viewer_user_id
          AND viewer.visibility = 'visible'
          AND coalesce(viewer.onboarding_completed, false) = true
          AND viewer.approved_at IS NOT NULL
          AND viewer_account.deleted_at IS NULL
          AND coalesce(viewer_account.is_banned, false) = false
          AND owner.visibility = 'visible'
          AND coalesce(owner.onboarding_completed, false) = true
          AND owner.approved_at IS NOT NULL
          AND candidate.photo_count > 0
          AND lower(candidate.gender::text) <> lower(viewer.gender::text)
          AND NOT EXISTS (
            SELECT 1
            FROM public.blocks b
            WHERE (b.blocker_id = p_viewer_user_id
                    AND b.blocked_id = owner.user_id)
               OR (b.blocker_id = owner.user_id
                    AND b.blocked_id = p_viewer_user_id)
          )
      )
      OR EXISTS (
        SELECT 1 FROM public.profile_view_daily_seen s
        WHERE s.viewer_user_id = p_viewer_user_id
          AND s.viewed_profile_id = owner.id
          AND s.viewed_on = current_date
      )
      OR EXISTS (
        SELECT 1 FROM public.interests i
        WHERE (i.sender_id = p_viewer_user_id AND i.receiver_id = owner.user_id)
           OR (i.receiver_id = p_viewer_user_id AND i.sender_id = owner.user_id)
      )
      OR EXISTS (
        SELECT 1 FROM public.matches m
        WHERE (m.user_a = p_viewer_user_id AND m.user_b = owner.user_id)
           OR (m.user_b = p_viewer_user_id AND m.user_a = owner.user_id)
      )
      OR EXISTS (
        SELECT 1 FROM public.profile_bookmarks b
        WHERE b.user_id = p_viewer_user_id
          AND b.saved_user_id = owner.user_id
      )
      OR EXISTS (
        SELECT 1 FROM public.photo_access_requests par
        WHERE par.requester_id = p_viewer_user_id
          AND par.owner_id = owner.user_id
          AND par.status = 'granted'
      )
      OR owner.guardian_user_id = p_viewer_user_id
    );
$$;

REVOKE ALL ON FUNCTION public.get_authorized_photo_paths(uuid, uuid[], integer)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.get_authorized_photo_paths(uuid, uuid[], integer)
  TO service_role;

COMMENT ON FUNCTION public.get_authorized_photo_paths(uuid, uuid[], integer) IS
  'Service-only private photo paths for owners, live discovery candidates, and established member relationships.';
