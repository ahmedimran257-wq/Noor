import { resolveClientModerationVerdict } from "./photo_moderation_policy.ts";
import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";

Deno.test("approved payload skips admin review", () => {
  assertEquals(
    resolveClientModerationVerdict({
      status: "approved",
      is_nsfw: false,
      confidence: 0.99,
      category: "safe_portrait",
      threshold: 0.55,
    }),
    "approved",
  );
});

Deno.test("low-neutral non-explicit payload remains approved", () => {
  assertEquals(
    resolveClientModerationVerdict({
      status: "approved",
      is_nsfw: false,
      confidence: 0.12,
      category: "safe_image",
      threshold: 0.30,
    }),
    "approved",
  );
});

Deno.test("explicit content above 0.85 is flagged", () => {
  assertEquals(
    resolveClientModerationVerdict({
      status: "flagged",
      is_nsfw: true,
      confidence: 0.93,
      category: "explicit_content",
      threshold: 0.85,
    }),
    "flagged",
  );
});

Deno.test("failed moderation rejects", () => {
  assertEquals(
    resolveClientModerationVerdict({
      status: "scanFailed",
      is_nsfw: false,
      confidence: 0,
      category: "unknown",
      threshold: 0.01,
    }),
    "reject",
  );
});
