-- ============================================================
-- MIGRATION 039: SELFIE VERIFICATION STORAGE BUCKET
-- Creates a private storage bucket for verification selfies
-- and sets up RLS policies.
-- ============================================================

-- Ensure storage bucket 'selfie-verifications' exists and is private
INSERT INTO storage.buckets (id, name, public)
VALUES ('selfie-verifications', 'selfie-verifications', false)
ON CONFLICT (id) DO NOTHING;


-- Drop existing policies if they exist to prevent conflicts
DROP POLICY IF EXISTS "Allow authenticated uploads" ON storage.objects;
DROP POLICY IF EXISTS "Allow user read" ON storage.objects;

-- RLS policies for the selfie-verifications bucket
-- 1. Allow authenticated users to upload selfies to a folder named after their own user ID
CREATE POLICY "Allow authenticated uploads" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'selfie-verifications' 
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

-- 2. Allow authenticated users to view their own selfies
CREATE POLICY "Allow user read" ON storage.objects
  FOR SELECT TO authenticated
  USING (
    bucket_id = 'selfie-verifications' 
    AND (storage.foldername(name))[1] = auth.uid()::text
  );
