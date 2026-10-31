-- Silarah — index the foreign keys that point at members
--
-- The performance advisor lists 31 foreign keys without a covering index.
-- Most are staff reviewer/creator columns on low-volume admin tables. These
-- eight reference members or their profiles, so an account deletion (the
-- 30-day purge) or a per-member read scans the whole child table. That is
-- invisible at today's size and slow at scale; each index is small.

CREATE INDEX IF NOT EXISTS idx_profile_bookmarks_saved_user
  ON public.profile_bookmarks(saved_user_id);
CREATE INDEX IF NOT EXISTS idx_profile_view_daily_seen_viewed_profile
  ON public.profile_view_daily_seen(viewed_profile_id);
CREATE INDEX IF NOT EXISTS idx_transactional_email_outbox_user
  ON public.transactional_email_outbox(user_id);
CREATE INDEX IF NOT EXISTS idx_photo_moderation_queue_user
  ON public.photo_moderation_queue(user_id);
CREATE INDEX IF NOT EXISTS idx_message_reports_reporter
  ON public.message_reports(reporter_id);
CREATE INDEX IF NOT EXISTS idx_admin_push_campaign_recipients_user
  ON public.admin_push_campaign_recipients(user_id);
CREATE INDEX IF NOT EXISTS idx_guardian_sessions_ward
  ON public.guardian_sessions(ward_id);
CREATE INDEX IF NOT EXISTS idx_photo_verification_submissions_profile
  ON public.photo_verification_submissions(profile_id);
