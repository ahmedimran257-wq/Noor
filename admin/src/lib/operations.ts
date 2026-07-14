import "server-only";

import { createClient } from "@/lib/supabase/server";
import { createAdminClient } from "@/lib/supabase/admin";

export type DashboardMetrics = Record<string, number>;
export type PagedResult<T> = {
  rows: T[];
  page: number;
  limit: number;
  total: number;
  hasNextPage: boolean;
  hasPreviousPage: boolean;
};

async function rpc<T>(name: string, args?: Record<string, unknown>): Promise<T> {
  const supabase = await createClient();
  const { data, error } = await supabase.rpc(name, args);
  if (error) throw new Error(error.message);
  return data as T;
}

export const getDashboardMetrics = () => rpc<DashboardMetrics>("admin_dashboard_metrics");
export async function getUsers(query = "", page = 1): Promise<PagedResult<UserRow>> {
  const limit = 50;
  const safePage = Number.isFinite(page) ? Math.max(1, Math.floor(page)) : 1;
  const offset = (safePage - 1) * limit;
  const rows = await rpc<UserRow[]>("admin_user_directory_page", {
    p_query: query,
    p_limit: limit,
    p_offset: offset,
  });
  const total = Number(rows[0]?.total_count ?? 0);

  return {
    rows,
    page: safePage,
    limit,
    total,
    hasNextPage: offset + rows.length < total,
    hasPreviousPage: safePage > 1,
  };
}
export async function getRevealedUserPii(userId: string, reason: string) {
  const rows = await rpc<RevealedUserPii[]>("admin_reveal_user_pii", {
    p_user_id: userId,
    p_reason: reason,
  });
  return rows[0] ?? null;
}
export const getKycQueue = () => rpc<KycRow[]>("admin_kyc_queue", { p_limit: 100 });
export const getReports = () => rpc<ReportRow[]>("admin_reports_queue", { p_limit: 100 });
export const getMessageReports = () => rpc<MessageReportRow[]>("admin_message_reports_queue", { p_limit: 100 });
export async function getPhotos(): Promise<PhotoRow[]> {
  const rows = await rpc<PhotoRow[]>("admin_photo_queue", { p_limit: 100 });
  if (rows.length === 0) return rows;

  const adminClient = createAdminClient();
  const withSignedUrls = await Promise.all(
    rows.map(async (photo) => {
      const { data, error } = await adminClient.storage
        .from("profile-photos")
        .createSignedUrl(photo.storage_path, 60 * 5);

      return {
        ...photo,
        preview_url: error ? null : data?.signedUrl ?? null,
        preview_error: error?.message ?? null,
      };
    }),
  );

  return withSignedUrls;
}
export const getMatchMetrics = () => rpc<DashboardMetrics>("admin_match_metrics");
export const getMatches = () => rpc<MatchRow[]>("admin_active_matches", { p_limit: 100 });
export const getSubscribers = () => rpc<SubscriberRow[]>("admin_subscribers", { p_limit: 100 });
export const getCampaigns = () => rpc<CampaignRow[]>("admin_push_campaigns", { p_limit: 100 });
export const getContentPages = () => rpc<ContentPageRow[]>("admin_content_pages", { p_limit: 100 });
export const getSuccessStories = () => rpc<SuccessStoryRow[]>("admin_success_stories", { p_limit: 100 });
export const getStaffMembers = () => rpc<StaffMemberRow[]>("admin_staff_members", { p_limit: 100 });
export const getSystemHealth = () => rpc<DashboardMetrics>("admin_system_health");
export const getLocalizationOverview = () => rpc<LocalizationRow[]>("admin_localization_overview");
export const getLiveOperationsSnapshot = () => rpc<LiveOperationsSnapshot>("admin_live_operations_snapshot");
export const getOnlineUsers = () => rpc<OnlineUserRow[]>("admin_online_users", { p_limit: 25 });
export const getAuditFeed = () => rpc<AuditRow[]>("admin_audit_feed", { p_limit: 200 });
export const getAdminInbox = () => rpc<AdminNotificationRow[]>("admin_inbox", { p_limit: 200 });
export const getSecurityMetrics = () => rpc<DashboardMetrics>("admin_security_metrics");

export type UserRow = { user_id:string; profile_id:string; name:string; email:string|null; country_code:string; gender:string; joined_at:string; last_active_at:string|null; onboarding_step:number; completeness_score:number; visibility:string; is_banned:boolean; is_shadowbanned:boolean; subscription_status:string; verification_status:string; has_verification_badge:boolean; can_approve_profile:boolean; approval_block_reason:string|null; total_count?:number };
export type RevealedUserPii = { user_id:string; name:string; email:string|null; revealed_at:string };
export type KycRow = { user_id:string; profile_id:string; name:string; country_code:string; kyc_id_type:string|null; face_similarity:number|null; created_at:string; selfie_path:string|null; id_path:string|null };
export type ReportRow = { report_id:string; reporter_id:string; reported_user_id:string; reason:string; description:string|null; created_at:string; report_count:number; reported_name:string };
export type MessageReportRow = { report_id:string; message_id:string; match_id:string; reporter_id:string; reported_user_id:string; reported_name:string; reason:string; description:string|null; message_content:string; created_at:string };
export type PhotoRow = { photo_id:string; user_id:string; name:string; storage_path:string; nsfw_score:number|null; nsfw_category:string|null; created_at:string; moderation_status:string; preview_url?:string|null; preview_error?:string|null };
export type MatchRow = { match_id:string; user_a_name:string; user_b_name:string; created_at:string; message_count:number; last_message_at:string|null };
export type SubscriberRow = { user_id:string; name:string; country_code:string; subscription_status:string; subscription_expires_at:string|null; product_id:string|null; total_paid:number };
export type CampaignRow = { campaign_id:string; title:string; body:string; deep_link:string|null; audience:string; country_code:string|null; scheduled_at:string; status:string; queued_count:number; created_at:string; queued_at:string|null };
export type ContentPageRow = { page_id:string; slug:string; locale:string; title:string; body:string; status:string; updated_at:string; published_at:string|null };
export type SuccessStoryRow = { story_id:string; couple_name:string; country_code:string|null; story:string; photo_path:string|null; status:string; created_at:string; published_at:string|null };
export type StaffMemberRow = { user_id:string; email:string; role:string; status:string; mfa_required:boolean; created_at:string; last_sign_in_at:string|null };
export type LocalizationRow = { locale:string; page_count:number; published_count:number; last_updated:string|null };
export type LiveBucket = Record<string, number>;
export type LiveOperationsSnapshot = { generatedAt:number; traffic:LiveBucket; engagement:LiveBucket; progress:LiveBucket; queues:LiveBucket; pipeline:LiveBucket };
export type OnlineUserRow = { user_id:string; profile_id:string|null; name:string; email:string|null; country_code:string|null; gender:string|null; last_seen_at:string; app_state:string; platform:string|null; visibility:string; verification_status:string; subscription_status:string };
export type AuditRow = { audit_id:string; admin_id:string; admin_email:string|null; actor_role:string|null; action_type:string; target_user_id:string|null; details:Record<string, unknown>|null; created_at:string };
export type AdminNotificationRow = { notification_id:string; type:string; message:string; related_user_id:string|null; is_read:boolean; created_at:string };
