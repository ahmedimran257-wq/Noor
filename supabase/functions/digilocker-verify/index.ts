import { createClient } from "@supabase/supabase-js";
import { corsHeaders, handleCors } from "../_shared/cors.ts";
import {
  readResponseBytes,
  readResponseJson,
} from "../_shared/bounded_response.ts";
import {
  consumeDistributedRateLimit,
  rateLimitHeaders,
} from "../_shared/distributed_rate_limit.ts";
import {
  decideVerification,
  type DigiLockerDecision,
  extractDocumentIdentity,
  type IssuedDocumentMetadata,
  parseAccountIdentity,
  selectIssuedIdentityDocument,
} from "./digilocker_verification_policy.ts";

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
const clientId = Deno.env.get("DIGILOCKER_CLIENT_ID") ?? "";
const clientSecret = Deno.env.get("DIGILOCKER_CLIENT_SECRET") ?? "";
const evidenceSecret = Deno.env.get("DIGILOCKER_EVIDENCE_HMAC_SECRET") ?? "";
const redirectUri = Deno.env.get("DIGILOCKER_REDIRECT_URI") ??
  "https://silarah.com/auth/digilocker/callback";

const tokenUrl = Deno.env.get("DIGILOCKER_TOKEN_URL") ??
  "https://digilocker.meripehchaan.gov.in/public/oauth2/2/token";
const userDetailsUrl = Deno.env.get("DIGILOCKER_USER_DETAILS_URL") ??
  "https://digilocker.meripehchaan.gov.in/public/oauth2/1/user";
const issuedDocumentsUrl = Deno.env.get("DIGILOCKER_ISSUED_DOCUMENTS_URL") ??
  "https://digilocker.meripehchaan.gov.in/public/oauth2/2/files/issued";
const documentXmlBaseUrl = Deno.env.get("DIGILOCKER_DOCUMENT_XML_BASE_URL") ??
  "https://digilocker.meripehchaan.gov.in/public/oauth2/1/xml";
const eAadhaarXmlUrl = Deno.env.get("DIGILOCKER_EAADHAAR_XML_URL") ??
  "https://digilocker.meripehchaan.gov.in/public/oauth2/3/xml/eaadhaar";
const revokeUrl = Deno.env.get("DIGILOCKER_REVOKE_URL") ??
  "https://digilocker.meripehchaan.gov.in/public/oauth2/1/revoke";
const allowedDocumentTypes = new Set(
  (Deno.env.get("DIGILOCKER_IDENTITY_DOCUMENT_TYPES") ??
    "ADHAR,PANCR,DRVLC")
    .split(",")
    .map((value) => value.trim().toUpperCase())
    .filter(Boolean),
);

const FETCH_TIMEOUT = 15_000;

Deno.serve(async (request) => {
  const corsResponse = handleCors(request);
  if (corsResponse) return corsResponse;
  if (request.method !== "POST") {
    return response(405, {
      status: "invalid_request",
      message: "Method not allowed.",
    });
  }
  if (!clientId || !clientSecret || evidenceSecret.length < 32) {
    return response(503, {
      status: "unavailable",
      message: "DigiLocker evidence verification is not configured.",
    });
  }

  let accessToken = "";
  try {
    const authorization = request.headers.get("Authorization");
    if (!authorization?.startsWith("Bearer ")) {
      return response(401, {
        status: "unauthenticated",
        message: "Authentication required.",
      });
    }
    const userClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authorization } },
      auth: { autoRefreshToken: false, persistSession: false },
    });
    const { data: { user }, error } = await userClient.auth.getUser();
    if (error || !user) {
      return response(401, {
        status: "unauthenticated",
        message: "Authentication required.",
      });
    }

    const body = await request.json();
    const code = typeof body?.code === "string" ? body.code.trim() : "";
    const suppliedRedirect = typeof body?.redirect_uri === "string"
      ? body.redirect_uri.trim()
      : "";
    const codeVerifier = typeof body?.code_verifier === "string"
      ? body.code_verifier.trim()
      : "";
    if (
      !code ||
      suppliedRedirect !== redirectUri ||
      !/^[A-Za-z0-9._~-]{43,128}$/.test(codeVerifier)
    ) {
      return response(400, {
        status: "invalid_request",
        message: "Invalid DigiLocker authorization response.",
      });
    }

    const admin = createClient(supabaseUrl, serviceRoleKey, {
      auth: { autoRefreshToken: false, persistSession: false },
    });
    const rateLimit = await consumeDistributedRateLimit(admin, {
      scope: "digilocker_verification",
      subject: user.id,
      maxRequests: 5,
      windowSeconds: 24 * 60 * 60,
    });
    if (!rateLimit.allowed) {
      return new Response(
        JSON.stringify({
          status: "rate_limited",
          message:
            "Verification attempt limit reached. Please try again later.",
        }),
        {
          status: 429,
          headers: {
            ...corsHeaders,
            ...rateLimitHeaders(rateLimit),
            "Content-Type": "application/json",
            "Cache-Control": "no-store",
          },
        },
      );
    }
    const { data: profile, error: profileError } = await admin
      .from("profiles")
      .select("first_name,last_name,date_of_birth,country_code")
      .eq("user_id", user.id)
      .maybeSingle();
    if (profileError) throw profileError;
    if (!profile || profile.country_code !== "IN") {
      return response(409, {
        status: "unavailable",
        message: "DigiLocker verification is available for Indian profiles.",
      });
    }

    const tokenResponse = await fetchWithTimeout(tokenUrl, {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: new URLSearchParams({
        grant_type: "authorization_code",
        code,
        client_id: clientId,
        client_secret: clientSecret,
        redirect_uri: redirectUri,
        code_verifier: codeVerifier,
      }),
    });
    if (!tokenResponse.ok) {
      return response(422, {
        status: "authorization_failed",
        message: "DigiLocker authorization was not completed.",
      });
    }
    const tokenPayload = await readResponseJson(
      tokenResponse,
      64 * 1024,
    ) as Record<string, unknown>;
    accessToken = typeof tokenPayload.access_token === "string"
      ? tokenPayload.access_token
      : "";
    if (!accessToken) {
      return response(502, {
        status: "provider_error",
        message: "DigiLocker did not return a usable authorization token.",
      });
    }

    const bearerHeaders = { Authorization: `Bearer ${accessToken}` };
    const accountResponse = await fetchWithTimeout(userDetailsUrl, {
      headers: bearerHeaders,
    });
    const accountPayload = accountResponse.ok
      ? await readResponseJson(
        accountResponse,
        256 * 1024,
      ) as Record<string, unknown>
      : {};
    const accountIdentity = accountResponse.ok
      ? parseAccountIdentity(accountPayload)
      : null;

    let issuedListPayload: unknown = null;
    const issuedListResponse = await fetchWithTimeout(issuedDocumentsUrl, {
      headers: bearerHeaders,
    });
    if (issuedListResponse.ok) {
      issuedListPayload = await readResponseJson(
        issuedListResponse,
        512 * 1024,
      );
    }

    let document: IssuedDocumentMetadata | null = null;
    let documentSource = "";
    let documentXml = "";
    let documentIntegrityVerified = false;

    // Prefer the account's e-Aadhaar because it is a government identity
    // document, then fall back to a consented issued PAN/DL/Aadhaar XML file.
    if (accountIdentity?.eAadhaarAvailable) {
      const eAadhaarResponse = await fetchWithTimeout(eAadhaarXmlUrl, {
        headers: bearerHeaders,
      });
      if (eAadhaarResponse.ok) {
        const bytes = await readResponseBytes(
          eAadhaarResponse,
          2 * 1024 * 1024,
        );
        documentIntegrityVerified = await verifyDigiLockerHmac(
          bytes,
          eAadhaarResponse.headers.get("hmac"),
        );
        documentXml = new TextDecoder().decode(bytes);
        documentSource = "eaadhaar";
        document = {
          uri: "eaadhaar",
          doctype: "ADHAR",
          issuerId: "in.gov.uidai",
          issuer: "UIDAI",
          description: "e-Aadhaar",
          mime: "application/xml",
        };
      }
    }

    if (!documentXml) {
      const selected = selectIssuedIdentityDocument(
        issuedListPayload,
        allowedDocumentTypes,
      );
      if (selected) {
        const xmlUrl = `${documentXmlBaseUrl.replace(/\/$/, "")}/${
          encodeURIComponent(selected.uri)
        }`;
        const xmlResponse = await fetchWithTimeout(xmlUrl, {
          headers: bearerHeaders,
        });
        if (xmlResponse.ok) {
          const bytes = await readResponseBytes(
            xmlResponse,
            2 * 1024 * 1024,
          );
          documentIntegrityVerified = await verifyDigiLockerHmac(
            bytes,
            xmlResponse.headers.get("hmac"),
          );
          documentXml = new TextDecoder().decode(bytes);
          documentSource = "issued_document";
          document = selected;
        }
      }
    }

    const documentIdentity = documentXml
      ? extractDocumentIdentity(documentXml)
      : null;
    const profileName = `${profile.first_name ?? ""} ${profile.last_name ?? ""}`
      .trim();
    const profileDob = String(profile.date_of_birth ?? "");
    const decision = decideVerification({
      profileName,
      profileDob,
      accountIdentity,
      documentIdentity,
      documentIntegrityVerified,
      issuedDocumentFetched: Boolean(documentXml),
    });

    const documentPayloadSha256 = documentXml
      ? await sha256Hex(new TextEncoder().encode(documentXml))
      : null;
    const evidence = {
      p_user_id: user.id,
      p_decision: decision.decision,
      p_failure_code: decision.failureCode,
      p_provider_subject_hmac: accountIdentity
        ? await evidenceHmac("subject", accountIdentity.digilockerId)
        : null,
      p_provider_reference_hmac: accountIdentity?.referenceKey
        ? await evidenceHmac("reference", accountIdentity.referenceKey)
        : null,
      p_profile_snapshot_hmac: await evidenceHmac(
        "profile",
        `${profileName}|${profileDob}`,
      ),
      p_document_uri_hmac: document?.uri
        ? await evidenceHmac("document_uri", document.uri)
        : null,
      p_document_payload_sha256: documentPayloadSha256,
      p_document_type: document?.doctype ?? null,
      p_issuer_id: document?.issuerId ?? null,
      p_issuer_name: document?.issuer ?? null,
      p_document_source: documentSource || null,
      p_provider_profile_fetched: accountIdentity != null,
      p_issued_document_fetched: Boolean(documentXml),
      p_document_integrity_verified: documentIntegrityVerified,
      p_account_name_match: decision.accountNameMatch,
      p_account_dob_match: decision.accountDobMatch,
      p_document_name_match: decision.documentNameMatch,
      p_document_dob_match: decision.documentDobMatch,
      p_consent_valid_until: unixTimestamp(tokenPayload?.consent_valid_till),
      p_provider_metadata: {
        token_scope: safeScope(tokenPayload?.scope),
        account_endpoint_version: "1",
        issued_documents_endpoint_version: "2",
        document_xml_integrity: "hmac-sha256",
      },
    };
    const { error: evidenceError } = await admin.rpc(
      "record_digilocker_verification_result",
      evidence,
    );
    if (evidenceError) throw evidenceError;

    return handledDecision(decision.decision, decision.failureCode);
  } catch (error) {
    console.error(
      "[digilocker-verify] evidence verification failed",
      safeError(error),
    );
    return response(500, {
      status: "provider_error",
      message:
        "Unable to verify DigiLocker evidence. No verification badge was granted.",
    });
  } finally {
    if (accessToken) await revokeAccessToken(accessToken);
  }
});

function handledDecision(
  decision: DigiLockerDecision,
  failureCode: string | null,
): Response {
  if (decision === "verified") {
    return response(200, {
      status: "verified",
      message:
        "Your DigiLocker identity and issued document match your Silarah profile.",
    });
  }
  if (decision === "identity_mismatch") {
    const field = failureCode?.includes("dob") ? "date of birth" : "name";
    return response(200, {
      status: "identity_mismatch",
      reason: failureCode,
      message:
        `Your ${field} does not match your Silarah profile. No badge was granted.`,
    });
  }
  return response(200, {
    status: "insufficient_evidence",
    reason: failureCode,
    message:
      "DigiLocker did not provide a signed, machine-readable identity document. No badge was granted.",
  });
}

async function fetchWithTimeout(
  url: string,
  init: RequestInit,
): Promise<Response> {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), FETCH_TIMEOUT);
  try {
    return await fetch(url, { ...init, signal: controller.signal });
  } finally {
    clearTimeout(timeout);
  }
}

async function verifyDigiLockerHmac(
  bytes: Uint8Array,
  supplied: string | null,
): Promise<boolean> {
  if (!supplied) return false;
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(clientSecret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = new Uint8Array(
    await crypto.subtle.sign("HMAC", key, asArrayBuffer(bytes)),
  );
  const calculated = bytesToBase64(signature);
  return constantTimeEqual(calculated, supplied.trim());
}

async function evidenceHmac(context: string, value: string): Promise<string> {
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(evidenceSecret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign(
    "HMAC",
    key,
    new TextEncoder().encode(`${context}\u0000${value}`),
  );
  return bytesToHex(new Uint8Array(signature));
}

async function sha256Hex(bytes: Uint8Array): Promise<string> {
  return bytesToHex(
    new Uint8Array(
      await crypto.subtle.digest("SHA-256", asArrayBuffer(bytes)),
    ),
  );
}

function asArrayBuffer(bytes: Uint8Array): ArrayBuffer {
  return bytes.buffer.slice(
    bytes.byteOffset,
    bytes.byteOffset + bytes.byteLength,
  ) as ArrayBuffer;
}

async function revokeAccessToken(token: string): Promise<void> {
  try {
    await fetchWithTimeout(revokeUrl, {
      method: "POST",
      headers: {
        Authorization: `Basic ${btoa(`${clientId}:${clientSecret}`)}`,
        "Content-Type": "application/x-www-form-urlencoded",
      },
      body: new URLSearchParams({ token, token_type_hint: "access_token" }),
    });
  } catch (error) {
    console.error(
      "[digilocker-verify] token revocation failed",
      safeError(error),
    );
  }
}

function unixTimestamp(value: unknown): string | null {
  const seconds = typeof value === "number"
    ? value
    : typeof value === "string"
    ? Number(value)
    : NaN;
  if (!Number.isFinite(seconds) || seconds <= 0) return null;
  return new Date(seconds * 1000).toISOString();
}

function safeScope(value: unknown): string[] {
  if (typeof value !== "string") return [];
  return value.split(/\s+/).filter((part) =>
    ["openid", "files.issueddocs"].includes(part)
  );
}

function bytesToBase64(bytes: Uint8Array): string {
  let value = "";
  for (const byte of bytes) value += String.fromCharCode(byte);
  return btoa(value);
}

function bytesToHex(bytes: Uint8Array): string {
  return Array.from(bytes).map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

function constantTimeEqual(left: string, right: string): boolean {
  const a = new TextEncoder().encode(left);
  const b = new TextEncoder().encode(right);
  let mismatch = a.length ^ b.length;
  const length = Math.max(a.length, b.length);
  for (let index = 0; index < length; index++) {
    mismatch |= (a[index % a.length] ?? 0) ^ (b[index % b.length] ?? 0);
  }
  return mismatch === 0;
}

function safeError(error: unknown): Record<string, string> {
  if (error instanceof Error) {
    return { name: error.name, message: error.message };
  }
  return { name: "UnknownError", message: "Unknown provider failure" };
}

function response(status: number, body: Record<string, unknown>): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
      "Cache-Control": "no-store",
    },
  });
}
