-- Remove orphan cleanup work for the verified-empty identity buckets retired
-- after migration 211. The generic storage worker must not retry destinations
-- that no longer exist.
DELETE FROM private.storage_deletion_jobs
WHERE bucket_id IN ('kyc-documents', 'selfie-verifications');
