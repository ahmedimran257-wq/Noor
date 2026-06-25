"use server";

import { revalidatePath } from "next/cache";
import { z } from "zod";
import { requireAdmin, type AdminRole, type CurrentAdmin } from "@/lib/auth";
import { createAdminClient } from "@/lib/supabase/admin";
import { createClient } from "@/lib/supabase/server";

const uuidSchema = z.string().uuid();
const reasonSchema = z.string().trim().max(500).optional().default("");
const accountActionSchema = z.object({
  userId: uuidSchema,
  action: z.enum(["suspend", "restore", "ban", "shadowban"]),
  reason: reasonSchema,
});
const bulkAccountActionSchema = z.object({
  userIds: z.array(uuidSchema).min(1).max(50),
  action: z.enum(["suspend", "restore", "ban", "shadowban"]),
  reason: z.string().trim().min(6, "Bulk actions require a reason.").max(500),
});
const kycReviewSchema = z.object({
  userId: uuidSchema,
  decision: z.enum(["approve", "reject", "resubmit"]),
  reason: reasonSchema,
});
const reportSchema = z.object({
  reportId: uuidSchema,
  action: z.enum(["actioned", "dismissed"]),
});
const photoReviewSchema = z.object({
  photoId: uuidSchema,
  decision: z.enum(["approve", "reject"]),
  reason: reasonSchema,
});
const campaignSchema = z.object({
  title: z.string().trim().min(3).max(120),
  body: z.string().trim().min(3).max(500),
  deepLink: z.string().trim().max(300).optional().default(""),
  audience: z.enum(["all", "active_7d", "subscribers", "country"]).default("all"),
  countryCode: z.string().trim().max(2).optional().default(""),
  scheduledAt: z.string().trim().optional(),
});
const contentSchema = z.object({
  slug: z.string().trim().min(2).max(120),
  locale: z.string().trim().min(2).max(12).default("en"),
  title: z.string().trim().min(2).max(160),
  body: z.string().trim().min(10),
});
const contentStatusSchema = z.object({
  pageId: uuidSchema,
  status: z.enum(["draft", "published", "archived"]),
});
const successStorySchema = z.object({
  coupleName: z.string().trim().min(2).max(160),
  countryCode: z.string().trim().max(2).optional().default(""),
  story: z.string().trim().min(20),
  photoPath: z.string().trim().max(500).optional().default(""),
});
const successStoryReviewSchema = z.object({
  storyId: uuidSchema,
  status: z.enum(["published", "rejected", "archived"]),
});
const staffSchema = z.object({
  email: z.string().trim().email(),
  role: z.enum(["support", "moderator", "super_admin"]),
});
const staffUpdateSchema = z.object({
  userId: uuidSchema,
  role: z.enum(["support", "moderator", "super_admin"]),
  status: z.enum(["active", "revoked"]),
  mfaRequired: z.boolean(),
});

function assertRole(admin: CurrentAdmin, allowed: AdminRole[]) {
  if (!allowed.includes(admin.role)) {
    throw new Error("UNAUTHORIZED: Your staff role cannot perform this action.");
  }
}

function assertAccountActionRole(admin: CurrentAdmin, action: string) {
  if (["ban", "shadowban"].includes(action)) {
    assertRole(admin, ["super_admin"]);
    return;
  }
  assertRole(admin, ["super_admin", "moderator"]);
}

function formString(formData: FormData, key: string) {
  return String(formData.get(key) ?? "");
}

async function run(name: string, values: Record<string, unknown>, path: string) {
  const supabase = await createClient();
  const { error } = await supabase.rpc(name, values);
  if (error) throw new Error(error.message);
  revalidatePath(path);
  revalidatePath("/dashboard");
}

export async function accountAction(formData: FormData) {
  const admin = await requireAdmin();
  const parsed = accountActionSchema.parse({
    userId: formData.get("userId"),
    action: formData.get("action"),
    reason: formData.get("reason"),
  });
  assertAccountActionRole(admin, parsed.action);
  await run("admin_account_action", { p_user_id: parsed.userId, p_action: parsed.action, p_reason: parsed.reason }, "/users");
}
export async function bulkAccountAction(formData: FormData) {
  const admin = await requireAdmin();
  const parsed = bulkAccountActionSchema.parse({
    userIds: formData.getAll("userIds"),
    action: formData.get("action"),
    reason: formData.get("reason"),
  });
  assertAccountActionRole(admin, parsed.action);
  await run("admin_bulk_account_action", {
    p_user_ids: parsed.userIds,
    p_action: parsed.action,
    p_reason: parsed.reason,
  }, "/users");
}
export async function reviewKyc(formData: FormData) {
  const admin = await requireAdmin();
  assertRole(admin, ["super_admin", "moderator"]);
  const parsed = kycReviewSchema.parse({
    userId: formData.get("userId"),
    decision: formData.get("decision"),
    reason: formData.get("reason"),
  });
  await run("admin_review_kyc", { p_user_id: parsed.userId, p_decision: parsed.decision, p_reason: parsed.reason }, "/kyc");
}
export async function resolveReport(formData: FormData) {
  const admin = await requireAdmin();
  assertRole(admin, ["super_admin", "moderator"]);
  const parsed = reportSchema.parse({
    reportId: formData.get("reportId"),
    action: formData.get("action"),
  });
  await run("admin_resolve_report", { p_report_id: parsed.reportId, p_action: parsed.action }, "/moderation");
}
export async function reviewPhoto(formData: FormData) {
  const admin = await requireAdmin();
  assertRole(admin, ["super_admin", "moderator"]);
  const parsed = photoReviewSchema.parse({
    photoId: formData.get("photoId"),
    decision: formData.get("decision"),
    reason: formData.get("reason"),
  });
  await run("admin_review_photo", { p_photo_id: parsed.photoId, p_decision: parsed.decision, p_reason: parsed.reason }, "/moderation");
}
export async function createCampaign(formData: FormData) {
  const admin = await requireAdmin();
  assertRole(admin, ["super_admin"]);
  const parsed = campaignSchema.parse({
    title: formData.get("title"),
    body: formData.get("body"),
    deepLink: formData.get("deepLink"),
    audience: formData.get("audience") || "all",
    countryCode: formData.get("countryCode"),
    scheduledAt: formData.get("scheduledAt"),
  });
  await run("admin_create_push_campaign", {
    p_title: parsed.title,
    p_body: parsed.body,
    p_deep_link: parsed.deepLink,
    p_audience: parsed.audience,
    p_country_code: parsed.countryCode,
    p_scheduled_at: parsed.scheduledAt || new Date().toISOString(),
  }, "/campaigns");
}
export async function queueCampaign(formData: FormData) {
  const admin = await requireAdmin();
  assertRole(admin, ["super_admin"]);
  await run("admin_queue_push_campaign", { p_campaign_id: uuidSchema.parse(formData.get("campaignId")) }, "/campaigns");
}
export async function upsertContentPage(formData: FormData) {
  const admin = await requireAdmin();
  assertRole(admin, ["super_admin", "moderator"]);
  const parsed = contentSchema.parse({
    slug: formData.get("slug"),
    locale: formData.get("locale") || "en",
    title: formData.get("title"),
    body: formData.get("body"),
  });
  await run("admin_upsert_content_page", {
    p_slug: parsed.slug,
    p_locale: parsed.locale,
    p_title: parsed.title,
    p_body: parsed.body,
  }, "/content");
}
export async function setContentStatus(formData: FormData) {
  const admin = await requireAdmin();
  assertRole(admin, ["super_admin", "moderator"]);
  const parsed = contentStatusSchema.parse({
    pageId: formData.get("pageId"),
    status: formData.get("status"),
  });
  await run("admin_set_content_status", { p_page_id: parsed.pageId, p_status: parsed.status }, "/content");
}
export async function addSuccessStory(formData: FormData) {
  const admin = await requireAdmin();
  assertRole(admin, ["super_admin", "moderator"]);
  const parsed = successStorySchema.parse({
    coupleName: formData.get("coupleName"),
    countryCode: formData.get("countryCode"),
    story: formData.get("story"),
    photoPath: formData.get("photoPath"),
  });
  await run("admin_add_success_story", {
    p_couple_name: parsed.coupleName,
    p_country_code: parsed.countryCode,
    p_story: parsed.story,
    p_photo_path: parsed.photoPath,
  }, "/stories");
}
export async function reviewSuccessStory(formData: FormData) {
  const admin = await requireAdmin();
  assertRole(admin, ["super_admin", "moderator"]);
  const parsed = successStoryReviewSchema.parse({
    storyId: formData.get("storyId"),
    status: formData.get("status"),
  });
  await run("admin_review_success_story", { p_story_id: parsed.storyId, p_status: parsed.status }, "/stories");
}
export async function addStaffMember(formData: FormData) {
  const admin = await requireAdmin();
  assertRole(admin, ["super_admin"]);
  const parsed = staffSchema.parse({
    email: formData.get("email"),
    role: formData.get("role"),
  });
  await run("admin_add_staff_member", {
    p_email: parsed.email,
    p_role: parsed.role,
  }, "/staff");
}

export async function inviteStaffMember(formData: FormData) {
  const admin = await requireAdmin();
  assertRole(admin, ["super_admin"]);
  const parsed = staffSchema.safeParse({
    email: formData.get("email"),
    role: formData.get("role"),
  });
  if (!parsed.success) throw new Error("Enter a valid staff email and role.");

  const adminClient = createAdminClient();
  const redirectBase =
    process.env.NEXT_PUBLIC_ADMIN_SITE_URL ??
    (process.env.VERCEL_PROJECT_PRODUCTION_URL
      ? `https://${process.env.VERCEL_PROJECT_PRODUCTION_URL}`
      : "http://localhost:3001");

  const { error } = await adminClient.auth.admin.inviteUserByEmail(
    parsed.data.email,
    {
      data: { staff: true, role: parsed.data.role },
      redirectTo: `${redirectBase}/login`,
    },
  );

  const message = error?.message.toLowerCase() ?? "";
  if (error && !message.includes("already") && !message.includes("registered")) {
    throw new Error(error.message);
  }

  await run("admin_add_staff_member", {
    p_email: parsed.data.email,
    p_role: parsed.data.role,
  }, "/staff");
}
export async function updateStaffMember(formData: FormData) {
  const admin = await requireAdmin();
  assertRole(admin, ["super_admin"]);
  const parsed = staffUpdateSchema.parse({
    userId: formData.get("userId"),
    role: formData.get("role"),
    status: formData.get("status"),
    mfaRequired: formData.get("mfaRequired") === "on",
  });
  await run("admin_update_staff_member", {
    p_user_id: parsed.userId,
    p_role: parsed.role,
    p_status: parsed.status,
    p_mfa_required: parsed.mfaRequired,
  }, "/staff");
}
export async function markAdminNotificationRead(formData: FormData) {
  await requireAdmin();
  await run("admin_mark_notification_read", {
    p_notification_id: uuidSchema.parse(formString(formData, "notificationId")),
  }, "/inbox");
}
export async function markAllAdminNotificationsRead() {
  await requireAdmin();
  await run("admin_mark_all_notifications_read", {}, "/inbox");
}
