-- Equal, on-device KYC baseline. India-only DigiLocker remains optional UI.
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS kyc_verified boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS kyc_method text,
  ADD COLUMN IF NOT EXISTS face_similarity numeric(5,2),
  ADD COLUMN IF NOT EXISTS kyc_id_type text,
  ADD COLUMN IF NOT EXISTS kyc_country_code varchar(2),
  ADD COLUMN IF NOT EXISTS kyc_selfie_storage_path text,
  ADD COLUMN IF NOT EXISTS kyc_id_photo_storage_path text;

DO $$
DECLARE constraint_name text;
BEGIN
  SELECT conname INTO constraint_name
  FROM pg_constraint
  WHERE conrelid = 'public.profiles'::regclass
    AND contype = 'c'
    AND pg_get_constraintdef(oid) ILIKE '%verification_status%';
  IF constraint_name IS NOT NULL THEN
    EXECUTE format('ALTER TABLE public.profiles DROP CONSTRAINT %I', constraint_name);
  END IF;
END $$;

ALTER TABLE public.profiles
  ADD CONSTRAINT profiles_verification_status_check
  CHECK (verification_status IN ('unverified', 'verified', 'pending_review'));

INSERT INTO storage.buckets (id, name, public)
VALUES ('kyc-documents', 'kyc-documents', false)
ON CONFLICT (id) DO UPDATE SET public = false;

CREATE INDEX IF NOT EXISTS idx_profiles_kyc_verified
  ON public.profiles (kyc_verified) WHERE kyc_verified = true;
