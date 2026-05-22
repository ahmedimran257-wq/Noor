-- ============================================================
-- MIGRATION 021: IDENTITY VERIFICATION SCHEMA
--
-- Fixes Audit Finding 4.2 (High):
--   No explicit identity verification tying a selfie to uploaded
--   photos. Photos are marked admin_approved but there's no KYC.
--
-- Changes:
--   1. Create identity_verifications table
--   2. Create sync_verification_status() trigger
--   3. Feed boost for verified profiles (already in 015/016)
-- ============================================================

-- ── 1. Identity Verifications table ───────────────────────────
CREATE TABLE identity_verifications (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id          uuid UNIQUE NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  provider         text NOT NULL DEFAULT 'manual'
                     CHECK (provider IN ('manual','persona','onfido','sumsub')),
  status           text NOT NULL DEFAULT 'pending'
                     CHECK (status IN ('pending','in_review','approved','rejected','expired')),
  provider_ref_id  text,          -- External verification ID from KYC provider
  selfie_path      text,          -- Storage path of verification selfie
  rejection_reason text,          -- Why verification was rejected
  attempts         int NOT NULL DEFAULT 1,
  verified_at      timestamptz,
  expires_at       timestamptz,   -- Verifications can expire (e.g. after 1 year)
  created_at       timestamptz NOT NULL DEFAULT now(),
  updated_at       timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_identity_verif_status ON identity_verifications(status);
CREATE INDEX idx_identity_verif_user   ON identity_verifications(user_id);

COMMENT ON TABLE identity_verifications IS
  'Identity verification records. Supports manual admin verification, '
  'or third-party KYC providers (Persona, Onfido, Sumsub). '
  'Verified status syncs to profiles.is_verified via trigger. '
  'Verification can expire after a configurable period.';

-- ── 2. Sync verification status to profiles ──────────────────
-- When an identity_verifications row changes status, update
-- the corresponding profiles.is_verified boolean.
-- ================================================================
CREATE OR REPLACE FUNCTION sync_verification_status()
RETURNS trigger AS $$
BEGIN
  IF NEW.status = 'approved' THEN
    UPDATE profiles
    SET is_verified = true
    WHERE user_id = NEW.user_id;

    -- Notify user of successful verification
    PERFORM queue_notification(
      NEW.user_id,
      'verification_approved',
      '✅ Profile verified!',
      'Your identity has been verified. Verified profiles receive more interest and rank higher in search.',
      'noor://profile'
    );

  ELSIF NEW.status IN ('rejected', 'expired') THEN
    UPDATE profiles
    SET is_verified = false
    WHERE user_id = NEW.user_id;

    IF NEW.status = 'rejected' THEN
      PERFORM queue_notification(
        NEW.user_id,
        'verification_rejected',
        'Verification not approved',
        COALESCE(
          'Your verification was not approved: ' || NEW.rejection_reason,
          'Your verification was not approved. Please try again with a clear selfie.'
        ),
        'noor://settings/verification'
      );
    END IF;
  END IF;

  NEW.updated_at := NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE TRIGGER trg_sync_verification_status
  BEFORE UPDATE OF status ON identity_verifications
  FOR EACH ROW
  WHEN (OLD.status IS DISTINCT FROM NEW.status)
  EXECUTE FUNCTION sync_verification_status();

-- Also trigger on INSERT (for initial approval)
CREATE TRIGGER trg_sync_verification_status_insert
  AFTER INSERT ON identity_verifications
  FOR EACH ROW
  WHEN (NEW.status = 'approved')
  EXECUTE FUNCTION sync_verification_status();

-- ── 3. Request verification RPC ──────────────────────────────
-- Called by Flutter when user taps "Verify my profile"
-- Creates or resets the verification record.
-- ================================================================
CREATE OR REPLACE FUNCTION request_verification(p_selfie_path text)
RETURNS jsonb AS $$
DECLARE
  v_user_id   uuid;
  v_existing  identity_verifications%ROWTYPE;
  v_verif_id  uuid;
BEGIN
  v_user_id := auth.uid();

  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required.';
  END IF;

  -- Check for existing verification
  SELECT * INTO v_existing
  FROM identity_verifications WHERE user_id = v_user_id;

  IF v_existing IS NOT NULL THEN
    -- Already verified and not expired
    IF v_existing.status = 'approved'
       AND (v_existing.expires_at IS NULL OR v_existing.expires_at > NOW()) THEN
      RETURN jsonb_build_object('status', 'already_verified');
    END IF;

    -- In review
    IF v_existing.status = 'in_review' THEN
      RETURN jsonb_build_object('status', 'in_review');
    END IF;

    -- Max 3 attempts
    IF v_existing.attempts >= 3 AND v_existing.status = 'rejected' THEN
      RETURN jsonb_build_object(
        'status', 'max_attempts_reached',
        'message', 'Maximum verification attempts reached. Please contact support.'
      );
    END IF;

    -- Re-attempt: update existing record
    UPDATE identity_verifications SET
      selfie_path = p_selfie_path,
      status = 'pending',
      rejection_reason = NULL,
      attempts = v_existing.attempts + 1,
      updated_at = NOW()
    WHERE user_id = v_user_id
    RETURNING id INTO v_verif_id;
  ELSE
    -- New verification request
    INSERT INTO identity_verifications (user_id, selfie_path)
    VALUES (v_user_id, p_selfie_path)
    RETURNING id INTO v_verif_id;
  END IF;

  -- Notify admin
  INSERT INTO admin_notifications (type, message, related_user_id)
  VALUES (
    'verification_request',
    format('New identity verification request (attempt %s)',
           COALESCE(v_existing.attempts + 1, 1)),
    v_user_id
  );

  RETURN jsonb_build_object('status', 'submitted', 'verification_id', v_verif_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- ── 4. Expire old verifications (yearly) ──────────────────────
CREATE OR REPLACE FUNCTION expire_old_verifications()
RETURNS void AS $$
BEGIN
  UPDATE identity_verifications
  SET status = 'expired'
  WHERE status = 'approved'
    AND expires_at IS NOT NULL
    AND expires_at < NOW();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Monthly check for expired verifications
SELECT cron.schedule(
  'expire_old_verifications_monthly',
  '0 5 1 * *',  -- 1st of each month at 05:00 UTC
  $$SELECT expire_old_verifications();$$
);

-- ── 5. RLS policies ──────────────────────────────────────────
ALTER TABLE identity_verifications ENABLE ROW LEVEL SECURITY;

CREATE POLICY identity_verif_select ON identity_verifications
  FOR SELECT USING (user_id = auth.uid());

-- Inserts handled by request_verification() RPC (SECURITY DEFINER)
-- Updates handled by admin via service role
