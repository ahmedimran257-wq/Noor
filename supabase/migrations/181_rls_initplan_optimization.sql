-- Cache the authenticated user id once per statement in high-traffic RLS
-- policies instead of asking Postgres to re-evaluate auth.uid() per row.

DROP POLICY IF EXISTS profile_views_select_premium_owner
  ON public.profile_views;
CREATE POLICY profile_views_select_premium_owner
  ON public.profile_views
  FOR SELECT
  TO authenticated
  USING (
    viewed_profile_id = (
      SELECT p.id
      FROM public.profiles p
      WHERE p.user_id = (SELECT auth.uid())
      LIMIT 1
    )
    AND public.has_active_premium((SELECT auth.uid()))
  );

DROP POLICY IF EXISTS admin_memberships_select_self_or_super_admin
  ON public.admin_memberships;
CREATE POLICY admin_memberships_select_self_or_super_admin
  ON public.admin_memberships
  FOR SELECT TO authenticated
  USING (
    user_id = (SELECT auth.uid())
    OR (SELECT public.is_active_admin(ARRAY['super_admin']))
  );

DROP POLICY IF EXISTS blocks_select ON public.blocks;
CREATE POLICY blocks_select ON public.blocks
  FOR SELECT TO authenticated
  USING (blocker_id = (SELECT auth.uid()));

DROP POLICY IF EXISTS guardian_mirrors_select
  ON public.guardian_chat_mirrors;
CREATE POLICY guardian_mirrors_select ON public.guardian_chat_mirrors
  FOR SELECT TO authenticated
  USING (
    ward_id = (SELECT auth.uid())
    OR public.is_current_guardian_for_ward(ward_id, mode)
  );

DROP POLICY IF EXISTS messages_select ON public.messages;
CREATE POLICY messages_select ON public.messages
  FOR SELECT TO authenticated
  USING (
    sender_id = (SELECT auth.uid())
    OR receiver_id = (SELECT auth.uid())
    OR EXISTS (
      SELECT 1
      FROM public.guardian_chat_mirrors gcm
      WHERE gcm.match_id = messages.match_id
        AND gcm.guardian_id = (SELECT auth.uid())
        AND public.is_current_guardian_for_ward(gcm.ward_id, gcm.mode)
    )
  );
