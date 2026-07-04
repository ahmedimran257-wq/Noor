"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { z, ZodError } from "zod";
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
const messageReportSchema = z.object({
  reportId: uuidSchema,
  action: z.enum(["reviewed", "actioned", "dismissed"]),
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

async function run(name: string, values: Record<string, unknown>) {
  const supabase = await createClient();
  const { error } = await supabase.rpc(name, values);
  if (error) throw new Error(error.message);
}

async function claimWorkItem(itemType: "kyc" | "report" | "photo" | "message_report", itemId: string) {
  await run("admin_claim_work_item", {
    p_item_type: itemType,
    p_item_id: itemId,
  });
}

function actionMessage(error: unknown) {
  if (error instanceof ZodError) {
    return error.issues[0]?.message ?? "Check the form and try again.";
  }
  if (error instanceof Error) return error.message;
  return "The action could not be completed.";
}

function isNextRedirect(error: unknown) {
  return (
    typeof error === "object" &&
    error !== null &&
    "digest" in error &&
    String((error as { digest?: unknown }).digest).startsWith("NEXT_REDIRECT")
  );
}

function withNotice(path: string, key: "admin_error" | "admin_success", message: string): never {
  redirect(`${path}?${key}=${encodeURIComponent(message)}`);
}

async function guardedAction(
  path: string,
  work: () => Promise<void>,
  successMessage = "Action completed.",
) {
  try {
    await work();
  } catch (error) {
    if (isNextRedirect(error)) throw error;
    withNotice(path, "admin_error", actionMessage(error));
  }
  revalidatePath(path);
  revalidatePath("/dashboard");
  withNotice(path, "admin_success", successMessage);
}

export async function accountAction(formData: FormData) {
  await guardedAction("/users", async () => {
    const admin = await requireAdmin();
    const parsed = accountActionSchema.parse({
      userId: formData.get("userId"),
      action: formData.get("action"),
      reason: formString(formData, "reason"),
    });
    assertAccountActionRole(admin, parsed.action);
    await run("admin_account_action", { p_user_id: parsed.userId, p_action: parsed.action, p_reason: parsed.reason });
  });
}
export async function bulkAccountAction(formData: FormData) {
  await guardedAction("/users", async () => {
    const admin = await requireAdmin();
    const parsed = bulkAccountActionSchema.parse({
      userIds: formData.getAll("userIds"),
      action: formData.get("action"),
      reason: formString(formData, "reason"),
    });
    assertAccountActionRole(admin, parsed.action);
    await run("admin_bulk_account_action", {
      p_user_ids: parsed.userIds,
      p_action: parsed.action,
      p_reason: parsed.reason,
    });
  }, "Bulk action completed.");
}
export async function reviewKyc(formData: FormData) {
  await guardedAction("/kyc", async () => {
    const admin = await requireAdmin();
    assertRole(admin, ["super_admin", "moderator"]);
    const parsed = kycReviewSchema.parse({
      userId: formData.get("userId"),
      decision: formData.get("decision"),
      reason: formString(formData, "reason"),
    });
    await claimWorkItem("kyc", parsed.userId);
    await run("admin_review_kyc", { p_user_id: parsed.userId, p_decision: parsed.decision, p_reason: parsed.reason });
  }, "KYC decision saved.");
}
export async function resolveReport(formData: FormData) {
  await guardedAction("/moderation", async () => {
    const admin = await requireAdmin();
    assertRole(admin, ["super_admin", "moderator"]);
    const parsed = reportSchema.parse({
      reportId: formData.get("reportId"),
      action: formData.get("action"),
    });
    await claimWorkItem("report", parsed.reportId);
    await run("admin_resolve_report", { p_report_id: parsed.reportId, p_action: parsed.action });
  }, "Report decision saved.");
}
export async function resolveMessageReport(formData: FormData) {
  await guardedAction("/moderation", async () => {
    const admin = await requireAdmin();
    assertRole(admin, ["super_admin", "moderator"]);
    const parsed = messageReportSchema.parse({
      reportId: formData.get("reportId"),
      action: formData.get("action"),
    });
    await claimWorkItem("message_report", parsed.reportId);
    await run("admin_resolve_message_report", {
      p_report_id: parsed.reportId,
      p_action: parsed.action,
    });
  }, "Message report decision saved.");
}
export async function reviewPhoto(formData: FormData) {
  await guardedAction("/moderation", async () => {
    const admin = await requireAdmin();
    assertRole(admin, ["super_admin", "moderator"]);
    const parsed = photoReviewSchema.parse({
      photoId: formData.get("photoId"),
      decision: formData.get("decision"),
      reason: formString(formData, "reason"),
    });
    await claimWorkItem("photo", parsed.photoId);
    await run("admin_review_photo", { p_photo_id: parsed.photoId, p_decision: parsed.decision, p_reason: parsed.reason });
  }, "Photo decision saved.");
}
export async function createCampaign(formData: FormData) {
  await guardedAction("/campaigns", async () => {
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
    });
  }, "Campaign created.");
}
export async function queueCampaign(formData: FormData) {
  await guardedAction("/campaigns", async () => {
    const admin = await requireAdmin();
    assertRole(admin, ["super_admin"]);
    await run("admin_queue_push_campaign", { p_campaign_id: uuidSchema.parse(formData.get("campaignId")) });
  }, "Campaign queued.");
}
export async function upsertContentPage(formData: FormData) {
  await guardedAction("/content", async () => {
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
    });
  }, "Content saved.");
}
export async function setContentStatus(formData: FormData) {
  await guardedAction("/content", async () => {
    const admin = await requireAdmin();
    assertRole(admin, ["super_admin", "moderator"]);
    const parsed = contentStatusSchema.parse({
      pageId: formData.get("pageId"),
      status: formData.get("status"),
    });
    await run("admin_set_content_status", { p_page_id: parsed.pageId, p_status: parsed.status });
  }, "Content status updated.");
}
export async function addSuccessStory(formData: FormData) {
  await guardedAction("/stories", async () => {
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
    });
  }, "Story added.");
}
export async function reviewSuccessStory(formData: FormData) {
  await guardedAction("/stories", async () => {
    const admin = await requireAdmin();
    assertRole(admin, ["super_admin", "moderator"]);
    const parsed = successStoryReviewSchema.parse({
      storyId: formData.get("storyId"),
      status: formData.get("status"),
    });
    await run("admin_review_success_story", { p_story_id: parsed.storyId, p_status: parsed.status });
  }, "Story reviewed.");
}
export async function addStaffMember(formData: FormData) {
  await guardedAction("/staff", async () => {
    const admin = await requireAdmin();
    assertRole(admin, ["super_admin"]);
    const parsed = staffSchema.parse({
      email: formData.get("email"),
      role: formData.get("role"),
    });
    await run("admin_add_staff_member", {
      p_email: parsed.email,
      p_role: parsed.role,
    });
  }, "Staff member added.");
}

export async function inviteStaffMember(formData: FormData) {
  await guardedAction("/staff", async () => {
    const admin = await requireAdmin();
    assertRole(admin, ["super_admin"]);
    const parsed = staffSchema.parse({
      email: formData.get("email"),
      role: formData.get("role"),
    });

    const adminClient = createAdminClient();
    const redirectBase = adminSiteUrl();

    const { error } = await adminClient.auth.admin.inviteUserByEmail(
      parsed.email,
      {
        data: { staff: true, role: parsed.role },
        redirectTo: `${redirectBase}/login`,
      },
    );

    const message = error?.message.toLowerCase() ?? "";
    if (error && !message.includes("already") && !message.includes("registered")) {
      throw new Error(error.message);
    }

    await run("admin_add_staff_member", {
      p_email: parsed.email,
      p_role: parsed.role,
    });
  }, "Staff invite sent.");
}
export async function updateStaffMember(formData: FormData) {
  await guardedAction("/staff", async () => {
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
    });
  }, "Staff member updated.");
}
export async function markAdminNotificationRead(formData: FormData) {
  await guardedAction("/inbox", async () => {
    await requireAdmin();
    await run("admin_mark_notification_read", {
      p_notification_id: uuidSchema.parse(formString(formData, "notificationId")),
    });
  }, "Notification marked read.");
}
export async function markAllAdminNotificationsRead() {
  await guardedAction("/inbox", async () => {
    await requireAdmin();
    await run("admin_mark_all_notifications_read", {});
  }, "All notifications marked read.");
}

function adminSiteUrl() {
  if (process.env.NEXT_PUBLIC_ADMIN_SITE_URL) {
    return process.env.NEXT_PUBLIC_ADMIN_SITE_URL.replace(/\/$/, "");
  }
  if (process.env.VERCEL_PROJECT_PRODUCTION_URL) {
    return `https://${process.env.VERCEL_PROJECT_PRODUCTION_URL}`;
  }
  if (process.env.NODE_ENV !== "production") {
    return "http://localhost:3001";
  }
  throw new Error("NEXT_PUBLIC_ADMIN_SITE_URL is required before staff invites can be sent in production.");
}
