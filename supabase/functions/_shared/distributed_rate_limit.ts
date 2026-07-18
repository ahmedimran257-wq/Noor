export interface RateLimitClient {
  rpc(
    functionName: string,
    args: Record<string, unknown>,
  ): PromiseLike<{ data: unknown; error: { message?: string } | null }>;
}

export interface DistributedRateLimitOptions {
  scope: string;
  subject: string;
  maxRequests: number;
  windowSeconds: number;
}

export interface DistributedRateLimitResult {
  allowed: boolean;
  remaining: number;
  resetAt: string;
}

export async function consumeDistributedRateLimit(
  client: unknown,
  options: DistributedRateLimitOptions,
): Promise<DistributedRateLimitResult> {
  const rpcClient = client as RateLimitClient;
  const { data, error } = await rpcClient.rpc("consume_edge_rate_limit", {
    p_scope: options.scope,
    p_subject: options.subject,
    p_max_requests: options.maxRequests,
    p_window_seconds: options.windowSeconds,
  });

  if (error) {
    throw new Error(
      `Distributed rate limiter unavailable: ${
        error.message ?? "unknown error"
      }`,
    );
  }

  const row = Array.isArray(data) ? data[0] : data;
  if (!isRateLimitRow(row)) {
    throw new Error("Distributed rate limiter returned an invalid response.");
  }

  return {
    allowed: row.allowed,
    remaining: Number(row.remaining),
    resetAt: row.reset_at,
  };
}

function isRateLimitRow(value: unknown): value is {
  allowed: boolean;
  remaining: number;
  reset_at: string;
} {
  if (!value || typeof value !== "object") return false;
  const row = value as Record<string, unknown>;
  return typeof row.allowed === "boolean" &&
    typeof row.remaining === "number" &&
    typeof row.reset_at === "string";
}

export function rateLimitHeaders(
  result: DistributedRateLimitResult,
): Record<string, string> {
  const resetSeconds = Math.max(
    1,
    Math.ceil((new Date(result.resetAt).getTime() - Date.now()) / 1000),
  );
  return {
    "Retry-After": String(resetSeconds),
    "X-RateLimit-Remaining": String(result.remaining),
    "X-RateLimit-Reset": result.resetAt,
  };
}
