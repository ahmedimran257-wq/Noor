-- Repair clean uploads finalized under the superseded "hold every photo"
-- contract. Rows with a pre-existing active photo in the same slot are left
-- for staff review instead of guessing which image should replace it.
UPDATE public.photos ph
SET status = 'active',
    admin_approved = true,
    nsfw_cleared = true,
    moderation_status = 'pending',
    nsfw_category = 'unreviewed_upload',
    moderation_source = 'on_device_scan'
WHERE ph.status = 'pending_review'
  AND coalesce(ph.nsfw_score, 0) <= 0.85
  AND NOT EXISTS (
    SELECT 1
    FROM public.photos active_photo
    WHERE active_photo.profile_id = ph.profile_id
      AND active_photo.order_index = ph.order_index
      AND active_photo.status = 'active'
      AND active_photo.id <> ph.id
  );
