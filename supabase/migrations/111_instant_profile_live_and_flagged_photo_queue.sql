-- Clean primary photos publish profiles immediately. Staff only reviews photos
-- explicitly flagged by on-device moderation above the 0.85 confidence gate.

CREATE TABLE IF NOT EXISTS public.photo_moderation_queue (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  photo_id uuid NOT NULL UNIQUE REFERENCES public.photos(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  confidence numeric(5,4) NOT NULL CHECK (confidence > 0.85 AND confidence <= 1),
  category text NOT NULL CHECK (category = 'explicit_content'),
  status text NOT NULL DEFAULT 'pending_review'
    CHECK (status IN ('pending_review', 'approved', 'rejected')),
  created_at timestamptz NOT NULL DEFAULT now(),
  reviewed_at timestamptz,
  reviewed_by uuid REFERENCES auth.users(id),
  review_reason text
);

CREATE INDEX IF NOT EXISTS idx_photo_moderation_queue_pending
  ON public.photo_moderation_queue(created_at ASC)
  WHERE status = 'pending_review';

ALTER TABLE public.photo_moderation_queue ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.photos
  DROP CONSTRAINT IF EXISTS photos_moderation_status_check;
ALTER TABLE public.photos
  ADD CONSTRAINT photos_moderation_status_check
  CHECK (moderation_status IN ('pending_upload', 'pending', 'approved', 'rejected'));
ALTER TABLE public.photos
  ALTER COLUMN moderation_status SET DEFAULT 'pending_upload';

UPDATE public.photos
SET moderation_status = 'pending_upload'
WHERE status = 'pending_upload'
  AND moderation_status = 'pending';

DROP POLICY IF EXISTS photo_moderation_queue_staff_read
  ON public.photo_moderation_queue;
CREATE POLICY photo_moderation_queue_staff_read
  ON public.photo_moderation_queue FOR SELECT
  USING (public.is_active_admin(ARRAY['super_admin', 'moderator']));

-- Bring existing client-screened rows forward. Only strong explicit-content
-- evidence remains pending; everything else skips staff review.
UPDATE public.photos
SET moderation_status = 'approved',
    admin_approved = true,
    nsfw_cleared = true,
    status = 'active'
WHERE moderation_status = 'pending'
  AND status = 'active'
  AND NOT (
    nsfw_category = 'explicit_content'
    AND coalesce(nsfw_score, 0) > 0.85
  );

INSERT INTO public.photo_moderation_queue(
  photo_id, user_id, confidence, category, status
)
SELECT
  ph.id,
  p.user_id,
  ph.nsfw_score,
  'explicit_content',
  'pending_review'
FROM public.photos ph
JOIN public.profiles p ON p.id = ph.profile_id
WHERE ph.moderation_status = 'pending'
  AND ph.status = 'active'
  AND ph.nsfw_category = 'explicit_content'
  AND ph.nsfw_score > 0.85
ON CONFLICT (photo_id) DO NOTHING;

-- approved_at remains the discovery/new-arrival timestamp; it is now assigned
-- by ML approval instead of a staff action.
UPDATE public.profiles p
SET approved_at = coalesce(p.approved_at, now()),
    visibility = CASE
      WHEN p.visibility IN ('suspended', 'deactivated') THEN p.visibility
      ELSE 'visible'
    END
WHERE EXISTS (
  SELECT 1
  FROM public.photos ph
  WHERE ph.profile_id = p.id
    AND ph.order_index = 0
    AND ph.moderation_status = 'approved'
    AND ph.admin_approved = true
    AND ph.nsfw_cleared = true
    AND ph.status = 'active'
);

UPDATE public.profiles
SET visibility = 'paused'
WHERE visibility = 'pending_review';

ALTER TABLE public.profiles
  DROP CONSTRAINT IF EXISTS profiles_visibility_check;
ALTER TABLE public.profiles
  ADD CONSTRAINT profiles_visibility_check
  CHECK (visibility IN ('visible', 'paused', 'suspended', 'deactivated'));

CREATE OR REPLACE FUNCTION public.admin_photo_queue(p_limit integer DEFAULT 100)
RETURNS TABLE(
  photo_id uuid,
  user_id uuid,
  name text,
  storage_path text,
  nsfw_score numeric,
  nsfw_category text,
  created_at timestamptz,
  moderation_status text
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT
    ph.id,
    q.user_id,
    concat_ws(' ', p.first_name, p.last_name),
    ph.storage_path,
    q.confidence,
    q.category,
    q.created_at,
    q.status
  FROM public.photo_moderation_queue q
  JOIN public.photos ph ON ph.id = q.photo_id
  JOIN public.profiles p ON p.user_id = q.user_id
  WHERE public.is_active_admin(ARRAY['super_admin', 'moderator'])
    AND q.status = 'pending_review'
  ORDER BY q.created_at ASC
  LIMIT least(greatest(p_limit, 1), 100);
$$;

CREATE OR REPLACE FUNCTION public.admin_review_photo(
  p_photo_id uuid,
  p_decision text,
  p_reason text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_target uuid;
  v_is_primary boolean;
BEGIN
  IF NOT public.is_active_admin(ARRAY['super_admin', 'moderator']) THEN
    RAISE EXCEPTION 'Staff authorization required';
  END IF;
  IF p_decision NOT IN ('approve', 'reject') THEN
    RAISE EXCEPTION 'Unsupported photo decision';
  END IF;

  SELECT q.user_id, ph.order_index = 0
  INTO v_target, v_is_primary
  FROM public.photo_moderation_queue q
  JOIN public.photos ph ON ph.id = q.photo_id
  WHERE q.photo_id = p_photo_id
    AND q.status = 'pending_review'
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Flagged photo is no longer pending review';
  END IF;

  UPDATE public.photo_moderation_queue
  SET status = CASE WHEN p_decision = 'approve' THEN 'approved' ELSE 'rejected' END,
      reviewed_at = now(),
      reviewed_by = auth.uid(),
      review_reason = p_reason
  WHERE photo_id = p_photo_id;

  UPDATE public.photos
  SET moderation_status = CASE WHEN p_decision = 'approve' THEN 'approved' ELSE 'rejected' END,
      moderation_reason = p_reason,
      moderated_at = now(),
      moderated_by = auth.uid(),
      admin_approved = p_decision = 'approve',
      nsfw_cleared = p_decision = 'approve',
      status = 'active'
  WHERE id = p_photo_id;

  IF p_decision = 'approve' AND v_is_primary THEN
    UPDATE public.profiles p
    SET approved_at = coalesce(p.approved_at, now()),
        visibility = CASE
          WHEN p.visibility IN ('suspended', 'deactivated') THEN p.visibility
          ELSE 'visible'
        END
    WHERE p.id = (
      SELECT ph.profile_id FROM public.photos ph WHERE ph.id = p_photo_id
    );
  END IF;

  PERFORM public.queue_notification(
    v_target,
    CASE
      WHEN p_decision = 'approve' AND v_is_primary THEN 'profile_live'
      WHEN p_decision = 'approve' THEN 'photo_approved'
      ELSE 'photo_rejected'
    END,
    CASE
      WHEN p_decision = 'approve' AND v_is_primary THEN 'Your profile is now live! 🎉'
      WHEN p_decision = 'approve' THEN 'Photo approved'
      ELSE 'Photo rejected'
    END,
    CASE
      WHEN p_decision = 'approve' AND v_is_primary THEN 'Muslims in your area can now find you on Mithaq.'
      WHEN p_decision = 'approve' THEN 'Your flagged photo was reviewed and approved.'
      ELSE 'A flagged photo could not be accepted. Please upload a clear, respectful portrait.'
    END,
    CASE
      WHEN p_decision = 'approve' AND v_is_primary THEN '/home?tab=0'
      ELSE '/home?tab=3'
    END
  );

  INSERT INTO public.admin_audit_log(
    admin_id, actor_role, action_type, target_user_id, details
  ) VALUES (
    auth.uid(), public.current_admin_role(), 'photo_' || p_decision,
    v_target, jsonb_build_object('photo_id', p_photo_id, 'reason', p_reason)
  );
END;
$$;

REVOKE ALL ON FUNCTION public.admin_photo_queue(integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.admin_review_photo(uuid, text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_photo_queue(integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_review_photo(uuid, text, text) TO authenticated;

-- Profile visibility is no longer a moderation work item.
DROP FUNCTION IF EXISTS public.admin_profile_visibility_action(uuid, text, text);

-- Notifications must be part of the realtime publication for instant inserts.
DO $$
BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;
EXCEPTION
  WHEN duplicate_object THEN NULL;
END;
$$;
