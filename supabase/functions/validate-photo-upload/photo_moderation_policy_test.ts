import { resolveClientModerationVerdict } from "./photo_moderation_policy.ts";
import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";

Deno.test("client forged safe payload does not auto-approve", () => {
  assertEquals(
    resolveClientModerationVerdict({
      status: "safe",
      is_nsfw: false,
      confidence: 0.99,
      category: "safe_portrait",
      threshold: 0.55,
    }),
    "pending_review",
  );
});

Deno.test("unsafe and failed moderation payloads reject", () => {
  assertEquals(
    resolveClientModerationVerdict({
      status: "unsafe",
      is_nsfw: true,
      confidence: 0.93,
      category: "explicit_content",
      threshold: 0.88,
    }),
    "reject",
  );

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
