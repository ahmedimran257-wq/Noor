# Silarah product backlog

This backlog records product ideas only. An item is not approved for a release
until its UX, privacy, database, localization, entitlement and test requirements
have been designed and accepted.

## Premium candidates

### Mutual Compatibility Insights

Status: implemented behind the canonical Premium entitlement; pending final
staging migration and two-account release-candidate QA.

Show a factual, explainable comparison on a member's profile using information
that both members already supplied. Examples include shared preferences and
whether age range, location, marriage timeline, relocation, marital-status and
family preferences align.

Guardrails:

- Never describe the result as a probability of marriage or a guarantee.
- Explain every displayed match or mismatch; do not use an opaque AI score.
- Respect blocked, banned, reported and Incognito states.
- Return criterion-level alignment only; never reveal another member's raw
  preference values.
- Compute from existing profile/preference data and avoid paid external APIs.
- Keep the summary Premium-gated on the server as well as in the client, and
  remove raw partner-preference fields from discovery payloads entirely.
- Add localization, accessibility, caching and two-account entitlement tests
  before release.

Implementation notes:

- Calculated only when a Premium member explicitly opens a profile, never for
  every discovery card.
- Uses a five-minute account-scoped cache and in-flight request coalescing.
- Server RPC verifies Premium, profile authorization and safety boundaries.

### Private Shortlists, Family Notes & Reminders

Status: implemented behind the canonical Premium entitlement; pending final
staging migration and two-account release-candidate QA.

Existing bookmarks remain free. Premium members can organize up to 50 saved
profiles into private categories, keep a private family discussion note and
schedule one reminder.

Guardrails:

- Notes and categories are visible only to their author, never to the saved
  member or either guardian.
- Metadata is attached to the existing bookmark and cascades away when that
  bookmark is removed.
- Notes are capped at 1,000 characters; reminder dates are bounded to one year.
- One bounded hourly worker sends each reminder once and silently consumes
  reminders that became stale during a long outage.
- Shortlist screens batch profile projection, photo lookup and URL signing;
  they do not perform one backend request per card.

### Incognito Discovery

Status: implemented behind the canonical Premium entitlement; pending final
staging migration and two-account release-candidate QA.

Incognito removes a member from general discovery and name/city search while
the setting is enabled and Premium remains active. Existing interests, matches,
permitted photo-access and guardian relationships remain accessible so the
setting cannot silently break active conversations or safety records.

Guardrails:

- Enforced by a central database authorization helper across discovery,
  search, profile projection, trust projection, photos, profile views and
  direct interest actions, including older clients.
- Compact entitlement state avoids evaluating billing providers or external
  APIs for every discovery row.
- Subscription and promotional-entitlement changes synchronize the setting;
  one bounded hourly worker covers timed expiry.
- UI and legal copy explain that Incognito limits new discovery and does not
  erase or anonymize prior interactions.
