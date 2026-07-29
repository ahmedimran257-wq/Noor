import { assertEquals, assertRejects } from "@std/assert";
import {
  consumeDistributedRateLimit,
  rateLimitHeaders,
} from "./distributed_rate_limit.ts";

Deno.test("distributed rate limit parses an atomic database result", async () => {
  const result = await consumeDistributedRateLimit(
    {
      rpc: () =>
        Promise.resolve({
          data: [{
            allowed: false,
            remaining: 0,
            reset_at: new Date(Date.now() + 60_000).toISOString(),
          }],
          error: null,
        }),
    },
    {
      scope: "translation",
      subject: "user",
      maxRequests: 60,
      windowSeconds: 3600,
    },
  );

  assertEquals(result.allowed, false);
  assertEquals(result.remaining, 0);
  assertEquals(rateLimitHeaders(result)["X-RateLimit-Remaining"], "0");
});

Deno.test("distributed rate limit fails closed when storage is unavailable", async () => {
  await assertRejects(
    () =>
      consumeDistributedRateLimit(
        {
          rpc: () =>
            Promise.resolve({
              data: null,
              error: { message: "database unavailable" },
            }),
        },
        {
          scope: "translation",
          subject: "user",
          maxRequests: 60,
          windowSeconds: 3600,
        },
      ),
    Error,
    "Distributed rate limiter unavailable",
  );
});
