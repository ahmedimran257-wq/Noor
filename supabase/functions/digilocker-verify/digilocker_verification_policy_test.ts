import { assertEquals } from "@std/assert";
import {
  decideVerification,
  extractDocumentIdentity,
  namesMatch,
  parseAccountIdentity,
  selectIssuedIdentityDocument,
} from "./digilocker_verification_policy.ts";

const profile = { profileName: "Amina Noor Khan", profileDob: "1996-07-21" };
const accountIdentity = parseAccountIdentity({
  digilockerid: "123e4567-e89b-12d3-a456-426655440000",
  name: "Amina Noor Khan",
  dob: "21071996",
  eaadhaar: "Y",
});
const documentIdentity = extractDocumentIdentity(`
  <Certificate status="A">
    <IssuedTo><Person name="AMINA NOOR KHAN" dob="21-07-1996" /></IssuedTo>
  </Certificate>
`);

Deno.test("token/account success alone never grants DigiLocker verification", () => {
  assertEquals(
    decideVerification({
      ...profile,
      accountIdentity,
      documentIdentity: null,
      documentIntegrityVerified: false,
      issuedDocumentFetched: false,
    }).decision,
    "insufficient_evidence",
  );
});

Deno.test("strong verification requires matching account and authenticated document", () => {
  assertEquals(
    decideVerification({
      ...profile,
      accountIdentity,
      documentIdentity,
      documentIntegrityVerified: true,
      issuedDocumentFetched: true,
    }),
    {
      decision: "verified",
      failureCode: null,
      accountNameMatch: true,
      accountDobMatch: true,
      documentNameMatch: true,
      documentDobMatch: true,
    },
  );
});

Deno.test("a document HMAC failure cannot grant verification", () => {
  const result = decideVerification({
    ...profile,
    accountIdentity,
    documentIdentity,
    documentIntegrityVerified: false,
    issuedDocumentFetched: true,
  });
  assertEquals(result.decision, "insufficient_evidence");
  assertEquals(result.failureCode, "document_integrity_unverified");
});

Deno.test("name and exact DOB mismatches fail closed", () => {
  const result = decideVerification({
    profileName: "Amina Noor Khan",
    profileDob: "1997-07-21",
    accountIdentity,
    documentIdentity,
    documentIntegrityVerified: true,
    issuedDocumentFetched: true,
  });
  assertEquals(result.decision, "identity_mismatch");
  assertEquals(result.failureCode, "account_dob_mismatch");
});

Deno.test("name comparison tolerates order and punctuation but not missing names", () => {
  assertEquals(namesMatch("Khan, Amina Noor", "Amina Noor Khan"), true);
  assertEquals(namesMatch("Amina Khan", "Amina Noor Khan"), false);
});

Deno.test("only issued XML identity documents are selected", () => {
  const selected = selectIssuedIdentityDocument({
    items: [
      {
        type: "file",
        uri: "uploaded-screenshot",
        doctype: "PANCR",
        issuerid: "",
        issuer: "",
        mime: "application/xml",
      },
      {
        type: "file",
        uri: "in.gov.incometax-PANCR-123",
        doctype: "PANCR",
        issuerid: "in.gov.incometax",
        issuer: "Income Tax Department",
        mime: ["application/pdf", "application/xml"],
        description: "PAN Card",
      },
    ],
  }, new Set(["ADHAR", "PANCR", "DRVLC"]));
  assertEquals(selected?.uri, "in.gov.incometax-PANCR-123");
});

Deno.test("year-only document data is insufficient for exact DOB matching", () => {
  assertEquals(
    extractDocumentIdentity(
      '<UidData><Poi name="Amina Noor Khan" yob="1996" /></UidData>',
    ),
    null,
  );
});
