#!/usr/bin/env node

// Disposable, production-refusing staging matrix for discovery scale and
// entitlement behavior. The fixture always contains exactly 200 members and
// is removed in finally, including Auth accounts and Storage objects.

import { mkdirSync, writeFileSync } from "node:fs";
import { dirname, resolve } from "node:path";

const PROFILE_COUNT = 200;
const KNOWN_PRODUCTION_REF = "jukpscfxzwttgtxvrbmj";
const FIXTURE_DOMAIN = "@staging.silarah.invalid";
const STALE_FIXTURE_AGE_MS = 6 * 60 * 60 * 1000;
const required = [
  "STAGING_SUPABASE_URL",
  "STAGING_SUPABASE_ANON_KEY",
  "STAGING_SUPABASE_SERVICE_ROLE_KEY",
  "STAGING_PROJECT_REF",
  "PRODUCTION_PROJECT_REF",
];

for (const name of required) {
  if (!process.env[name]) {
    throw new Error(`Missing required environment variable: ${name}`);
  }
}

const env = process.env;
const baseUrl = env.STAGING_SUPABASE_URL.replace(/\/$/, "");
const stagingHost = new URL(baseUrl).hostname;
if (
  env.STAGING_PROJECT_REF === env.PRODUCTION_PROJECT_REF ||
  env.STAGING_PROJECT_REF === KNOWN_PRODUCTION_REF ||
  stagingHost.startsWith(`${KNOWN_PRODUCTION_REF}.`)
) {
  throw new Error("Refusing to create 200 test profiles in production");
}
if (!stagingHost.startsWith(`${env.STAGING_PROJECT_REF}.`)) {
  throw new Error("STAGING_SUPABASE_URL does not match STAGING_PROJECT_REF");
}

const service = env.STAGING_SUPABASE_SERVICE_ROLE_KEY;
const anon = env.STAGING_SUPABASE_ANON_KEY;
const runId = `${Date.now()}-${Math.random().toString(36).slice(2, 10)}`;
const reportPath = resolve(
  process.env.STAGING_REPORT_PATH ?? "build/staging-200-profile-report.json",
);
const fixtureImageBytes = Buffer.from(
  "/9j/4AAQSkZJRgABAQAAAQABAAD/2wBDAP//////////////////////////////////////////////////////////////////////////////////////2wBDAf//////////////////////////////////////////////////////////////////////////////////////wAARCAABAAEDASIAAhEBAxEB/8QAFQABAQAAAAAAAAAAAAAAAAAAAAX/xAAUEAEAAAAAAAAAAAAAAAAAAAAA/9oADAMBAAIQAxAAAAF//8QAFBABAAAAAAAAAAAAAAAAAAAAAP/aAAgBAQABBQJ//8QAFBEBAAAAAAAAAAAAAAAAAAAAAP/aAAgBAwEBPwF//8QAFBEBAAAAAAAAAAAAAAAAAAAAAP/aAAgBAgEBPwF//8QAFBABAAAAAAAAAAAAAAAAAAAAAP/aAAgBAQAGPwJ//8QAFBABAAAAAAAAAAAAAAAAAAAAAP/aAAgBAQABPyF//9oADAMBAAIAAwAAABAf/8QAFBEBAAAAAAAAAAAAAAAAAAAAAP/aAAgBAwEBPxB//8QAFBEBAAAAAAAAAAAAAAAAAAAAAP/aAAgBAgEBPxB//8QAFBABAAAAAAAAAAAAAAAAAAAAAP/aAAgBAQABPxB//9k=",
  "base64",
);

const created = {
  authUserIds: [],
  profileIds: [],
  storagePaths: [],
  fixtureCityIds: [],
};
const report = {
  runId,
  target: stagingHost,
  requestedProfiles: PROFILE_COUNT,
  startedAt: new Date().toISOString(),
  status: "running",
  distribution: {},
  tests: [],
  cleanup: { attempted: false, completed: false },
};
const continuingFailures = [];

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

function errorMessage(error) {
  return error instanceof Error ? error.message : String(error);
}

async function request(
  path,
  {
    token,
    apiKey,
    method = "GET",
    body,
    prefer,
    contentType = "application/json",
  } = {},
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
    const message = data?.message ??
      data?.error_description ??
      data?.error ??
      (typeof data === "string" ? data : `HTTP ${response.status}`);
    const error = new Error(message);
    error.status = response.status;
    error.data = data;
    throw error;
  }
  return data;
}

async function test(name, action, { continueOnFailure = true } = {}) {
  const started = performance.now();
  try {
    const details = (await action()) ?? {};
    const durationMs = Math.round(performance.now() - started);
    report.tests.push({ name, status: "passed", durationMs, ...details });
    console.log(`PASS: ${name} (${durationMs} ms)`);
    return details;
  } catch (error) {
    const durationMs = Math.round(performance.now() - started);
    report.tests.push({
      name,
      status: "failed",
      durationMs,
      error: errorMessage(error),
    });
    console.error(`FAIL: ${name} (${durationMs} ms): ${errorMessage(error)}`);
    if (continueOnFailure) {
      continuingFailures.push({ name, error: errorMessage(error) });
      return {};
    }
    throw error;
  }
}

async function expectRejected(action, expectedFragment, message) {
  try {
    await action();
  } catch (error) {
    if (expectedFragment) {
      const serialized = JSON.stringify(error.data ?? errorMessage(error));
      assert(
        serialized.toLowerCase().includes(expectedFragment.toLowerCase()),
        `${message}: received ${serialized}`,
      );
    }
    return;
  }
  throw new Error(message);
}

async function mapConcurrent(items, concurrency, action) {
  const results = new Array(items.length);
  let cursor = 0;
  async function worker() {
    while (cursor < items.length) {
      const index = cursor;
      cursor += 1;
      results[index] = await action(items[index], index);
    }
  }
  await Promise.all(
    Array.from({ length: Math.min(concurrency, items.length) }, worker),
  );
  return results;
}

function chunks(items, size) {
  const result = [];
  for (let index = 0; index < items.length; index += size) {
    result.push(items.slice(index, index + size));
  }
  return result;
}

async function insertRows(
  table,
  rows,
  { returning = false, onConflict } = {},
) {
  const inserted = [];
  for (const batch of chunks(rows, 40)) {
    const path = onConflict
      ? `/rest/v1/${table}?on_conflict=${encodeURIComponent(onConflict)}`
      : `/rest/v1/${table}`;
    const data = await request(path, {
      apiKey: service,
      method: "POST",
      prefer: [
        onConflict ? "resolution=merge-duplicates" : null,
        returning ? "return=representation" : "return=minimal",
      ]
        .filter(Boolean)
        .join(","),
      body: batch,
    });
    if (returning && Array.isArray(data)) inserted.push(...data);
  }
  return inserted;
}

async function deleteWhere(table, query) {
  await request(`/rest/v1/${table}?${query}`, {
    apiKey: service,
    method: "DELETE",
    prefer: "return=minimal",
  });
}

async function listAuthUsers() {
  const users = [];
  for (let page = 1; page <= 20; page += 1) {
    const data = await request(`/auth/v1/admin/users?page=${page}&per_page=1000`, {
      apiKey: service,
    });
    const batch = Array.isArray(data) ? data : (data?.users ?? []);
    users.push(...batch);
    if (batch.length < 1000) return users;
  }
  throw new Error("Auth fixture scan exceeded the 20,000-user safety bound");
}

function isMatrixFixture(user) {
  return Boolean(
    user?.id &&
      user?.email?.toLowerCase().endsWith(FIXTURE_DOMAIN) &&
      user?.user_metadata?.staging_matrix_run,
  );
}

async function removeStaleMatrixFixtures() {
  const cutoff = Date.now() - STALE_FIXTURE_AGE_MS;
  const stale = (await listAuthUsers()).filter((user) => {
    const createdAt = Date.parse(user.created_at ?? "");
    return isMatrixFixture(user) && Number.isFinite(createdAt) && createdAt < cutoff;
  });
  for (const ids of chunks(stale.map((user) => user.id), 25)) {
    await deleteWhere("users", `id=in.(${ids.join(",")})`);
  }
  await mapConcurrent(stale, 10, async (user) => {
    await request(`/auth/v1/admin/users/${user.id}`, {
      apiKey: service,
      method: "DELETE",
    });
  });
  const staleIds = new Set(stale.map((user) => user.id));
  const remaining = (await listAuthUsers()).filter((user) => staleIds.has(user.id));
  assert(remaining.length === 0, "Stale matrix fixtures remain after cleanup");
  return stale.length;
}

async function createAuthUser(member) {
  const data = await request("/auth/v1/admin/users", {
    apiKey: service,
    method: "POST",
    body: {
      email: member.email,
      password: member.password,
      email_confirm: true,
      user_metadata: { staging_matrix_run: runId },
    },
  });
  const id = data?.id ?? data?.user?.id;
  assert(id, `Auth user was not created for ${member.email}`);
  created.authUserIds.push(id);
  return { ...member, id };
}

async function signIn(member) {
  const data = await request("/auth/v1/token?grant_type=password", {
    method: "POST",
    body: { email: member.email, password: member.password },
  });
  assert(data?.access_token, `No access token for ${member.email}`);
  return { ...member, token: data.access_token };
}

async function uploadFixture(path) {
  let lastError;
  for (let attempt = 1; attempt <= 4; attempt += 1) {
    try {
      await request(`/storage/v1/object/profile-photos/${path}`, {
        apiKey: service,
        method: "POST",
        body: fixtureImageBytes,
        contentType: "image/jpeg",
      });
      lastError = null;
      break;
    } catch (error) {
      lastError = error;
      const transient = error?.status === 429 ||
        (error?.status >= 500 && /40P01|deadlock|database error/i.test(error.message));
      if (!transient || attempt === 4) throw error;
      await new Promise((resolveDelay) =>
        setTimeout(resolveDelay, 150 * 2 ** (attempt - 1))
      );
    }
  }
  if (lastError) throw lastError;
  created.storagePaths.push(path);
}

async function feed(actor, filters = {}, page = {}) {
  return request("/rest/v1/rpc/get_discovery_feed", {
    token: actor.token,
    method: "POST",
    body: {
      p_viewer_id: actor.id,
      p_cursor_score: page.score ?? null,
      p_cursor_id: page.id ?? null,
      p_page_size: page.size ?? 20,
      p_filters: filters,
    },
  });
}

async function feedLocationRows(rows) {
  const userIds = [...new Set(rows.map((row) => row.user_id).filter(Boolean))];
  if (userIds.length === 0) return [];
  const profiles = await request(
    `/rest/v1/profiles?user_id=in.(${userIds.join(",")})&select=user_id,city_id`,
    { apiKey: service },
  );
  const cityIds = [...new Set(profiles.map((row) => row.city_id).filter(Boolean))];
  const cities = cityIds.length === 0
    ? []
    : await request(
      `/rest/v1/cities?id=in.(${cityIds.join(",")})&select=id,region_id`,
      { apiKey: service },
    );
  const cityRegion = new Map(cities.map((row) => [row.id, row.region_id]));
  return profiles.map((row) => ({
    userId: row.user_id,
    cityId: row.city_id,
    regionId: cityRegion.get(row.city_id),
  }));
}

async function rpc(actor, name, body = {}) {
  return request(`/rest/v1/rpc/${name}`, {
    token: actor.token,
    method: "POST",
    body,
  });
}

function firstRow(data, label) {
  const row = Array.isArray(data) ? data[0] : data;
  assert(row, `${label} returned no row`);
  return row;
}

function profileAge(index) {
  return 22 + (index % 20);
}

function isoBirthday(age) {
  return `${new Date().getUTCFullYear() - age}-01-01`;
}

function groupCount(items, selector) {
  return Object.fromEntries(
    [
      ...items.reduce((map, item) => {
        const key = String(selector(item));
        map.set(key, (map.get(key) ?? 0) + 1);
        return map;
      }, new Map()).entries(),
    ].sort(([left], [right]) => left.localeCompare(right)),
  );
}

async function cleanup() {
  report.cleanup.attempted = true;
  if (created.storagePaths.length > 0) {
    for (const batch of chunks(created.storagePaths, 100)) {
      await request("/storage/v1/object/profile-photos", {
        apiKey: service,
        method: "DELETE",
        body: { prefixes: batch },
      });
    }
  }

  for (const ids of chunks(created.authUserIds, 25)) {
    const list = `(${ids.join(",")})`;
    await deleteWhere("message_reports", `reporter_id=in.${list}`);
    await deleteWhere("reports", `reporter_id=in.${list}`);
    await deleteWhere("blocks", `blocker_id=in.${list}`);
    await deleteWhere("messages", `sender_id=in.${list}`);
    await deleteWhere("interests", `sender_id=in.${list}`);
    await deleteWhere("matches", `user_a=in.${list}`);
    await deleteWhere("profiles", `user_id=in.${list}`);
    await deleteWhere("users", `id=in.${list}`);
  }

  await mapConcurrent(created.authUserIds, 10, async (id) => {
    await request(`/auth/v1/admin/users/${id}`, {
      apiKey: service,
      method: "DELETE",
    });
  });
  if (created.fixtureCityIds.length > 0) {
    for (const ids of chunks(created.fixtureCityIds, 100)) {
      await deleteWhere("cities", `id=in.(${ids.join(",")})`);
    }
  }
  const createdIds = new Set(created.authUserIds);
  const authLeft = (await listAuthUsers()).filter((user) => createdIds.has(user.id));
  assert(authLeft.length === 0, "Matrix Auth fixtures remain after cleanup");
  for (const ids of chunks(created.authUserIds, 25)) {
    const publicLeft = await request(
      `/rest/v1/users?id=in.(${ids.join(",")})&select=id`,
      { apiKey: service },
    );
    assert(publicLeft.length === 0, "Matrix public users remain after cleanup");
  }
  if (created.fixtureCityIds.length > 0) {
    const cityLeft = await request(
      `/rest/v1/cities?id=in.(${created.fixtureCityIds.join(",")})&select=id`,
      { apiKey: service },
    );
    assert(cityLeft.length === 0, "Matrix city fixtures remain after cleanup");
  }
  report.cleanup.completed = true;
  report.cleanup.deletedAuthUsers = created.authUserIds.length;
  report.cleanup.deletedStorageObjects = created.storagePaths.length;
  report.cleanup.deletedFixtureCities = created.fixtureCityIds.length;
}

let failure;
let members = [];

try {
  await test("remove stale staging matrix fixtures", async () => ({
    removed: await removeStaleMatrixFixtures(),
  }), { continueOnFailure: false });

  const india = await request(
    "/rest/v1/countries?iso_code=eq.IN&select=iso_code,name&limit=1",
    { apiKey: service },
  );
  assert(india.length === 1, "India is missing from the staging catalogue");

  const regions = await request(
    "/rest/v1/regions?country_code=eq.IN&select=id,name,country_code&order=name.asc&limit=100",
    { apiKey: service },
  );
  assert(
    regions.length >= 36,
    `Expected the India state/UT catalogue, found ${regions.length}`,
  );

  const regionIds = regions.map((region) => region.id);
  const existingCities = await request(
    `/rest/v1/cities?region_id=in.(${regionIds.join(",")})&select=id,name,region_id,latitude,longitude&limit=5000`,
    { apiKey: service },
  );
  const cityByRegion = new Map();
  for (const city of existingCities) {
    if (!cityByRegion.has(city.region_id)) cityByRegion.set(city.region_id, city);
  }
  const missingRegionCities = regions
    .filter((region) => !cityByRegion.has(region.id))
    .map((region, index) => ({
      region_id: region.id,
      name: `Matrix Fixture ${runId} ${index + 1}`,
      // Disposable staging-only coordinates distributed inside India. They
      // exercise PostGIS/state/city paths and are deleted in finally.
      latitude: 8.0 + (index % 20) * 1.2,
      longitude: 68.0 + (index % 18) * 1.8,
    }));
  if (missingRegionCities.length > 0) {
    const insertedCities = await insertRows("cities", missingRegionCities, {
      returning: true,
    });
    for (const city of insertedCities) {
      cityByRegion.set(city.region_id, city);
      created.fixtureCityIds.push(city.id);
    }
  }
  const locationFixtures = regions.map((region) => ({
    region,
    city: cityByRegion.get(region.id),
  }));
  assert(
    locationFixtures.every((location) => location.city),
    "Every Indian state/UT needs a disposable city fixture",
  );

  const seeds = Array.from({ length: PROFILE_COUNT }, (_, index) => {
    const gender = index % 2 === 0 ? "male" : "female";
    // The shared-city cohort is Premium so the notification test exercises
    // the same entitlement path sold to customers. The remainder preserves a
    // mixed free/Premium population for quota and paywall coverage.
    const premium = index < 30 || index % 8 === 0 || index % 8 === 1;
    // Keep a bounded same-city cohort for the new-compatible-member alert,
    // then distribute the remaining members across every Indian state/UT.
    const location = index < 30
      ? locationFixtures[0]
      : locationFixtures[1 + (Math.floor((index - 30) / 2) % (locationFixtures.length - 1))];
    return {
      index,
      gender,
      premium,
      countryCode: "IN",
      region: location.region,
      city: location.city,
      email: `matrix.${runId}.${
        String(index).padStart(3, "0")
      }@staging.silarah.invalid`,
      password: `Mx-${crypto.randomUUID()}-aA7!`,
    };
  });

  await test(
    "create exactly 200 isolated Auth accounts",
    async () => {
      members = await mapConcurrent(seeds, 8, createAuthUser);
      assert(
        members.length === PROFILE_COUNT,
        "Auth population is not exactly 200",
      );
      return { count: members.length };
    },
    { continueOnFailure: false },
  );

  const now = new Date();
  const users = members.map((member) => ({
    id: member.id,
    email: member.email,
    country_code: member.countryCode,
    gender: member.gender,
    preferred_language: ["en", "ur", "ar", "hi"][member.index % 4],
    timezone: "Asia/Kolkata",
    subscription_status: member.premium ? "active" : "none",
    subscription_expires_at: member.premium
      ? new Date(now.getTime() + 30 * 86_400_000).toISOString()
      : null,
    onboarding_step: 5,
    onboarding_completed: true,
  }));
  await insertRows("users", users);

  const sects = ["Sunni", "Shia", "Just Muslim"];
  const deenLevels = ["practicing", "moderate", "cultural"];
  const familyTypes = ["nuclear", "joint", "extended"];
  const maritalStatuses = ["no", "divorced", "widowed"];
  const tongues = [
    "Hindi",
    "Urdu",
    "Bengali",
    "Telugu",
    "Marathi",
    "Tamil",
    "Gujarati",
    "Kannada",
    "Malayalam",
    "English",
  ];
  const communities = [
    "Syed",
    "Sheikh",
    "Ansari",
    "Pathan",
    "Deccan Muslim",
    "Bengali Muslim",
    "Mappila",
    "Lebbai",
  ];
  const living = ["separate", "with_inlaws", "open_to_discussion"];
  const quran = ["none", "some_surahs", "partial", "hafiz"];
  const timelines = ["asap", "6_months", "1_year", "2_plus_years"];
  const relocation = ["yes", "no", "open_to_discussion"];

  const profileRows = members.map((member) => {
    const group = Math.floor(member.index / 2);
    const city = member.city;
    const recent = group % 4 !== 3;
    return {
      user_id: member.id,
      static_rank_score: member.index % 10,
      first_name: `Matrix${member.gender === "female" ? "F" : "M"}${
        String(member.index).padStart(3, "0")
      }`,
      last_name: "Staging",
      date_of_birth: isoBirthday(profileAge(member.index)),
      gender: member.gender,
      country_code: member.countryCode,
      city_id: city?.id ?? null,
      sect: sects[group % sects.length],
      deen_level: deenLevels[group % deenLevels.length],
      prays_five_daily: group % 2 === 0,
      education_level: `Level ${1 + (member.index % 7)}`,
      education_rank: 1 + (member.index % 7),
      profession: ["Engineer", "Teacher", "Designer", "Doctor"][group % 4],
      family_type: familyTypes[group % familyTypes.length],
      previously_married: maritalStatuses[group % maritalStatuses.length],
      children_count: group % 3 === 0 ? 1 : 0,
      bio: `Disposable staging matrix member ${member.index}.`,
      languages: [tongues[group % tongues.length], "English"],
      interests: ["Family", "Reading", `Matrix ${group % 5}`],
      height_cm: 150 + (member.index % 40),
      photo_privacy: "public",
      visibility: "visible",
      onboarding_step: 14,
      onboarding_completed: true,
      completeness_score: 100,
      is_verified: member.index % 4 < 2,
      approved_at: now.toISOString(),
      last_active_at: recent
        ? new Date(now.getTime() - (group % 10) * 3_600_000).toISOString()
        : new Date(now.getTime() - 30 * 86_400_000).toISOString(),
      mother_tongue: tongues[group % tongues.length],
      community: communities[group % communities.length],
      complexion: ["fair", "medium", "olive", "dark"][group % 4],
      diet_type: ["halal_only", "zabiha_strict", "vegetarian"][group % 3],
      smoking_habit: group % 5 === 0 ? "occasionally" : "never",
      quran_memorization: quran[group % quran.length],
      religious_education: ["self_taught", "madrasa", "none"][group % 3],
      marriage_timeline: timelines[group % timelines.length],
      willing_to_relocate: relocation[group % relocation.length],
      living_expectation: living[group % living.length],
    };
  });
  const insertedProfiles = await insertRows("profiles", profileRows, {
    returning: true,
  });
  assert(
    insertedProfiles.length === PROFILE_COUNT,
    "Profile population is not exactly 200",
  );
  const profileIdByUser = new Map(
    insertedProfiles.map((profile) => [profile.user_id, profile.id]),
  );
  created.profileIds.push(...insertedProfiles.map((profile) => profile.id));
  members = members.map((member) => ({
    ...member,
    profileId: profileIdByUser.get(member.id),
    profile: profileRows[member.index],
  }));

  await insertRows(
    "profile_preferences",
    members.map((member) => ({
      profile_id: member.profileId,
      preferred_age_min: 22,
      preferred_age_max: 45,
      preferred_countries: ["IN"],
      sect_preference: "any",
      deen_preference: "any",
      min_education_rank: 1,
      open_to_divorced: true,
      open_to_widowed: true,
      open_to_has_children: true,
      open_to_diaspora: false,
      preferred_mother_tongue: [],
      preferred_community: [],
      preferred_marriage_timeline: "no_preference",
      preferred_relocation: "no_preference",
      preferred_living_expectation: "no_preference",
    })),
    { onConflict: "profile_id" },
  );

  const photoRows = members.map((member) => ({
    profile_id: member.profileId,
    storage_path: `${member.id}/matrix-${runId}.jpg`,
    status: "active",
    order_index: 0,
    admin_approved: true,
    nsfw_cleared: true,
    moderation_status: "approved",
  }));
  // Storage metadata inserts can contend on a small Supabase staging tier.
  // Four workers exercise concurrency without manufacturing deadlocks that a
  // real client population naturally spreads over time.
  await mapConcurrent(photoRows, 4, async (photo) => {
    await uploadFixture(photo.storage_path);
  });
  await insertRows("photos", photoRows);

  report.distribution = {
    gender: groupCount(members, (member) => member.gender),
    country: groupCount(members, (member) => member.countryCode),
    state: groupCount(members, (member) => member.region.name),
    entitlement: groupCount(
      members,
      (member) => member.premium ? "premium" : "free",
    ),
    verified: groupCount(
      members,
      (member) => member.profile.is_verified ? "verified" : "unverified",
    ),
  };
  assert(report.distribution.gender.male === 100, "Expected 100 men");
  assert(report.distribution.gender.female === 100, "Expected 100 women");

  const maleFreeMembers = members.filter(
    (member) => member.gender === "male" && !member.premium,
  );
  const malePremiumMembers = members.filter(
    (member) => member.gender === "male" && member.premium,
  );
  const femaleFreeMembers = members.filter(
    (member) => member.gender === "female" && !member.premium,
  );
  const femalePremiumMembers = members.filter(
    (member) => member.gender === "female" && member.premium,
  );
  const signedActors = await mapConcurrent(
    [
      malePremiumMembers[0],
      maleFreeMembers[0],
      maleFreeMembers[1],
      maleFreeMembers[2],
      malePremiumMembers[1],
      femalePremiumMembers[0],
      femaleFreeMembers[0],
    ],
    7,
    signIn,
  );
  const [
    premiumMale,
    freeMale,
    freeViewMale,
    freeInterestMale,
    premiumInterestMale,
    premiumFemale,
    freeFemale,
  ] = signedActors;

  await test("population is visible live without a materialized refresh", async () => {
    const rows = await feed(premiumMale);
    assert(
      rows.length === 20,
      `Expected a full page of 20, received ${rows.length}`,
    );
    assert(
      rows.every((row) => row.gender === "female"),
      "Male feed mixed genders",
    );
    return { pageSize: rows.length };
  });

  await test("cursor pagination is stable and non-overlapping", async () => {
    const first = await feed(premiumMale);
    const cursor = first.at(-1);
    const second = await feed(premiumMale, {}, {
      score: cursor.rank_score,
      id: cursor.profile_id,
    });
    const firstIds = new Set(first.map((row) => row.profile_id));
    assert(second.length > 0, "Second discovery page was empty");
    assert(
      second.every((row) => !firstIds.has(row.profile_id)),
      "Discovery cursor returned duplicate profiles",
    );
    return { firstPage: first.length, secondPage: second.length };
  });

  await test("all demographic and lifestyle filters are server-enforced", async () => {
    const cases = [
      ["age", { age_min: 25, age_max: 25 }, (row) => row.age === 25],
      ["verified", { verified_only: true }, (row) => row.is_verified === true],
      ["sect", { sect: "Sunni" }, (row) => row.sect === "Sunni"],
      [
        "deen",
        { deen_level: "practicing" },
        (row) => row.deen_level === "practicing",
      ],
      [
        "family",
        { family_type: "nuclear" },
        (row) => row.family_type === "nuclear",
      ],
      [
        "marital",
        { marital_status: "divorced" },
        (row) => row.previously_married === "divorced",
      ],
      [
        "education",
        { education_min: 6 },
        (row) =>
          Number(
            members.find((member) => member.id === row.user_id)?.profile
              .education_rank ?? 0,
          ) >= 6,
      ],
      [
        "language",
        { mother_tongue: "English" },
        (row) => row.mother_tongue === "English",
      ],
      [
        "community",
        { community: "Syed" },
        (row) => row.community === "Syed",
      ],
      [
        "living",
        { living_expectation: "separate" },
        (row) => row.living_expectation === "separate",
      ],
      [
        "quran",
        { quran_memorization: "none" },
        (row) => row.quran_memorization === "none",
      ],
      [
        "timeline",
        { marriage_timeline: "asap" },
        (row) => row.marriage_timeline === "asap",
      ],
      [
        "relocation",
        { willing_to_relocate: "yes" },
        (row) => row.willing_to_relocate === "yes",
      ],
      [
        "children",
        { has_children: "yes" },
        (row) => Number(row.children_count) > 0,
      ],
      [
        "active",
        { active_recently: true },
        (row) =>
          new Date(row.last_active_at) >=
            new Date(Date.now() - 14 * 86_400_000),
      ],
    ];
    for (const [label, filters, predicate] of cases) {
      const rows = await feed(premiumMale, filters);
      assert(rows.length > 0, `${label} filter returned no fixture profiles`);
      assert(
        rows.every(predicate),
        `${label} filter returned a mismatched row`,
      );
    }
    return { filtersVerified: cases.length };
  });

  await test("free location filters are rejected and India Premium scopes work", async () => {
    await expectRejected(
      () => feed(freeMale, { location_scope: "same_country" }),
      "premium_filter_required",
      "Free member bypassed the Premium location gate",
    );
    const sameCountry = await feed(premiumMale, {
      location_scope: "same_country",
    });
    assert(
      sameCountry.length > 0,
      "Premium same-country filter returned no profiles",
    );
    assert(
      sameCountry.every((row) => row.country_code === premiumMale.countryCode),
      "Premium same-country filter crossed countries",
    );
    const stateRows = await feed(premiumMale, {
      state_name: premiumMale.region.name,
    });
    assert(stateRows.length > 0, "Premium state filter returned no profiles");
    const stateLocations = await feedLocationRows(stateRows);
    assert(
      stateLocations.length === stateRows.length &&
        stateLocations.every((row) => row.regionId === premiumMale.region.id),
      "Premium state filter crossed Indian states/UTs",
    );
    const cityRows = await feed(premiumMale, {
      state_name: premiumMale.region.name,
      city_id: String(premiumMale.city.id),
    });
    assert(cityRows.length > 0, "Premium city filter returned no profiles");
    const cityLocations = await feedLocationRows(cityRows);
    assert(
      cityLocations.length === cityRows.length &&
        cityLocations.every((row) => row.cityId === premiumMale.city.id),
      "Premium city filter crossed cities",
    );
    if (premiumMale.profile.city_id) {
      for (const scope of ["same_city", "same_region", "radius"]) {
        const filters = scope === "radius"
          ? { location_scope: scope, max_distance_km: 25 }
          : { location_scope: scope };
        const rows = await feed(premiumMale, filters);
        assert(rows.length > 0, `Premium ${scope} filter returned no profiles`);
      }
    }
    return {
      launchCountry: "IN",
      statesAndUnionTerritoriesVerified: regions.length,
    };
  });

  await test(
    "every Premium preference is enforced by the database",
    async () => {
      const premiumPreferences = [
        { verified_only: true },
        { mother_tongue: "Hindi" },
        { community: "Syed" },
        { living_expectation: "separate" },
      ];
      for (const filters of premiumPreferences) {
        await expectRejected(
          () => feed(freeMale, filters),
          "premium_filter_required",
          `Free member bypassed Premium filters: ${JSON.stringify(filters)}`,
        );
        const rows = await feed(premiumMale, filters);
        assert(
          rows.length > 0,
          `Premium filter returned no rows: ${JSON.stringify(filters)}`,
        );
      }
      return { premiumPreferencesVerified: premiumPreferences.length };
    },
    { continueOnFailure: true },
  );

  await test("name and city search returns eligible opposite profiles", async () => {
    const rows = await rpc(premiumMale, "search_profiles_by_name_city", {
      p_viewer_id: premiumMale.id,
      p_first_name: "MatrixF",
      p_city_id: null,
    });
    assert(rows.length > 0, "Profile search returned no women");
    assert(
      rows.every((row) => row.first_name.startsWith("MatrixF")),
      "Search prefix was not enforced",
    );
    return { results: rows.length };
  });

  await test("batched signed photo URLs resolve real Storage objects", async () => {
    const owners = femaleFreeMembers.slice(0, 5).map((member) => member.id);
    const data = await request("/functions/v1/get-signed-url", {
      token: premiumMale.token,
      method: "POST",
      body: {
        purpose: "read_profile_photos",
        owner_user_ids: owners,
        order_index: 0,
      },
    });
    assert(
      Object.keys(data?.urls ?? {}).length === owners.length,
      "Signed URL batch was incomplete",
    );
    for (const url of Object.values(data.urls)) {
      const response = await fetch(url);
      assert(response.ok, `Signed photo returned HTTP ${response.status}`);
      assert(
        (await response.arrayBuffer()).byteLength > 0,
        "Signed photo was empty",
      );
    }
    return { signedPhotos: owners.length };
  });

  await test(
    "compatible-profile notifications are exact, localized, private, deduplicated, and optional",
    async () => {
      const candidate = femalePremiumMembers.find(
        (member) => member.city.id === locationFixtures[0].city.id,
      );
      assert(candidate, "Same-city notification candidate is missing");
      const originalTongue = candidate.profile.mother_tongue;
      const uniqueTongue = `Availability-${runId}`;
      const localeCodes = [
        "en",
        "ar",
        "bn",
        "de",
        "fr",
        "hi",
        "id",
        "ms",
        "tr",
        "ur",
      ];
      const cohortMembers = members
        .filter(
          (member) =>
            member.gender === "male" &&
            member.city.id === candidate.city.id &&
            Date.parse(member.profile.last_active_at) >
              now.getTime() - 30 * 86_400_000,
        )
        .slice(0, 12);
      assert(cohortMembers.length === 12, "Notification cohort is incomplete");
      const cohort = await mapConcurrent(cohortMembers, 6, signIn);
      const optedIn = cohort.slice(0, 10);
      const optedOut = cohort.slice(10);
      const filters = {
        location_scope: "same_city",
        gender_pref: "female",
        mother_tongue: uniqueTongue,
      };

      // Keep the candidate outside Discovery while the viewers establish an
      // authoritative empty feed. Updating a paused profile cannot race the
      // availability worker.
      await request(`/rest/v1/profiles?id=eq.${candidate.profileId}`, {
        apiKey: service,
        method: "PATCH",
        body: { visibility: "paused", mother_tongue: uniqueTongue },
        prefer: "return=minimal",
      });

      // The bulk population legitimately enqueues one bounded availability
      // event per newly-live profile. Drain those staging-only events before
      // establishing the empty-inventory cohort so an older cursor cannot
      // race or partially consume the single transition under test.
      let completedDrainPasses = 0;
      let drainAttempts = 0;
      while (
        completedDrainPasses < PROFILE_COUNT + 10 &&
        drainAttempts < (PROFILE_COUNT + 10) * 3
      ) {
        drainAttempts += 1;
        const result = await request(
          "/rest/v1/rpc/process_discovery_availability_notifications",
          {
            apiKey: service,
            method: "POST",
            body: { p_batch_size: 40 },
          },
        );
        if (!result?.busy) completedDrainPasses += 1;
        else await new Promise((resolve) => setTimeout(resolve, 50));
      }
      assert(
        completedDrainPasses >= PROFILE_COUNT + 10,
        "Availability queue could not be drained without lock contention",
      );

      for (let index = 0; index < cohort.length; index += 1) {
        const actor = cohort[index];
        const isOptedIn = index < optedIn.length;
        await request(`/rest/v1/users?id=eq.${actor.id}`, {
          apiKey: service,
          method: "PATCH",
          body: { preferred_language: localeCodes[index % localeCodes.length] },
          prefer: "return=minimal",
        });
        await request("/rest/v1/notification_prefs?on_conflict=user_id", {
          token: actor.token,
          method: "POST",
          body: {
            user_id: actor.id,
            new_compatible_profiles: isOptedIn,
            discovery_digest_frequency: "off",
          },
          prefer: "resolution=merge-duplicates,return=minimal",
        });
        const emptyRows = await feed(actor, filters);
        assert(
          emptyRows.length === 0,
          `Availability feed was not empty for cohort member ${index}`,
        );
        await rpc(actor, "record_discovery_inventory", {
          p_filters: filters,
          p_has_profiles: false,
        });
      }

      await request(`/rest/v1/profiles?id=eq.${candidate.profileId}`, {
        apiKey: service,
        method: "PATCH",
        body: { visibility: "visible", approved_at: new Date().toISOString() },
        prefer: "return=minimal",
      });

      let notificationRows = [];
      const availabilityWorkerResults = [];
      // Explicitly invoke the same bounded production worker so the assertion
      // does not depend on pg_net or cron scheduling latency.
      for (let attempt = 0; attempt < 30; attempt += 1) {
        const workerResult = await request(
          "/rest/v1/rpc/process_discovery_availability_notifications",
          {
            apiKey: service,
            method: "POST",
            body: { p_batch_size: 40 },
          },
        );
        if (workerResult?.queued || workerResult?.busy) {
          availabilityWorkerResults.push(workerResult);
        }
        notificationRows = await request(
          `/rest/v1/notifications?user_id=in.(${
            cohort.map((actor) => actor.id).join(",")
          })&type=eq.new_compatible_profiles&select=user_id,title,body,deep_link`,
          { apiKey: service },
        );
        if (notificationRows.length >= optedIn.length) break;
        await new Promise((resolve) => setTimeout(resolve, 100));
      }

      const notifiedIds = new Set(notificationRows.map((row) => row.user_id));
      if (notificationRows.length !== optedIn.length) {
        const missingActors = optedIn.filter((actor) => !notifiedIds.has(actor.id));
        const missingDiagnostics = [];
        for (const actor of missingActors) {
          const [exactRows, prefs, account] = await Promise.all([
            feed(actor, filters),
            request(
              `/rest/v1/notification_prefs?user_id=eq.${actor.id}&select=new_compatible_profiles`,
              { apiKey: service },
            ),
            request(
              `/rest/v1/users?id=eq.${actor.id}&select=subscription_status,subscription_expires_at,is_banned,is_shadowbanned`,
              { apiKey: service },
            ),
          ]);
          missingDiagnostics.push({
            fixtureIndex: actor.index,
            userId: actor.id,
            exactFeedContainsCandidate: exactRows.some((row) => row.user_id === candidate.id),
            preference: prefs[0]?.new_compatible_profiles,
            account: account[0],
          });
        }
        console.error(JSON.stringify({
          availabilityWorkerResults,
          missingDiagnostics,
        }));
      }
      assert(
        notificationRows.length === optedIn.length,
        `Expected ${optedIn.length} availability alerts, received ${notificationRows.length}`,
      );
      assert(
        optedIn.every((actor) => notifiedIds.has(actor.id)),
        "An opted-in compatible viewer was not notified",
      );
      assert(
        optedOut.every((actor) => !notifiedIds.has(actor.id)),
        "An opted-out viewer received an availability notification",
      );
      const candidateName = candidate.profile.first_name.toLowerCase();
      const candidateLocation = [
        candidate.city.name,
        candidate.region.name,
        "india",
      ].filter(Boolean).map((value) => value.toLowerCase());
      for (const row of notificationRows) {
        const copy = `${row.title} ${row.body}`.toLowerCase();
        assert(
          row.deep_link === "silarah://discover",
          "Availability route was not canonical",
        );
        assert(
          !copy.includes(candidateName),
          "Availability copy leaked a member name",
        );
        assert(
          candidateLocation.every((value) => !copy.includes(value)),
          "Availability copy leaked a member location",
        );
      }
      assert(
        new Set(notificationRows.map((row) => row.title)).size ===
          localeCodes.length,
        "All ten localized notification titles were not produced",
      );

      for (const actor of optedIn) {
        const rows = await feed(actor, filters);
        assert(
          rows.some((row) => row.user_id === candidate.id),
          "Notified viewer did not receive the candidate in the exact feed",
        );
      }

      // A later catalog event must not create a duplicate while the member's
      // inventory state is already non-empty.
      await request(`/rest/v1/profiles?id=eq.${candidate.profileId}`, {
        apiKey: service,
        method: "PATCH",
        body: { mother_tongue: uniqueTongue },
        prefer: "return=minimal",
      });
      await request(
        "/rest/v1/rpc/process_discovery_availability_notifications",
        {
          apiKey: service,
          method: "POST",
          body: { p_batch_size: 40 },
        },
      );
      const deduped = await request(
        `/rest/v1/notifications?user_id=in.(${
          cohort.map((actor) => actor.id).join(",")
        })&type=eq.new_compatible_profiles&select=id`,
        { apiKey: service },
      );
      assert(
        deduped.length === optedIn.length,
        "A repeated catalog event created duplicate availability alerts",
      );

      await request(`/rest/v1/profiles?id=eq.${candidate.profileId}`, {
        apiKey: service,
        method: "PATCH",
        body: { mother_tongue: originalTongue },
        prefer: "return=minimal",
      });
      return {
        population: PROFILE_COUNT,
        evaluatedViewers: cohort.length,
        notified: notificationRows.length,
        optedOut: optedOut.length,
        localizedTitles: localeCodes.length,
        duplicateAlerts: deduped.length - notificationRows.length,
      };
    },
    { continueOnFailure: false },
  );

  await test("free daily profile-view limit stops the sixteenth distinct view", async () => {
    const targets = femaleFreeMembers.slice(3, 19);
    for (const target of targets.slice(0, 15)) {
      const row = firstRow(
        await rpc(freeViewMale, "record_profile_view", {
          p_viewed_user_id: target.id,
          p_notify_owner: false,
        }),
        "record_profile_view",
      );
      assert(row.allowed === true, "A free view was rejected before 15");
    }
    const denied = firstRow(
      await rpc(freeViewMale, "record_profile_view", {
        p_viewed_user_id: targets[15].id,
        p_notify_owner: false,
      }),
      "record_profile_view",
    );
    assert(
      denied.allowed === false,
      "The sixteenth free distinct view was allowed",
    );
    assert(
      Number(denied.daily_limit) === 15,
      "Free profile-view limit is not 15",
    );
    return { allowed: 15, denied: 1 };
  });

  await test("Premium profile views are effectively unlimited", async () => {
    const targets = femaleFreeMembers.slice(20, 50);
    for (const target of targets) {
      const row = firstRow(
        await rpc(premiumMale, "record_profile_view", {
          p_viewed_user_id: target.id,
          p_notify_owner: false,
        }),
        "record_profile_view",
      );
      assert(row.allowed === true, "Premium profile view was rejected");
      assert(
        Number(row.daily_limit) > PROFILE_COUNT,
        "Premium view limit is unexpectedly finite",
      );
    }
    return { viewsRecorded: targets.length };
  });

  await test("profile-view identities are Premium-only while summaries stay free", async () => {
    await rpc(freeMale, "record_profile_view", {
      p_viewed_user_id: premiumFemale.id,
      p_notify_owner: false,
    });
    await rpc(freeMale, "record_profile_view", {
      p_viewed_user_id: freeFemale.id,
      p_notify_owner: false,
    });
    const summary = firstRow(
      await rpc(freeFemale, "get_my_profile_view_summary"),
      "profile view summary",
    );
    assert(
      Number(summary.viewer_count) >= 1,
      "Free aggregate viewer count was missing",
    );
    await expectRejected(
      () => rpc(freeFemale, "get_my_profile_viewers", { p_limit: 50 }),
      "premium_required",
      "Free member received profile-view identities",
    );
    const viewers = await rpc(premiumFemale, "get_my_profile_viewers", {
      p_limit: 50,
    });
    assert(
      viewers.some((row) => row.viewer_user_id === freeMale.id),
      "Premium viewer list omitted the viewer",
    );
    return { premiumViewerRows: viewers.length };
  });

  await test("free daily interest limit rejects the sixth send", async () => {
    const targets = femaleFreeMembers.slice(55, 61);
    const before = firstRow(
      await rpc(freeInterestMale, "get_interest_quota"),
      "free interest quota",
    );
    assert(Number(before.daily_limit) === 5, "Free interest limit is not 5");
    for (const target of targets.slice(0, 5)) {
      await rpc(freeInterestMale, "send_interest", {
        p_receiver_id: target.id,
        p_note: null,
      });
    }
    await expectRejected(
      () =>
        rpc(freeInterestMale, "send_interest", {
          p_receiver_id: targets[5].id,
          p_note: null,
        }),
      "interest_quota_exhausted",
      "Free member sent a sixth daily interest",
    );
    return { allowed: 5, denied: 1 };
  });

  await test("Premium daily interest limit rejects the twenty-sixth send", async () => {
    const targets = femaleFreeMembers.slice(20, 46);
    const before = firstRow(
      await rpc(premiumInterestMale, "get_interest_quota"),
      "Premium interest quota",
    );
    assert(
      Number(before.daily_limit) === 25,
      "Premium interest limit is not 25",
    );
    for (const target of targets.slice(0, 25)) {
      await rpc(premiumInterestMale, "send_interest", {
        p_receiver_id: target.id,
        p_note: null,
      });
    }
    await expectRejected(
      () =>
        rpc(premiumInterestMale, "send_interest", {
          p_receiver_id: targets[25].id,
          p_note: null,
        }),
      "interest_quota_exhausted",
      "Premium member sent a twenty-sixth daily interest",
    );
    return { allowed: 25, denied: 1 };
  });

  await test("interest send and withdrawal update only card state", async () => {
    const actor = await signIn(maleFreeMembers[4]);
    const before = await feed(actor);
    assert(before.length > 0, "Discovery returned no withdrawal target");
    const target = members.find((member) => member.id === before[0].user_id);
    assert(target, "Withdrawal target was not in the fixture map");
    const interestId = await rpc(actor, "send_interest", {
      p_receiver_id: target.id,
      p_note: "Matrix withdrawal check",
    });
    const pending = await rpc(actor, "get_prior_match_context", {
      p_candidate_user_ids: [target.id],
    });
    assert(
      pending[0]?.relationship_state === "pending_sent",
      "Pending card state was not returned",
    );
    await rpc(actor, "withdraw_interest", { p_interest_id: interestId });
    const withdrawn = await rpc(actor, "get_prior_match_context", {
      p_candidate_user_ids: [target.id],
    });
    assert(
      withdrawn[0]?.relationship_state === "none",
      "Withdrawn card state remained pending",
    );
    const after = await feed(actor);
    assert(
      after.some((row) => row.user_id === target.id),
      "Withdrawn profile disappeared from Discovery",
    );
    return { relationshipState: withdrawn[0]?.relationship_state };
  });

  await test("interest and profile-view events create notification records", async () => {
    const interestNotifications = await request(
      `/rest/v1/notifications?user_id=in.(${
        femaleFreeMembers.map((member) => member.id).join(",")
      })&type=eq.interest_received&select=id`,
      { apiKey: service },
    );
    assert(
      interestNotifications.length >= 30,
      "Interest notifications were not queued",
    );
    await rpc(premiumMale, "record_profile_view", {
      p_viewed_user_id: femaleFreeMembers[0].id,
      p_notify_owner: true,
    });
    const viewNotifications = await request(
      `/rest/v1/notifications?user_id=eq.${
        femaleFreeMembers[0].id
      }&type=eq.profile_view&select=id,deep_link`,
      { apiKey: service },
    );
    assert(
      viewNotifications.length === 1,
      "Profile-view notification was not queued",
    );
    return {
      interestNotifications: interestNotifications.length,
      profileViewNotifications: viewNotifications.length,
    };
  });

  const durations = report.tests
    .filter((entry) => entry.status === "passed")
    .map((entry) => entry.durationMs)
    .sort((left, right) => left - right);
  const percentile = (value) =>
    durations[
      Math.min(durations.length - 1, Math.ceil(durations.length * value) - 1)
    ] ?? 0;
  report.performance = {
    measuredSteps: durations.length,
    p50Ms: percentile(0.5),
    p95Ms: percentile(0.95),
    maxMs: durations.at(-1) ?? 0,
  };
  if (continuingFailures.length > 0) {
    report.continuingFailures = continuingFailures;
    throw new Error(
      `${continuingFailures.length} independent feature assertion(s) failed`,
    );
  }
  report.status = "passed";
  console.log("PASS: complete disposable 200-profile staging matrix");
} catch (error) {
  failure = error;
  report.status = "failed";
  report.error = errorMessage(error);
} finally {
  try {
    await cleanup();
  } catch (error) {
    report.cleanup.error = errorMessage(error);
    failure ??= error;
    report.status = "failed";
  }
  report.finishedAt = new Date().toISOString();
  report.durationMs = new Date(report.finishedAt) - new Date(report.startedAt);
  mkdirSync(dirname(reportPath), { recursive: true });
  writeFileSync(reportPath, `${JSON.stringify(report, null, 2)}\n`);
  console.log(`REPORT: ${reportPath}`);
}

if (failure) throw failure;
