import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  PHOTO_MODERATION_POLICY_VERSION,
  resolveClientModerationVerdict,
} from "./photo_moderation_policy.ts";

const safePayload = {
  policy_version: PHOTO_MODERATION_POLICY_VERSION,
  status: "approved" as const,
  is_nsfw: false,
  requires_review: false,
  confidence: 0.99,
  nsfw_confidence: 0.01,
  safe_confidence: 0.99,
  category: "safe_image",
  threshold: 0.85,
};

Deno.test("approved safe payload skips admin review", () => {
  assertEquals(resolveClientModerationVerdict(safePayload), "approved");
});

Deno.test("exactly 0.85 remains approved", () => {
  assertEquals(
    resolveClientModerationVerdict({
      ...safePayload,
      confidence: 0.15,
      nsfw_confidence: 0.85,
      safe_confidence: 0.10,
    }),
    "approved",
  );
});

Deno.test("a score above 0.85 is sent to review", () => {
  assertEquals(
    resolveClientModerationVerdict({
      ...safePayload,
      status: "flagged",
      is_nsfw: true,
      requires_review: true,
      confidence: 0.851,
      nsfw_confidence: 0.851,
      safe_confidence: 0.099,
      category: "explicit_content",
      threshold: 0.85,
    }),
    "flagged",
  );
});

Deno.test("client cannot disguise high NSFW evidence as approved", () => {
  assertEquals(
    resolveClientModerationVerdict({
      ...safePayload,
      confidence: 0.08,
      nsfw_confidence: 0.92,
      safe_confidence: 0.08,
    }),
    "reject",
  );
});

Deno.test("low safe confidence does not reject non-explicit content", () => {
  assertEquals(
    resolveClientModerationVerdict({
      ...safePayload,
      confidence: 0.60,
      nsfw_confidence: 0.40,
      safe_confidence: 0.05,
    }),
    "approved",
  );
});

Deno.test("inconclusive low scores reject", () => {
  assertEquals(
    resolveClientModerationVerdict({
      ...safePayload,
      status: "scanFailed",
      confidence: 0.20,
      nsfw_confidence: 0.20,
      safe_confidence: 0.20,
      category: "scan_failed",
    }),
    "reject",
  );
});

Deno.test("outdated policy payload rejects", () => {
  assertEquals(
    resolveClientModerationVerdict({
      ...safePayload,
      policy_version: 1,
    }),
    "reject",
  );
});
