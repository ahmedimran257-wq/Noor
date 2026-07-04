-- ============================================================
-- MITHAQ — Lock profile photo storage reads
-- ============================================================

INSERT INTO storage.buckets (id, name, public)
VALUES ('profile-photos', 'profile-photos', false)
ON CONFLICT (id) DO UPDATE SET public = false;

-- Profile photo reads must be authorized by public.can_view_photo() inside
-- the get-signed-url Edge Function. Do not allow authenticated clients to
-- SELECT storage.objects directly, because that lets them mint signed URLs for
-- guessed paths outside the app's privacy flow.
DROP POLICY IF EXISTS "profile photos read" ON storage.objects;
DROP POLICY IF EXISTS "profile_photos_read" ON storage.objects;
DROP POLICY IF EXISTS "Allow profile photo reads" ON storage.objects;
DROP POLICY IF EXISTS "Allow authenticated profile photo reads" ON storage.objects;
DROP POLICY IF EXISTS "Public profile photo read" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated profile photo read" ON storage.objects;
