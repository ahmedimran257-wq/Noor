-- Consolidate owner and guardian access into one permissive policy per action.
-- A policy declared TO public also applies to authenticated users, so keeping a
-- second authenticated-only policy forces PostgreSQL to evaluate both.

DROP POLICY IF EXISTS prefs_insert ON public.profile_preferences;
DROP POLICY IF EXISTS profile_preferences_guardian_insert ON public.profile_preferences;
CREATE POLICY prefs_insert
ON public.profile_preferences
FOR INSERT
TO public
WITH CHECK (
  EXISTS (
    SELECT 1
    FROM public.profiles AS p
    WHERE p.id = profile_preferences.profile_id
      AND (
        p.user_id = (SELECT auth.uid())
        OR p.guardian_user_id = (SELECT auth.uid())
      )
  )
);

DROP POLICY IF EXISTS prefs_select ON public.profile_preferences;
DROP POLICY IF EXISTS profile_preferences_guardian_select ON public.profile_preferences;
CREATE POLICY prefs_select
ON public.profile_preferences
FOR SELECT
TO public
USING (
  EXISTS (
    SELECT 1
    FROM public.profiles AS p
    WHERE p.id = profile_preferences.profile_id
      AND (
        p.user_id = (SELECT auth.uid())
        OR p.guardian_user_id = (SELECT auth.uid())
      )
  )
);

DROP POLICY IF EXISTS prefs_update ON public.profile_preferences;
DROP POLICY IF EXISTS profile_preferences_guardian_update ON public.profile_preferences;
CREATE POLICY prefs_update
ON public.profile_preferences
FOR UPDATE
TO public
USING (
  EXISTS (
    SELECT 1
    FROM public.profiles AS p
    WHERE p.id = profile_preferences.profile_id
      AND (
        p.user_id = (SELECT auth.uid())
        OR p.guardian_user_id = (SELECT auth.uid())
      )
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1
    FROM public.profiles AS p
    WHERE p.id = profile_preferences.profile_id
      AND (
        p.user_id = (SELECT auth.uid())
        OR p.guardian_user_id = (SELECT auth.uid())
      )
  )
);

DROP POLICY IF EXISTS profiles_insert ON public.profiles;
DROP POLICY IF EXISTS profiles_guardian_insert ON public.profiles;
CREATE POLICY profiles_insert
ON public.profiles
FOR INSERT
TO public
WITH CHECK (
  user_id = (SELECT auth.uid())
  OR guardian_user_id = (SELECT auth.uid())
);

DROP POLICY IF EXISTS profiles_select ON public.profiles;
DROP POLICY IF EXISTS profiles_guardian_select ON public.profiles;
CREATE POLICY profiles_select
ON public.profiles
FOR SELECT
TO public
USING (
  user_id = (SELECT auth.uid())
  OR guardian_user_id = (SELECT auth.uid())
  OR (
    visibility = 'visible'
    AND NOT EXISTS (
      SELECT 1
      FROM public.blocks AS b
      WHERE
        (b.blocker_id = (SELECT auth.uid()) AND b.blocked_id = profiles.user_id)
        OR
        (b.blocker_id = profiles.user_id AND b.blocked_id = (SELECT auth.uid()))
    )
  )
);

DROP POLICY IF EXISTS profiles_update ON public.profiles;
DROP POLICY IF EXISTS profiles_guardian_update ON public.profiles;
CREATE POLICY profiles_update
ON public.profiles
FOR UPDATE
TO public
USING (
  user_id = (SELECT auth.uid())
  OR guardian_user_id = (SELECT auth.uid())
)
WITH CHECK (
  user_id = (SELECT auth.uid())
  OR guardian_user_id = (SELECT auth.uid())
);
