export type DigiLockerDecision =
  | "verified"
  | "identity_mismatch"
  | "insufficient_evidence"
  | "provider_error";

export interface DigiLockerAccountIdentity {
  digilockerId: string;
  name: string;
  dob: string;
  eAadhaarAvailable: boolean;
  referenceKey?: string;
}

export interface IssuedDocumentMetadata {
  uri: string;
  doctype: string;
  issuerId: string;
  issuer: string;
  description: string;
  mime: unknown;
}

export interface ExtractedDocumentIdentity {
  name: string;
  dob: string;
  active: boolean;
}

export interface VerificationInputs {
  profileName: string;
  profileDob: string;
  accountIdentity: DigiLockerAccountIdentity | null;
  documentIdentity: ExtractedDocumentIdentity | null;
  documentIntegrityVerified: boolean;
  issuedDocumentFetched: boolean;
}

export interface VerificationDecision {
  decision: DigiLockerDecision;
  failureCode: string | null;
  accountNameMatch: boolean;
  accountDobMatch: boolean;
  documentNameMatch: boolean;
  documentDobMatch: boolean;
}

export function parseAccountIdentity(
  value: Record<string, unknown>,
): DigiLockerAccountIdentity | null {
  const digilockerId = stringValue(value.digilockerid);
  const name = stringValue(value.name);
  const dob = canonicalDate(stringValue(value.dob));
  if (!digilockerId || !name || !dob) return null;
  return {
    digilockerId,
    name,
    dob,
    eAadhaarAvailable: stringValue(value.eaadhaar).toUpperCase() === "Y",
    referenceKey: stringValue(value.reference_key) || undefined,
  };
}

export function selectIssuedIdentityDocument(
  value: unknown,
  allowedDocumentTypes: ReadonlySet<string>,
): IssuedDocumentMetadata | null {
  if (!value || typeof value !== "object") return null;
  const items = (value as Record<string, unknown>).items;
  if (!Array.isArray(items)) return null;

  for (const candidate of items) {
    if (!candidate || typeof candidate !== "object") continue;
    const row = candidate as Record<string, unknown>;
    const doctype = stringValue(row.doctype).toUpperCase();
    const uri = stringValue(row.uri);
    const issuerId = stringValue(row.issuerid);
    const issuer = stringValue(row.issuer);
    const mime = row.mime;
    if (
      stringValue(row.type).toLowerCase() !== "file" ||
      !allowedDocumentTypes.has(doctype) ||
      !uri ||
      !issuerId ||
      !issuer ||
      !hasXmlMime(mime)
    ) {
      continue;
    }
    return {
      uri,
      doctype,
      issuerId,
      issuer,
      description: stringValue(row.description) || stringValue(row.name),
      mime,
    };
  }
  return null;
}

export function extractDocumentIdentity(
  xml: string,
): ExtractedDocumentIdentity | null {
  // DigiLocker's standard certificate XML uses IssuedTo/Person. e-Aadhaar
  // uses Poi. Do not inspect arbitrary elements because a document can also
  // contain relatives' names and dates.
  const identityTag = xml.match(/<(?:[\w-]+:)?(?:Person|Poi)\b[^>]*>/i)?.[0];
  if (!identityTag) return null;
  const name = xmlAttribute(identityTag, "name");
  const dob = canonicalDate(
    xmlAttribute(identityTag, "dob") ||
      xmlAttribute(identityTag, "dateOfBirth") ||
      xmlAttribute(identityTag, "birthdate"),
  );
  if (!name || !dob) return null;

  const certificateTag = xml.match(/<(?:[\w-]+:)?Certificate\b[^>]*>/i)?.[0];
  const certificateStatus = certificateTag
    ? xmlAttribute(certificateTag, "status").toUpperCase()
    : "A";
  return {
    name: decodeXmlEntities(name),
    dob,
    active: !certificateStatus || certificateStatus === "A",
  };
}

export function decideVerification(
  input: VerificationInputs,
): VerificationDecision {
  const accountNameMatch = input.accountIdentity != null &&
    namesMatch(input.profileName, input.accountIdentity.name);
  const accountDobMatch = input.accountIdentity != null &&
    datesMatch(input.profileDob, input.accountIdentity.dob);
  const documentNameMatch = input.documentIdentity != null &&
    namesMatch(input.profileName, input.documentIdentity.name);
  const documentDobMatch = input.documentIdentity != null &&
    datesMatch(input.profileDob, input.documentIdentity.dob);
  const base = {
    accountNameMatch,
    accountDobMatch,
    documentNameMatch,
    documentDobMatch,
  };

  if (!input.accountIdentity) {
    return {
      ...base,
      decision: "insufficient_evidence",
      failureCode: "account_identity_missing",
    };
  }
  if (!accountNameMatch) {
    return {
      ...base,
      decision: "identity_mismatch",
      failureCode: "account_name_mismatch",
    };
  }
  if (!accountDobMatch) {
    return {
      ...base,
      decision: "identity_mismatch",
      failureCode: "account_dob_mismatch",
    };
  }
  if (!input.issuedDocumentFetched || !input.documentIdentity) {
    return {
      ...base,
      decision: "insufficient_evidence",
      failureCode: "issued_identity_document_missing",
    };
  }
  if (!input.documentIntegrityVerified) {
    return {
      ...base,
      decision: "insufficient_evidence",
      failureCode: "document_integrity_unverified",
    };
  }
  if (!input.documentIdentity.active) {
    return {
      ...base,
      decision: "insufficient_evidence",
      failureCode: "document_not_active",
    };
  }
  if (!documentNameMatch) {
    return {
      ...base,
      decision: "identity_mismatch",
      failureCode: "document_name_mismatch",
    };
  }
  if (!documentDobMatch) {
    return {
      ...base,
      decision: "identity_mismatch",
      failureCode: "document_dob_mismatch",
    };
  }
  return { ...base, decision: "verified", failureCode: null };
}

export function namesMatch(left: string, right: string): boolean {
  const a = normalizedNameTokens(left);
  const b = normalizedNameTokens(right);
  return a.length > 0 && a.length === b.length && a.every((v, i) => v === b[i]);
}

export function datesMatch(left: string, right: string): boolean {
  const a = canonicalDate(left);
  const b = canonicalDate(right);
  return a.length > 0 && a === b;
}

export function canonicalDate(value: string): string {
  const input = value.trim();
  let year = 0;
  let month = 0;
  let day = 0;
  if (/^\d{8}$/.test(input)) {
    day = Number(input.slice(0, 2));
    month = Number(input.slice(2, 4));
    year = Number(input.slice(4, 8));
  } else {
    const iso = input.match(/^(\d{4})[-\/]([01]?\d)[-\/]([0-3]?\d)$/);
    const local = input.match(/^([0-3]?\d)[-\/]([01]?\d)[-\/](\d{4})$/);
    if (iso) {
      year = Number(iso[1]);
      month = Number(iso[2]);
      day = Number(iso[3]);
    } else if (local) {
      day = Number(local[1]);
      month = Number(local[2]);
      year = Number(local[3]);
    } else {
      return "";
    }
  }
  const date = new Date(Date.UTC(year, month - 1, day));
  if (
    date.getUTCFullYear() !== year ||
    date.getUTCMonth() !== month - 1 ||
    date.getUTCDate() !== day
  ) return "";
  return `${year.toString().padStart(4, "0")}-${
    month.toString().padStart(2, "0")
  }-${day.toString().padStart(2, "0")}`;
}

function normalizedNameTokens(value: string): string[] {
  return value
    .normalize("NFKD")
    .replace(/[\u0300-\u036f]/g, "")
    .toLocaleLowerCase("en-IN")
    .replace(/[^\p{L}\p{N}]+/gu, " ")
    .trim()
    .split(/\s+/)
    .filter(Boolean)
    .sort();
}

function hasXmlMime(value: unknown): boolean {
  if (typeof value === "string") {
    return value.toLowerCase().includes("application/xml");
  }
  if (Array.isArray(value)) {
    return value.some((item) =>
      typeof item === "string"
        ? item.toLowerCase().includes("application/xml")
        : item && typeof item === "object" &&
          Object.keys(item as Record<string, unknown>).some((key) =>
            key.toLowerCase().includes("application/xml")
          )
    );
  }
  return false;
}

function xmlAttribute(tag: string, attribute: string): string {
  const escaped = attribute.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
  return tag.match(new RegExp(`\\b${escaped}\\s*=\\s*["']([^"']*)["']`, "i"))
    ?.[1] ?? "";
}

function decodeXmlEntities(value: string): string {
  return value
    .replace(/&quot;/gi, '"')
    .replace(/&apos;/gi, "'")
    .replace(/&lt;/gi, "<")
    .replace(/&gt;/gi, ">")
    .replace(/&amp;/gi, "&");
}

function stringValue(value: unknown): string {
  return typeof value === "string" ? value.trim() : "";
}
