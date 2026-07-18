-- Account-standing changes must be visible throughout the signed-in app
-- without depending on a push notification or manual refresh. Realtime still
-- applies profiles RLS, including the owner's explicit self-read policy.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'profiles'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.profiles;
  END IF;
END;
$$;
