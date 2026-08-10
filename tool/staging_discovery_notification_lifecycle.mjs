#!/usr/bin/env node

// Disposable, production-refusing verification of the complete
// zero-to-available notification transition. It creates two isolated members,
// proves the viewer's exact filtered feed is empty, activates one compatible
// profile, observes the generic notification, verifies the feed, then removes
// every Auth, database, notification, and Storage fixture.

const productionRef = "jukpscfxzwttgtxvrbmj";
const required = [
  "STAGING_SUPABASE_URL",
  "STAGING_SUPABASE_ANON_KEY",
  "STAGING_SUPABASE_SERVICE_ROLE_KEY",
  "STAGING_PROJECT_REF",
  "PRODUCTION_PROJECT_REF",
];
for (const name of required) {
  if (!process.env[name]) throw new Error(`Missing ${name}`);
}

const baseUrl = process.env.STAGING_SUPABASE_URL.replace(/\/$/, "");
const stagingRef = process.env.STAGING_PROJECT_REF;
if (
  stagingRef === productionRef ||
  stagingRef === process.env.PRODUCTION_PROJECT_REF ||
  new URL(baseUrl).hostname !== `${stagingRef}.supabase.co`
) {
  throw new Error("Safety stop: this lifecycle may run only on staging");
}

const anon = process.env.STAGING_SUPABASE_ANON_KEY;
const service = process.env.STAGING_SUPABASE_SERVICE_ROLE_KEY;
const runId = `${Date.now()}-${crypto.randomUUID().slice(0, 8)}`;
const fixtureBytes = Buffer.from(
  "/9j/4AAQSkZJRgABAQAAAQABAAD/2wBDAP//////////////////////////////////////////////////////////////////////////////////////2wBDAf//////////////////////////////////////////////////////////////////////////////////////wAARCAABAAEDASIAAhEBAxEB/8QAFQABAQAAAAAAAAAAAAAAAAAAAAX/xAAUEAEAAAAAAAAAAAAAAAAAAAAA/9oADAMBAAIQAxAAAAF//8QAFBABAAAAAAAAAAAAAAAAAAAAAP/aAAgBAQABBQJ//8QAFBEBAAAAAAAAAAAAAAAAAAAAAP/aAAgBAwEBPwF//8QAFBEBAAAAAAAAAAAAAAAAAAAAAP/aAAgBAgEBPwF//8QAFBABAAAAAAAAAAAAAAAAAAAAAP/aAAgBAQAGPwJ//8QAFBABAAAAAAAAAAAAAAAAAAAAAP/aAAgBAQABPyF//9oADAMBAAIAAwAAABAf/8QAFBEBAAAAAAAAAAAAAAAAAAAAAP/aAAgBAwEBPxB//8QAFBEBAAAAAAAAAAAAAAAAAAAAAP/aAAgBAgEBPxB//8QAFBABAAAAAAAAAAAAAAAAAAAAAP/aAAgBAQABPxB//9k=",
  "base64",
);
const created = { users: [], storage: [] };

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

async function request(
  path,
  { token, apiKey, method = "GET", body, contentType = "application/json", prefer } = {},
) {
  const key = apiKey ?? anon;
  const response = await fetch(`${baseUrl}${path}`, {
    method,
    headers: {
      apikey: key,
      Authorization: `Bearer ${token ?? key}`,
      "Content-Type": contentType,
      ...(prefer ? { Prefer: prefer } : {}),
    },
    body: body === undefined
      ? undefined
      : contentType === "application/json"
      ? JSON.stringify(body)
      : body,
  });
  const text = await response.text();
  let data = null;
  if (text) {
    try {
      data = JSON.parse(text);
    } catch {
      data = text;
    }
  }
  if (!response.ok) {
    throw new Error(
      data?.message ?? data?.error_description ?? data?.error ??
        (typeof data === "string" ? data : `HTTP ${response.status}`),
    );
  }
  return data;
}

async function createAuthMember(label) {
  const email = `availability.${label}.${runId}@staging.silarah.invalid`;
  const password = `Av-${crypto.randomUUID()}-aA7!`;
  const auth = await request("/auth/v1/admin/users", {
    apiKey: service,
    method: "POST",
    body: {
      email,
      password,
      email_confirm: true,
      user_metadata: { staging_availability_run: runId },
    },
  });
  const id = auth?.id ?? auth?.user?.id;
  assert(id, `Unable to create ${label} Auth member`);
  created.users.push(id);
  const session = await request("/auth/v1/token?grant_type=password", {
    method: "POST",
    body: { email, password },
  });
  assert(session?.access_token, `Unable to authenticate ${label}`);
  return { id, email, token: session.access_token };
}

async function insert(table, body, returning = false) {
  const rows = await request(`/rest/v1/${table}`, {
    apiKey: service,
    method: "POST",
    body,
    prefer: returning ? "return=representation" : "return=minimal",
  });
  return returning ? rows?.[0] : null;
}

async function createProfile(member, { gender, country, language, visibility }) {
  await insert("users", {
    id: member.id,
    email: member.email,
    country_code: country,
    gender,
    preferred_language: "en",
    timezone: "UTC",
    subscription_status: gender === "male" ? "active" : "none",
    subscription_expires_at: gender === "male"
      ? new Date(Date.now() + 30 * 86_400_000).toISOString()
      : null,
    onboarding_step: 5,
    onboarding_completed: true,
  });
  const profile = await insert("profiles", {
    user_id: member.id,
    first_name: gender === "male" ? "AvailabilityViewer" : "AvailabilityCandidate",
    last_name: "Staging",
    date_of_birth: gender === "male" ? "1995-01-01" : "1997-01-01",
    gender,
    country_code: country,
    sect: "Sunni",
    deen_level: "practicing",
    education_level: "Graduate",
    education_rank: 5,
    profession: "Engineer",
    family_type: "nuclear",
    previously_married: "no",
    children_count: 0,
    bio: "Disposable staging availability fixture.",
    languages: [language, "English"],
    interests: ["Family", "Reading"],
    height_cm: gender === "male" ? 176 : 164,
    photo_privacy: "public",
    visibility,
    onboarding_step: 14,
    onboarding_completed: true,
    completeness_score: 100,
    approved_at: new Date().toISOString(),
    last_active_at: new Date().toISOString(),
    mother_tongue: language,
    community: "South Asian",
    quran_memorization: "some_surahs",
    marriage_timeline: "1_year",
    willing_to_relocate: "open_to_discussion",
    living_expectation: "open_to_discussion",
  }, true);
  assert(profile?.id, `Unable to create ${gender} profile`);

  const path = `${member.id}/availability-${runId}.jpg`;
  await request(`/storage/v1/object/profile-photos/${path}`, {
    apiKey: service,
    method: "POST",
    body: fixtureBytes,
    contentType: "image/jpeg",
  });
  created.storage.push(path);
  await insert("photos", {
    profile_id: profile.id,
    storage_path: path,
    status: "active",
    order_index: 0,
    admin_approved: true,
    nsfw_cleared: true,
    moderation_status: "approved",
  });
  return profile;
}

async function feed(member, filters) {
  return await request("/rest/v1/rpc/get_discovery_feed", {
    token: member.token,
    method: "POST",
    body: {
      p_viewer_id: member.id,
      p_cursor_score: null,
      p_cursor_id: null,
      p_page_size: 20,
      p_filters: filters,
    },
  });
}

async function cleanup() {
  for (const path of created.storage) {
    await request(`/storage/v1/object/profile-photos/${path}`, {
      apiKey: service,
      method: "DELETE",
    }).catch(() => undefined);
  }
  for (const id of created.users) {
    await request(`/rest/v1/users?id=eq.${id}`, {
      apiKey: service,
      method: "DELETE",
      prefer: "return=minimal",
    }).catch(() => undefined);
    await request(`/auth/v1/admin/users/${id}`, {
      apiKey: service,
      method: "DELETE",
    }).catch(() => undefined);
  }
}

let failed = null;
try {
  const countryRows = await request(
    "/rest/v1/countries?select=iso_code&order=display_priority.desc.nullslast,name.asc&limit=1",
    { apiKey: service },
  );
  const country = countryRows?.[0]?.iso_code;
  assert(country, "Staging has no configured country");

  const uniqueLanguage = `Availability-${runId}`;
  const filters = {
    location_scope: "anywhere",
    anywhere: true,
    gender_pref: "female",
    mother_tongue: uniqueLanguage,
  };
  const viewer = await createAuthMember("viewer");
  await createProfile(viewer, {
    gender: "male",
    country,
    language: "English",
    visibility: "visible",
  });
  const candidate = await createAuthMember("candidate");
  const candidateProfile = await createProfile(candidate, {
    gender: "female",
    country,
    language: uniqueLanguage,
    visibility: "paused",
  });

  const before = await feed(viewer, filters);
  assert(Array.isArray(before) && before.length === 0, "Filtered feed was not empty before activation");
  await request("/rest/v1/rpc/record_discovery_inventory", {
    token: viewer.token,
    method: "POST",
    body: { p_filters: filters, p_has_profiles: false },
  });

  await request(`/rest/v1/profiles?id=eq.${candidateProfile.id}`, {
    apiKey: service,
    method: "PATCH",
    body: { visibility: "visible", approved_at: new Date().toISOString() },
    prefer: "return=minimal",
  });

  let notification = null;
  for (let attempt = 0; attempt < 30 && !notification; attempt += 1) {
    const rows = await request(
      `/rest/v1/notifications?user_id=eq.${viewer.id}&type=eq.new_compatible_profiles&select=title,body,deep_link,created_at&order=created_at.desc&limit=1`,
      { apiKey: service },
    );
    notification = rows?.[0] ?? null;
    if (!notification) await new Promise((resolve) => setTimeout(resolve, 1000));
  }
  assert(notification, "Availability notification was not queued within 30 seconds");
  assert(notification.deep_link === "silarah://discover", "Notification route was not canonical");
  assert(
    notification.title === "New compatible profiles are available",
    "Notification title was not generic",
  );
  const serialized = `${notification.title} ${notification.body}`.toLowerCase();
  assert(!serialized.includes("availabilitycandidate"), "Notification leaked the member name");
  assert(!serialized.includes(country.toLowerCase()), "Notification leaked the country");

  const after = await feed(viewer, filters);
  assert(
    after.some((row) => row.user_id === candidate.id),
    "Exact Discovery feed did not contain the activated candidate",
  );

  // The master preference is authoritative at generation and dispatch time.
  // Recreate the same empty-to-available transition with alerts disabled and
  // force a service-role worker pass so this negative assertion is deterministic.
  await request(`/rest/v1/profiles?id=eq.${candidateProfile.id}`, {
    apiKey: service,
    method: "PATCH",
    body: { visibility: "paused" },
    prefer: "return=minimal",
  });
  const emptyAgain = await feed(viewer, filters);
  assert(emptyAgain.length === 0, "Feed did not return to empty for opt-out test");
  await request("/rest/v1/notification_prefs?on_conflict=user_id", {
    token: viewer.token,
    method: "POST",
    body: {
      user_id: viewer.id,
      new_compatible_profiles: false,
      discovery_digest_frequency: "weekly",
    },
    prefer: "resolution=merge-duplicates,return=minimal",
  });
  await request("/rest/v1/rpc/record_discovery_inventory", {
    token: viewer.token,
    method: "POST",
    body: { p_filters: filters, p_has_profiles: false },
  });
  await request(`/rest/v1/profiles?id=eq.${candidateProfile.id}`, {
    apiKey: service,
    method: "PATCH",
    body: { visibility: "visible", approved_at: new Date().toISOString() },
    prefer: "return=minimal",
  });
  await request(
    "/rest/v1/rpc/process_discovery_availability_notifications",
    {
      apiKey: service,
      method: "POST",
      body: { p_batch_size: 10 },
    },
  );
  const notificationRows = await request(
    `/rest/v1/notifications?user_id=eq.${viewer.id}&type=eq.new_compatible_profiles&select=id`,
    { apiKey: service },
  );
  assert(
    notificationRows.length === 1,
    "Opted-out member received another compatible-profile notification",
  );

  console.log(JSON.stringify({
    status: "passed",
    transition: "empty -> compatible profile active -> generic alert -> exact feed result",
    deepLink: notification.deep_link,
    optOut: "verified",
    cleanup: "pending",
  }));
} catch (error) {
  failed = error;
  console.error(error instanceof Error ? error.message : String(error));
} finally {
  await cleanup();
}

if (failed) process.exitCode = 1;
else console.log(JSON.stringify({ status: "cleanup-complete", users: created.users.length }));
