-- A parent user can be logically absent while ON DELETE CASCADE removes that
-- member's matches, interests, blocks and reports. Their AFTER DELETE triggers
-- must still invalidate the surviving participant without recreating a
-- revision row for the user currently being purged (which violates the FK).

CREATE OR REPLACE FUNCTION private.touch_discovery_member(p_user_id uuid)
RETURNS void
LANGUAGE sql
SECURITY DEFINER
SET search_path = ''
AS $$
  INSERT INTO private.discovery_member_revisions(user_id, revision, changed_at)
  SELECT p_user_id, 1, now()
  WHERE p_user_id IS NOT NULL
    AND EXISTS (
      SELECT 1 FROM public.users existing_user
      WHERE existing_user.id = p_user_id
    )
  ON CONFLICT (user_id) DO UPDATE
  SET revision = private.discovery_member_revisions.revision + 1,
      changed_at = now();
$$;

REVOKE ALL ON FUNCTION private.touch_discovery_member(uuid)
  FROM PUBLIC, anon, authenticated;

COMMENT ON FUNCTION private.touch_discovery_member(uuid) IS
  'Invalidates Discovery for an existing member and safely skips a member currently being hard-deleted.';
