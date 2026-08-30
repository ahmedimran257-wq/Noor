#!/usr/bin/env node

// Owner-authorized, reversible production discovery fixtures.
//
// This is deliberately separate from staging_200_profile_matrix.mjs. The
// staging matrix signs actors in and always self-cleans; this tool creates
// persistent, non-login test inventory for supervised UI/filter testing.

import { writeFileSync } from "node:fs";
import { resolve } from "node:path";

const DEFAULT_PROFILE_COUNT = 500;
const MAX_PROFILE_COUNT = 500;
const KNOWN_PRODUCTION_REF = "jukpscfxzwttgtxvrbmj";
const PRODUCTION_ACK = "confirmed-by-owner";
// Minimal neutral JPEG fixture. Each photo row needs its own object key because
// production enforces globally unique photo storage paths. At this size, all
// 500 objects together remain well below one megabyte.
const TEST_IMAGE_BYTES = Buffer.from(
  "/9j/4AAQSkZJRgABAQAAAQABAAD/2wBDAP//////////////////////////////////////////////////////////////////////////////////////2wBDAf//////////////////////////////////////////////////////////////////////////////////////wAARCAABAAEDASIAAhEBAxEB/8QAFQABAQAAAAAAAAAAAAAAAAAAAAX/xAAUEAEAAAAAAAAAAAAAAAAAAAAA/9oADAMBAAIQAxAAAAF//8QAFBABAAAAAAAAAAAAAAAAAAAAAP/aAAgBAQABBQJ//8QAFBEBAAAAAAAAAAAAAAAAAAAAAP/aAAgBAwEBPwF//8QAFBEBAAAAAAAAAAAAAAAAAAAAAP/aAAgBAgEBPwF//8QAFBABAAAAAAAAAAAAAAAAAAAAAP/aAAgBAQAGPwJ//8QAFBABAAAAAAAAAAAAAAAAAAAAAP/aAAgBAQABPyF//9oADAMBAAIAAwAAABAf/8QAFBEBAAAAAAAAAAAAAAAAAAAAAP/aAAgBAwEBPxB//8QAFBEBAAAAAAAAAAAAAAAAAAAAAP/aAAgBAgEBPxB//8QAFBABAAAAAAAAAAAAAAAAAAAAAP/aAAgBAQABPxB//9k=",
  "base64",
);
// Database-driven fixture coverage for India filters. These are real city
// centres, but rows are inserted only when absent and registered on the batch
// for safe removal after the fixture profiles are deleted.
const INDIA_TEST_CITY_CENTRES = [
  ["Guwahati", "Assam", 26.1445, 91.7362],
  ["Patna", "Bihar", 25.5941, 85.1376],
  ["Delhi", "Delhi", 28.6139, 77.2090],
  ["Ahmedabad", "Gujarat", 23.0225, 72.5714],
  ["Srinagar", "Jammu and Kashmir", 34.0837, 74.7973],
  ["Bengaluru", "Karnataka", 12.9716, 77.5946],
  ["Kochi", "Kerala", 9.9312, 76.2673],
  ["Bhopal", "Madhya Pradesh", 23.2599, 77.4126],
  ["Mumbai", "Maharashtra", 19.0760, 72.8777],
  ["Bhubaneswar", "Odisha", 20.2961, 85.8245],
  ["Jaipur", "Rajasthan", 26.9124, 75.7873],
  ["Chennai", "Tamil Nadu", 13.0827, 80.2707],
  ["Hyderabad", "Telangana", 17.3850, 78.4867],
  ["Lucknow", "Uttar Pradesh", 26.8467, 80.9462],
  ["Kolkata", "West Bengal", 22.5726, 88.3639],
];
const command = process.argv[2] ?? "status";
const options = Object.fromEntries(
  process.argv.slice(3).map((value) => {
    const [key, ...rest] = value.replace(/^--/, "").split("=");
    return [key, rest.join("=") || true];
  }),
);

for (const name of [
  "SUPABASE_URL",
  "SUPABASE_SERVICE_ROLE_KEY",
  "PRODUCTION_PROJECT_REF",
]) {
  if (!process.env[name]) throw new Error(`Missing environment variable: ${name}`);
}

const baseUrl = process.env.SUPABASE_URL.replace(/\/$/, "");
const projectRef = process.env.PRODUCTION_PROJECT_REF;
const service = process.env.SUPABASE_SERVICE_ROLE_KEY;
const host = new URL(baseUrl).hostname;

if (projectRef !== KNOWN_PRODUCTION_REF || !host.startsWith(`${projectRef}.`)) {
  throw new Error("Production URL/project reference mismatch");
}
if (
  ["create", "remove"].includes(command) &&
  process.env.ALLOW_PRODUCTION_TEST_FIXTURES !== PRODUCTION_ACK
) {
  throw new Error(
    `Set ALLOW_PRODUCTION_TEST_FIXTURES=${PRODUCTION_ACK} for production mutation`,
  );
}

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

function errorMessage(error) {
  return error instanceof Error ? error.message : String(error);
}

function chunks(items, size) {
  const result = [];
  for (let index = 0; index < items.length; index += size) {
    result.push(items.slice(index, index + size));
  }
  return result;
}

async function mapConcurrent(items, concurrency, action) {
  const results = new Array(items.length);
  let cursor = 0;
  async function worker() {
    while (cursor < items.length) {
      const index = cursor++;
      results[index] = await action(items[index], index);
    }
  }
  await Promise.all(
    Array.from({ length: Math.min(concurrency, items.length) }, worker),
  );
  return results;
}

async function request(
  path,
  { method = "GET", body, prefer, contentType = "application/json" } = {},
) {
  let lastError;
  for (let attempt = 0; attempt < 6; attempt += 1) {
    let response;
    try {
      response = await fetch(`${baseUrl}${path}`, {
        method,
        headers: {
          apikey: service,
          Authorization: `Bearer ${service}`,
          "Content-Type": contentType,
          ...(prefer ? { Prefer: prefer } : {}),
        },
        body: body === undefined
          ? undefined
          : contentType === "application/json"
          ? JSON.stringify(body)
          : body,
      });
    } catch (error) {
      lastError = error;
      if (attempt === 5) throw error;
      await new Promise((resolveDelay) =>
        setTimeout(resolveDelay, Math.min(8000, 350 * 2 ** attempt))
      );
      continue;
    }
    const raw = await response.text();
    let data = null;
    if (raw) {
      try {
        data = JSON.parse(raw);
      } catch {
        data = raw;
      }
    }
    if (response.ok) return data;
    const message = data?.message ?? data?.error_description ?? data?.error ??
      (typeof data === "string" ? data : `HTTP ${response.status}`);
    lastError = new Error(message);
    lastError.status = response.status;
    lastError.data = data;
    if (![429, 500, 502, 503, 504].includes(response.status) || attempt === 5) {
      throw lastError;
    }
    await new Promise((resolveDelay) =>
      setTimeout(resolveDelay, Math.min(8000, 350 * 2 ** attempt))
    );
  }
  throw lastError;
}

async function insertRows(
  table,
  rows,
  { returning = false, onConflict, mergeDuplicates = false } = {},
) {
  const inserted = [];
  for (const batch of chunks(rows, 40)) {
    const conflictQuery = onConflict
      ? `?on_conflict=${encodeURIComponent(onConflict)}`
      : "";
    const preferences = [
      mergeDuplicates ? "resolution=merge-duplicates" : null,
      returning ? "return=representation" : "return=minimal",
    ].filter(Boolean).join(",");
    const data = await request(`/rest/v1/${table}${conflictQuery}`, {
      method: "POST",
      body: batch,
      prefer: preferences,
    });
    if (returning && Array.isArray(data)) inserted.push(...data);
  }
  return inserted;
}

async function patchWhere(table, query, body, { returning = false } = {}) {
  return request(`/rest/v1/${table}?${query}`, {
    method: "PATCH",
    body,
    prefer: returning ? "return=representation" : "return=minimal",
  });
}

async function deleteWhere(table, query) {
  return request(`/rest/v1/${table}?${query}`, {
    method: "DELETE",
    prefer: "return=minimal",
  });
}

function inFilter(ids) {
  return `in.(${ids.join(",")})`;
}

function isoBirthday(age, index) {
  const year = new Date().getUTCFullYear() - age;
  const month = String(1 + (index % 12)).padStart(2, "0");
  const day = String(1 + (index % 27)).padStart(2, "0");
  return `${year}-${month}-${day}`;
}

function groupCount(items, selector) {
  const grouped = {};
  for (const item of items) {
    const key = String(selector(item));
    grouped[key] = (grouped[key] ?? 0) + 1;
  }
  return grouped;
}

async function activeBatches() {
  return request(
    "/rest/v1/test_fixture_batches" +
      "?status=in.(creating,active,removing)" +
      "&select=batch_id,requested_count,status,storage_path,created_at,activated_at" +
      "&order=created_at.asc",
  );
}

async function batchMembers(batchId) {
  return request(
    `/rest/v1/test_fixture_members?batch_id=eq.${encodeURIComponent(batchId)}` +
      "&select=user_id,fixture_index,gender&order=fixture_index.asc&limit=500",
  );
}

async function status() {
  const batches = await request(
    "/rest/v1/test_fixture_batches" +
      "?select=batch_id,requested_count,status,created_at,activated_at,removed_at,metadata" +
      "&order=created_at.desc&limit=20",
  );
  const result = [];
  for (const batch of batches) {
    const members = batch.status === "removed" ? [] : await batchMembers(batch.batch_id);
    result.push({
      ...batch,
      registeredMembers: members.length,
      gender: groupCount(members, (member) => member.gender),
    });
  }
  console.log(JSON.stringify({ projectRef, batches: result }, null, 2));
}

async function createAuthMember(seed, batchId) {
  const response = await request("/auth/v1/admin/users", {
    method: "POST",
    body: {
      email: seed.email,
      password: `Fixture-${crypto.randomUUID()}-Z9!`,
      email_confirm: true,
      user_metadata: {
        silarah_test_fixture: true,
        test_fixture_batch: batchId,
        fixture_index: seed.index,
      },
      app_metadata: {
        provider: "email",
        providers: ["email"],
        silarah_test_fixture: true,
      },
    },
  });
  const id = response?.id ?? response?.user?.id;
  assert(id, `Auth user missing for fixture ${seed.index}`);
  try {
    await insertRows("test_fixture_members", [{
      batch_id: batchId,
      user_id: id,
      fixture_index: seed.index,
      gender: seed.gender,
    }]);
  } catch (error) {
    await request(`/auth/v1/admin/users/${id}`, { method: "DELETE" })
      .catch(() => undefined);
    throw error;
  }
  return { ...seed, id };
}

async function uploadTestImage(storagePath) {
  await request(`/storage/v1/object/profile-photos/${storagePath}`, {
    method: "POST",
    body: TEST_IMAGE_BYTES,
    contentType: "image/jpeg",
  });
}

async function removeStorageObject(storagePath) {
  if (!storagePath) return;
  assert(
    /^test-fixtures\/production-discovery-\d+-\d+$/.test(storagePath),
    "Refusing to remove an unrecognized fixture storage path",
  );

  const objects = await request("/storage/v1/object/list/profile-photos", {
    method: "POST",
    body: {
      prefix: storagePath,
      limit: MAX_PROFILE_COUNT + 1,
      offset: 0,
      sortBy: { column: "name", order: "asc" },
    },
  });
  assert(
    objects.length <= MAX_PROFILE_COUNT,
    "Fixture storage contains more objects than the protected batch limit",
  );

  const exactPaths = objects.map((object) => {
    assert(
      /^profile-\d{3}\.jpg$/.test(object?.name ?? ""),
      "Fixture storage contains an unrecognized object name",
    );
    return `${storagePath}/${object.name}`;
  });
  for (const paths of chunks(exactPaths, 100)) {
    await request("/storage/v1/object/profile-photos", {
      method: "DELETE",
      body: { prefixes: paths },
    });
  }

  const remaining = await request("/storage/v1/object/list/profile-photos", {
    method: "POST",
    body: { prefix: storagePath, limit: 1, offset: 0 },
  });
  assert(remaining.length === 0, "Fixture storage cleanup was incomplete");
}

async function removeBatch(batchId, { failureReason } = {}) {
  const batchRows = await request(
    `/rest/v1/test_fixture_batches?batch_id=eq.${encodeURIComponent(batchId)}` +
      "&select=batch_id,status,storage_path,metadata",
  );
  const batch = batchRows[0];
  if (!batch) throw new Error(`Unknown fixture batch: ${batchId}`);
  if (batch.status === "removed") {
    await removeStorageObject(batch.storage_path);
    return { batchId, removed: 0 };
  }

  await patchWhere(
    "test_fixture_batches",
    `batch_id=eq.${encodeURIComponent(batchId)}`,
    { status: "removing" },
  );
  const members = await batchMembers(batchId);
  const userIds = members.map((member) => member.user_id);

  for (const ids of chunks(userIds, 35)) {
    const list = inFilter(ids);
    await deleteWhere(
      "referrals",
      `or=(referrer_id.${list},referred_id.${list})`,
    ).catch(() => undefined);
    await deleteWhere("users", `id=${list}`);
  }

  const authFailures = [];
  await mapConcurrent(userIds, 6, async (id) => {
    try {
      await request(`/auth/v1/admin/users/${id}`, { method: "DELETE" });
    } catch (error) {
      if (error.status !== 404) authFailures.push({ id, error: errorMessage(error) });
    }
  });
  if (authFailures.length > 0) {
    throw new Error(`${authFailures.length} fixture Auth accounts could not be removed`);
  }

  await removeStorageObject(batch.storage_path);
  const fixtureCityIds = Array.isArray(batch.metadata?.fixture_city_ids)
    ? batch.metadata.fixture_city_ids.filter(Number.isInteger)
    : [];
  if (fixtureCityIds.length > 0) {
    const occupied = await request(
      `/rest/v1/profiles?city_id=${inFilter(fixtureCityIds)}` +
        "&select=city_id&limit=500",
    );
    const occupiedIds = new Set(occupied.map((row) => row.city_id));
    const removableIds = fixtureCityIds.filter((id) => !occupiedIds.has(id));
    for (const ids of chunks(removableIds, 35)) {
      await deleteWhere("cities", `id=${inFilter(ids)}`);
    }
  }
  await patchWhere(
    "test_fixture_batches",
    `batch_id=eq.${encodeURIComponent(batchId)}`,
    {
      status: failureReason ? "failed" : "removed",
      removed_at: new Date().toISOString(),
      metadata: {
        ...(batch.metadata ?? {}),
        removed_count: userIds.length,
        ...(failureReason ? { failure_reason: failureReason } : {}),
      },
    },
  );
  return { batchId, removed: userIds.length };
}

async function removeRequested() {
  const requestedBatch = options.batch === true ? null : options.batch;
  const batches = requestedBatch
    ? [{ batch_id: requestedBatch }]
    : await activeBatches();
  if (batches.length === 0) {
    console.log(JSON.stringify({ removedBatches: 0, removedProfiles: 0 }, null, 2));
    return;
  }
  const results = [];
  for (const batch of batches) results.push(await removeBatch(batch.batch_id));
  console.log(JSON.stringify({
    removedBatches: results.length,
    removedProfiles: results.reduce((sum, row) => sum + row.removed, 0),
    results,
  }, null, 2));
}

async function create() {
  const count = Number(options.count === true ? DEFAULT_PROFILE_COUNT : options.count ?? DEFAULT_PROFILE_COUNT);
  assert(Number.isInteger(count) && count >= 2 && count <= MAX_PROFILE_COUNT, "count must be between 2 and 500");
  assert(count % 2 === 0, "count must be even for a 50/50 gender split");

  const existing = await activeBatches();
  assert(existing.length === 0, "An active test fixture batch already exists; remove it first");

  const timestamp = new Date().toISOString().replace(/[-:.TZ]/g, "").slice(0, 14);
  const batchId = `production-discovery-${count}-${timestamp}`;
  const storagePath = `test-fixtures/${batchId}`;
  const reportPath = resolve(
    options.report === true || !options.report
      ? "build/production-test-profile-report.json"
      : options.report,
  );

  await insertRows("test_fixture_batches", [{
    batch_id: batchId,
    fixture_kind: "discovery_profiles",
    requested_count: count,
    target_project_ref: projectRef,
    status: "creating",
    storage_path: storagePath,
    metadata: {
      purpose: "Owner-supervised Premium, discovery and filter testing",
      test_only: true,
      sends_email: false,
      authenticates_fixture_accounts: false,
    },
  }]);

  let members = [];
  try {
    const regions = await request(
      "/rest/v1/regions?country_code=eq.IN&select=id,name&order=name.asc&limit=100",
    );
    assert(regions.length >= 1, "India region catalogue is empty");
    const regionIds = regions.map((region) => region.id);
    const regionByName = new Map(regions.map((region) => [region.name, region]));
    const existingCities = await request(
      `/rest/v1/cities?region_id=${inFilter(regionIds)}` +
      "&select=id,name,region_id,latitude,longitude&latitude=not.is.null" +
      "&longitude=not.is.null&order=region_id.asc,id.asc&limit=500",
    );
    const existingCityKeys = new Set(
      existingCities.map((city) => `${city.region_id}:${city.name.toLowerCase()}`),
    );
    const missingFixtureCities = INDIA_TEST_CITY_CENTRES
      .map(([name, regionName, latitude, longitude]) => ({
        name,
        region_id: regionByName.get(regionName)?.id,
        latitude,
        longitude,
      }))
      .filter((city) => city.region_id &&
        !existingCityKeys.has(`${city.region_id}:${city.name.toLowerCase()}`));
    const createdFixtureCities = missingFixtureCities.length > 0
      ? await insertRows("cities", missingFixtureCities, { returning: true })
      : [];
    const fixtureCityIds = createdFixtureCities.map((city) => city.id);
    await patchWhere(
      "test_fixture_batches",
      `batch_id=eq.${encodeURIComponent(batchId)}`,
      {
        metadata: {
          purpose: "Owner-supervised Premium, discovery and filter testing",
          test_only: true,
          sends_email: false,
          authenticates_fixture_accounts: false,
          fixture_city_ids: fixtureCityIds,
        },
      },
    );
    const cities = await request(
      `/rest/v1/cities?region_id=${inFilter(regionIds)}` +
        "&select=id,name,region_id,latitude,longitude&latitude=not.is.null" +
        "&longitude=not.is.null&order=region_id.asc,id.asc&limit=500",
    );
    assert(cities.length >= 1, "India city catalogue has no coordinate-backed rows");
    const regionById = new Map(regions.map((region) => [region.id, region]));
    const languages = await request(
      "/rest/v1/india_state_mother_tongues" +
        "?state_code=eq.ALL&select=language,display_rank&order=display_rank.asc&limit=100",
    );
    const tongues = languages.map((row) => row.language);
    assert(tongues.length >= 20, "India mother-tongue catalogue is incomplete");

    const seeds = Array.from({ length: count }, (_, index) => ({
      index,
      gender: index % 2 === 0 ? "male" : "female",
      email: `fixture.${batchId}.${String(index).padStart(3, "0")}@test.silarah.invalid`,
    }));

    console.log(`Creating ${count} tagged Auth fixtures...`);
    members = await mapConcurrent(seeds, 6, async (seed) => {
      const member = await createAuthMember(seed, batchId);
      if ((seed.index + 1) % 50 === 0) console.log(`Registered ${seed.index + 1}/${count}`);
      return member;
    });
    assert(members.length === count, "Auth fixture count mismatch");

    const now = new Date();
    const publicUsers = members.map((member) => ({
      id: member.id,
      email: member.email,
      country_code: "IN",
      gender: member.gender,
      preferred_language: ["en", "hi", "ur"][member.index % 3],
      timezone: "Asia/Kolkata",
      subscription_status: "none",
      onboarding_step: 5,
      onboarding_completed: true,
      created_at: new Date(now.getTime() - (member.index % 90) * 86_400_000).toISOString(),
    }));
    await insertRows("users", publicUsers);

    const sects = ["Sunni", "Shia", "Just Muslim"];
    const deenLevels = ["practicing", "moderate", "cultural"];
    const familyTypes = ["nuclear", "joint", "extended"];
    const maritalStatuses = ["no", "divorced", "widowed"];
    const communities = [
      "Sheikh", "Syed", "Pathan", "Ansari", "Qureshi", "Memon",
      "Mapilla", "Bohra", "Khoja", "No community preference",
    ];
    const living = ["separate", "with_inlaws", "open_to_discussion"];
    const quran = ["none", "some_surahs", "partial", "hafiz"];
    const timelines = ["asap", "6_months", "1_year", "2_plus_years"];
    const relocation = ["yes", "no", "open_to_discussion"];
    const professions = [
      "Software Engineer", "Teacher", "Doctor", "Designer", "Accountant",
      "Entrepreneur", "Civil Engineer", "Nurse", "Lawyer", "Researcher",
    ];

    const profileRows = members.map((member) => {
      const pairIndex = Math.floor(member.index / 2);
      const city = cities[pairIndex % cities.length];
      const region = regionById.get(city.region_id);
      const age = 21 + (pairIndex % 29);
      return {
        user_id: member.id,
        static_rank_score: 20 + (pairIndex % 30),
        first_name: `Test ${member.gender === "female" ? "Woman" : "Man"} ${String(pairIndex + 1).padStart(3, "0")}`,
        last_name: "Fixture",
        date_of_birth: isoBirthday(age, pairIndex),
        gender: member.gender,
        country_code: "IN",
        city_id: city.id,
        sect: sects[pairIndex % sects.length],
        deen_level: deenLevels[pairIndex % deenLevels.length],
        prays_five_daily: pairIndex % 2 === 0,
        education_level: ["Graduate", "Postgraduate", "Doctorate", "Diploma"][pairIndex % 4],
        education_rank: 2 + (pairIndex % 6),
        profession: professions[pairIndex % professions.length],
        family_type: familyTypes[pairIndex % familyTypes.length],
        parents_status: ["Both living", "Mother living", "Father living"][pairIndex % 3],
        previously_married: maritalStatuses[pairIndex % maritalStatuses.length],
        children_count: pairIndex % 5 === 0 ? 1 : 0,
        bio: `TEST PROFILE ${String(member.index + 1).padStart(3, "0")} — synthetic Silarah account for supervised Premium, discovery and filter testing. This is not a real member. State: ${region?.name ?? "India"}.`,
        languages: [tongues[pairIndex % tongues.length], "English"],
        interests: ["Family", "Reading", "Community service"],
        height_cm: 150 + (pairIndex % 40),
        photo_privacy: "public",
        visibility: "visible",
        onboarding_step: 5,
        onboarding_flow_version: 3,
        onboarding_completed: true,
        completeness_score: 100,
        is_verified: false,
        approved_at: now.toISOString(),
        last_active_at: new Date(now.getTime() - (pairIndex % 72) * 3_600_000).toISOString(),
        mother_tongue: tongues[pairIndex % tongues.length],
        community: communities[pairIndex % communities.length],
        complexion: ["fair", "medium", "olive", "dark"][pairIndex % 4],
        diet_type: ["halal_only", "zabiha_strict", "vegetarian"][pairIndex % 3],
        smoking_habit: pairIndex % 7 === 0 ? "occasionally" : "never",
        quran_memorization: quran[pairIndex % quran.length],
        religious_education: ["self_taught", "madrasa", "none"][pairIndex % 3],
        marriage_timeline: timelines[pairIndex % timelines.length],
        willing_to_relocate: relocation[pairIndex % relocation.length],
        living_expectation: living[pairIndex % living.length],
        // PostgREST bulk inserts require every object in the JSON array to
        // expose the same keys, even when a gender-specific value is null.
        hijab: member.gender === "female"
          ? ["always", "sometimes", "no"][pairIndex % 3]
          : null,
        beard: member.gender === "male"
          ? ["yes", "no", "prefer_not_to_say"][pairIndex % 3]
          : null,
      };
    });
    const insertedProfiles = await insertRows("profiles", profileRows, { returning: true });
    assert(insertedProfiles.length === count, "Profile fixture count mismatch");
    const profileByUser = new Map(insertedProfiles.map((row) => [row.user_id, row]));
    members = members.map((member) => ({ ...member, profileId: profileByUser.get(member.id)?.id }));
    assert(members.every((member) => member.profileId), "Profile ID mapping is incomplete");

    await insertRows(
      "profile_preferences",
      members.map((member) => ({
        profile_id: member.profileId,
        preferred_age_min: 21,
        preferred_age_max: 55,
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
      {
        onConflict: "profile_id",
        mergeDuplicates: true,
      },
    );

    const fixturePhotos = members.map((member) => ({
      member,
      storagePath: `${storagePath}/profile-${String(member.index).padStart(3, "0")}.jpg`,
    }));
    await mapConcurrent(fixturePhotos, 12, async (fixture) => {
      await uploadTestImage(fixture.storagePath);
    });
    await insertRows("photos", fixturePhotos.map((fixture) => ({
      profile_id: fixture.member.profileId,
      storage_path: fixture.storagePath,
      status: "active",
      order_index: 0,
      admin_approved: true,
      nsfw_cleared: true,
      moderation_status: "approved",
    })));

    // Deliberately varied retained trust states make paid trust filters testable.
    const photoVerified = members.filter((member) => member.index % 4 === 0);
    for (const part of chunks(photoVerified.map((member) => member.profileId), 35)) {
      await patchWhere("profiles", `id=${inFilter(part)}`, {
        photo_verified_at: now.toISOString(),
        photo_verification_paused_at: null,
        has_verification_badge: true,
        badge_earned_at: now.toISOString(),
        verification_status: "verified",
        verification_challenge: "test_fixture_only",
        verified_at: now.toISOString(),
        is_verified: true,
      });
    }
    const additionalPhotoVerified = members.filter((member) => member.index % 8 === 2);
    for (const part of chunks(additionalPhotoVerified.map((member) => member.profileId), 35)) {
      await patchWhere("profiles", `id=${inFilter(part)}`, {
        photo_verified_at: now.toISOString(),
        photo_verification_paused_at: null,
        has_verification_badge: true,
        badge_earned_at: now.toISOString(),
        verification_status: "verified",
        verification_challenge: "test_fixture_only",
        verified_at: now.toISOString(),
        is_verified: true,
      });
    }
    const guardianConnected = members.filter((member) => member.index % 10 === 3);
    for (const member of guardianConnected) {
      const guardian = members[(member.index + 2) % members.length];
      await patchWhere("profiles", `id=eq.${member.profileId}`, {
        guardian_user_id: guardian.id,
        guardian_mode: "passive",
      });
    }

    await patchWhere(
      "test_fixture_batches",
      `batch_id=eq.${encodeURIComponent(batchId)}`,
      {
        status: "active",
        activated_at: new Date().toISOString(),
        metadata: {
          purpose: "Owner-supervised Premium, discovery and filter testing",
          test_only: true,
          sends_email: false,
          authenticates_fixture_accounts: false,
          fixture_city_ids: fixtureCityIds,
          male: count / 2,
          female: count / 2,
          storage_objects: count,
          photo_verified: photoVerified.length + additionalPhotoVerified.length,
          guardian_connected: guardianConnected.length,
        },
      },
    );

    const registered = await batchMembers(batchId);
    const live = [];
    for (const part of chunks(members.map((member) => member.id), 35)) {
      live.push(...await request(
        `/rest/v1/live_discovery_pool?user_id=${inFilter(part)}` +
          "&select=user_id,gender,mother_tongue,community,living_expectation,city_id&limit=500",
      ));
    }
    const photos = [];
    for (const part of chunks(members.map((member) => member.profileId), 35)) {
      photos.push(...await request(
        `/rest/v1/photos?profile_id=${inFilter(part)}` +
          "&select=profile_id,storage_path&limit=500",
      ));
    }
    const gender = groupCount(live, (row) => row.gender);
    assert(registered.length === count, `Expected ${count} registry members`);
    assert(live.length === count, `Expected ${count} live discovery fixtures, found ${live.length}`);
    assert(photos.length === count, `Expected ${count} photo rows`);
    assert(gender.male === count / 2 && gender.female === count / 2, "Gender split is not 50/50");
    assert(
      new Set(live.map((row) => row.city_id)).size === Math.min(cities.length, Math.ceil(count / 2)),
      "Not every available India city is represented",
    );
    assert(new Set(live.map((row) => row.mother_tongue)).size >= 20, "Mother-tongue diversity is too low");
    assert(
      new Set(photos.map((row) => row.storage_path)).size === count,
      "Expected one unique storage path per test profile",
    );

    const report = {
      batchId,
      projectRef,
      createdAt: new Date().toISOString(),
      profiles: live.length,
      gender,
      cities: new Set(live.map((row) => row.city_id)).size,
      motherTongues: new Set(live.map((row) => row.mother_tongue)).size,
      communities: new Set(live.map((row) => row.community)).size,
      livingExpectations: new Set(live.map((row) => row.living_expectation)).size,
      storageObjects: count,
      fakeAccountsSignedIn: 0,
      notificationFanoutSuppressed: true,
      cleanupCommand: `node tool/manage_production_test_profiles.mjs remove --batch=${batchId}`,
    };
    writeFileSync(reportPath, `${JSON.stringify(report, null, 2)}\n`);
    console.log(JSON.stringify(report, null, 2));
  } catch (error) {
    console.error(`Creation failed: ${errorMessage(error)}. Cleaning this batch...`);
    await removeBatch(batchId, { failureReason: errorMessage(error) }).catch((cleanupError) => {
      console.error(`Automatic cleanup needs attention: ${errorMessage(cleanupError)}`);
    });
    throw error;
  }
}

if (command === "create") await create();
else if (command === "remove") await removeRequested();
else if (command === "status") await status();
else throw new Error("Usage: create | status | remove [--batch=...] [--count=500]");
