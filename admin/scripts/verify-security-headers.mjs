import process from "node:process";

const baseUrl = new URL(
  process.env.ADMIN_BASE_URL ?? "https://admin.silarah.com",
);

const requiredCspDirectives = [
  "default-src 'self'",
  "script-src 'self'",
  "style-src 'self'",
  "frame-ancestors 'none'",
  "object-src 'none'",
  "base-uri 'none'",
  "form-action 'self'",
];

function assertSecurityHeaders(path, headers) {
  const hsts = headers.get("strict-transport-security") ?? "";
  if (
    !hsts.includes("max-age=63072000") ||
    !hsts.includes("includeSubDomains") ||
    !hsts.includes("preload")
  ) {
    throw new Error(`${path}: strict HSTS policy is missing`);
  }

  const csp = headers.get("content-security-policy") ?? "";
  for (const directive of requiredCspDirectives) {
    if (!csp.includes(directive)) {
      throw new Error(`${path}: CSP is missing ${directive}`);
    }
  }
  if (csp.includes("'unsafe-inline'")) {
    throw new Error(`${path}: CSP permits unsafe inline content`);
  }
  if (headers.get("x-content-type-options") !== "nosniff") {
    throw new Error(`${path}: MIME sniffing protection is missing`);
  }
  if (headers.get("x-frame-options") !== "DENY") {
    throw new Error(`${path}: clickjacking protection is missing`);
  }
}

async function verifyPath(path) {
  const response = await fetch(new URL(path, baseUrl), {
    method: "HEAD",
    redirect: "manual",
  });
  assertSecurityHeaders(path, response.headers);
}

for (const path of [
  "/",
  "/login",
  "/dashboard",
  "/definitely-not-a-real-page",
]) {
  await verifyPath(path);
}

const loginResponse = await fetch(new URL("/login", baseUrl));
const loginHtml = await loginResponse.text();
const assetMatch = loginHtml.match(
  /(?:src|href)="(?<path>\/_next\/static\/[^"]+)"/,
);
if (!assetMatch?.groups?.path) {
  throw new Error("Could not locate a deployed Next.js static asset");
}

const assetUrl = new URL(assetMatch.groups.path.replaceAll("&amp;", "&"), baseUrl);
assetUrl.searchParams.set("security-audit", Date.now().toString());
const assetResponse = await fetch(assetUrl, {
  method: "HEAD",
  redirect: "manual",
});
assertSecurityHeaders(assetUrl.pathname, assetResponse.headers);

console.log("Admin production security headers verified.");
