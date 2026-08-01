-- Complete the JPEG profile-photo contract at the storage boundary.
-- The bucket previously admitted only WebP, which made a server-decodable
-- JPEG reservation fail during the signed storage transfer.

UPDATE storage.buckets
SET public = false,
    file_size_limit = 2097152,
    allowed_mime_types = ARRAY['image/jpeg']::text[]
WHERE id = 'profile-photos';
