-- Persist saved/bookmarked profiles server-side so they work across devices.
CREATE TABLE IF NOT EXISTS public.profile_bookmarks (
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  saved_user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, saved_user_id),
  CHECK (user_id <> saved_user_id)
);

ALTER TABLE public.profile_bookmarks ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS profile_bookmarks_owner_select ON public.profile_bookmarks;
CREATE POLICY profile_bookmarks_owner_select
ON public.profile_bookmarks
FOR SELECT
TO authenticated
USING (auth.uid() = user_id);

DROP POLICY IF EXISTS profile_bookmarks_owner_insert ON public.profile_bookmarks;
CREATE POLICY profile_bookmarks_owner_insert
ON public.profile_bookmarks
FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS profile_bookmarks_owner_delete ON public.profile_bookmarks;
CREATE POLICY profile_bookmarks_owner_delete
ON public.profile_bookmarks
FOR DELETE
TO authenticated
USING (auth.uid() = user_id);

CREATE INDEX IF NOT EXISTS idx_profile_bookmarks_user_created
ON public.profile_bookmarks (user_id, created_at DESC);
