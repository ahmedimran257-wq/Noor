# Silarah India release gate and post-launch market backlog

Last technical review: 11 August 2026

This is an engineering launch gate, not a legal opinion. A country appearing in
the 198-country product catalog means that country selection, metadata and
location matching are technically supported. It does **not** mean Silarah has
been legally cleared, registered, taxed, priced or store-tested there.

## Verified in engineering

- The client and hosted staging database contain the same 198 ISO country
  records, including dialing code, currency, default language and pricing tier.
- Ten production UI locales (`ar`, `bn`, `de`, `en`, `fr`, `hi`, `id`, `ms`,
  `tr`, `ur`) have the same complete message-key set. Native-speaker review is
  still required before marketing any locale as professionally translated.
- Authenticated city lookup and signed city resolution passed live samples for
  Australia, Canada, Egypt, India, Indonesia, Malaysia, Pakistan, Turkey, the
  United Kingdom and the United States. Cities are obtained from a live global
  provider and cached; there is no finite bundled list of every city worldwide.
- Backend function authentication boundaries and tokenless durable notification
  delivery pass on staging. Separate least-privilege Firebase senders are now
  configured for staging and production, and real background delivery passed
  on the connected Android 13 device in both environments.
- The bounded 50-VU staging baseline completed 9,558 authenticated requests
  with no HTTP failures; this is not a million-user capacity certification.

## India launch position

- The live launch-country catalogue is server-restricted to India. Global
  country metadata remains engineering capability, not a public launch claim.
- Policy bundle 2.2.0 identifies individual operator and grievance officer
  Imran Ahmed, provides an authenticated machine-readable data archive, and
  documents access, correction, consent withdrawal, deletion, retention,
  grievance and appeal routes.
- Government-ID collection is retired. The optional photo trust check uses no
  face template, automated identity match or age estimation; temporary guided
  captures are deleted after review and within 48 hours.
- The Google Play developer identity and public contact must be checked against
  the published operator wording before production submission. A qualified
  Indian lawyer should still review the final production policies and actual
  operations; engineering controls cannot guarantee legal immunity.

## Post-launch country-expansion blockers requiring owner or counsel input

1. If the operator, address or business form changes, update Google Play, Terms,
   Privacy Policy, invoices and grievance disclosures together.
2. Decide the initial country launch allowlist. Legal clearance must be tracked
   per country; an unchecked country must not be described as compliant.
3. Execute processor/data-transfer agreements and record the hosting region,
   subprocessors, retention schedule, breach process and government-request
   process.
4. Appoint any required privacy officer, grievance officer, EU/UK representative
   or local representative, and publish their valid contact details.
5. Have qualified counsel review sensitive religious, temporary photo-check,
   matrimonial and moderation processing in every launch market.
6. Complete local consumer, auto-renewal, refund, tax, invoicing, sanctions,
   content, online-safety and law-enforcement-response reviews.
7. Upload/verify the Apple APNs authentication key in Firebase and prove one
   real iOS token on a physical iPhone. Android operating-system delivery is
   verified; an iOS build cannot be built or physically tested from Windows.
8. Test monthly purchase, annual purchase, cancellation, restore, renewal,
   expiry, refund, billing retry and webhook idempotency on real Play and Apple
   sandboxes in every pricing region that will launch.

## Priority jurisdiction review matrix

| Market | Engineering control already present | Required external clearance |
|---|---|---|
| India | Versioned consent, authenticated export, correction/deletion routes, grievance timelines, no government-ID or biometric-template flow | Confirm staged commencement duties under the [Digital Personal Data Protection Rules, 2025](https://www.meity.gov.in/documents/act-and-policies/digital-personal-data-protection-rules-2025-gDOxUjMtQWa), operator contact, notices, retention, transfers and adult-only position |
| EU/EEA | Consent records, access/correction/export/deletion controls, processor disclosure | Confirm special-category basis, DPIA, controller identity, representative/DPO requirements, regulator/complaint wording and transfer mechanism under the [European Commission GDPR rights guidance](https://commission.europa.eu/law/law-topic/data-protection/reform/rights-citizens/how-my-personal-data-protected/how-should-my-consent-be-requested_en) and [international-transfer rules](https://commission.europa.eu/law/law-topic/data-protection/international-dimension-data-protection/rules-international-data-transfers_en) |
| United Kingdom | Same privacy controls and complaint route | Review UK GDPR/DPA changes introduced by the [Data (Use and Access) Act 2025](https://www.gov.uk/guidance/data-use-and-access-act-2025-data-protection-and-privacy-changes), representative/ICO obligations and international transfers |
| Turkey | Explicit sensitive-data disclosure, correction/deletion path, private verification | Obtain KVKK review for religion/sect and biometric processing, notices, consent exceptions, data-subject requests and transfers under the [official KVKK law](https://www.kvkk.gov.tr/Icerik/6649/Personal-Data-Protection-Law) |
| California/United States | No sale/behavioural-ad claim; access, correction and deletion paths | Determine CCPA/CPRA applicability and implement any required notice-at-collection, sensitive-data limitation and opt-out handling using the [California Attorney General guidance](https://oag.ca.gov/privacy/ccpa) |
| UAE | Consent, rights, security and transfer disclosures | Confirm federal/free-zone scope, controller/processor duties, breach handling, transfer mechanism and consumer rules under the [official UAE data-protection overview](https://u.ae/en/about-the-uae/digital-uae/data/data-protection-laws.) |
| Saudi Arabia | Sensitive-data controls, private verification, retention controls | Obtain local PDPL review for lawful basis, sensitive/biometric processing, transfers, registration/representative and breach duties using the [official Saudi PDPL](https://sdaia.gov.sa/en/SDAIA/about/Documents/Personal%20Data%20English%20V2-23April2023-%20Reviewed-.pdf) |
| Canada | Consent, transparency, access/correction/deletion and safeguards | Determine federal/provincial scope, breach records/reporting and cross-border accountability under the [Office of the Privacy Commissioner PIPEDA guidance](https://www.priv.gc.ca/en/privacy-topics/privacy-laws-in-canada/the-personal-information-protection-and-electronic-documents-act-pipeda/) |
| Pakistan and all other catalog markets | Global country/location mechanics | Country-specific counsel review is still unverified; keep status blocked until an authoritative-law review and written owner approval are recorded |

## Payment-region acceptance matrix

For every intended store region, retain evidence for:

- correct monthly/annual products and the `premium` entitlement;
- local currency and store-supplied price (never a hardcoded amount);
- purchase, pending/declined purchase, restore, renewal, cancellation, expiry,
  refund and webhook replay;
- tax-inclusive display, trial/intro eligibility, price-change consent and local
  refund/cancellation copy;
- RevenueCat current-offering fallback and country/store targeting.

Google documents regional eligibility testing through Play Billing Lab and
license testers in its [billing test guide](https://developer.android.com/google/play/billing/test).
Apple supports changing a sandbox account's country/region for storefront tests
in its [StoreKit sandbox guide](https://developer.apple.com/documentation/storekit/testing-in-app-purchases-with-sandbox).
RevenueCat country and custom-attribute rules are described in its
[Targeting documentation](https://www.revenuecat.com/docs/tools/targeting).

## Release decision

Engineering status is **India staging-ready for expanded functional and load
tests** after the release/device checks are completed. Worldwide production
remains **blocked** until Apple APNs/device access, store sandbox access and
written country-by-country legal approvals are available.
