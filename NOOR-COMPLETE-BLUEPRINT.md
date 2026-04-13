# NOOR (نور) — Global Muslim Matrimony App
## Complete Product & Technical Blueprint — Full Edition
### For: Imran | Solo Flutter Developer | Global Launch
### Version: 2.0 — April 2026

---

> NOOR means "light" in Arabic. Every decision in this blueprint serves one purpose:
> to be a dignified, trustworthy platform where Muslim families worldwide find
> the right person for the most important decision of their lives.
>
> This is not a dating app. It must never feel like one.

---

# PART 1: WHAT WE ARE BUILDING AND WHY

## The Problem We Solve

Muslim matrimony today is broken in three specific ways. First, existing apps like Shaadi and BharatMatrimony are outdated — built in 2005, designed like desktop websites, treating marriage like a database query. Second, WhatsApp groups and Facebook matrimony communities are chaotic, unsafe, and deeply undignified — people's daughters' photos shared in group chats of strangers. Third, Western dating apps like Hinge are culturally wrong — the swipe mechanic, the casual tone, the lack of family involvement all conflict with how Muslim marriages actually happen.

NOOR solves all three. Premium design that respects the gravity of the decision. A structured, safe environment. Family built into the architecture, not bolted on.

## Who We Are Building For

Our primary users are Muslim men and women aged 22 to 40 who are serious about marriage, educated, and smartphone-native. They exist in every country with a meaningful Muslim population — India, Pakistan, Bangladesh, Indonesia, Malaysia, Nigeria, Egypt, Turkey, the Gulf states, and the Muslim diaspora communities in the UK, USA, Canada, Germany, France, and Australia.

They share common frustrations: matrimony apps feel cheap and unsafe, especially for women. The process is undignified. Parents want to be involved but existing tools don't support that. Good profiles are buried under fake ones. They're willing to pay a small amount for something that actually works and feels trustworthy.

## What Makes NOOR Different

One: it is designed specifically for Muslim matrimony — not repurposed from a dating app. Islamic vocabulary, family involvement features, sect and deen fields, a tone that respects the gravity of nikah.

Two: it is premium. Every screen should look like Apple designed it for a Muslim audience. This isn't vanity — trust is the most important feature in a matrimony app, and premium design communicates trustworthiness before a single word is read.

Three: women are protected by design. Photo privacy controls, guardian mode, mandatory photo verification, anti-scam systems — these are Day One features, not afterthoughts. If women don't feel safe, the platform dies.

Four: it is global but culturally adaptive. The same codebase serves Pakistan, Saudi Arabia, Indonesia, and the UK — but the experience adapts. Gulf users see wali requirements. Some regions hide sect fields. Income brackets are in local currencies. Prices respect purchasing power.

## The North Star

"What if Apple built a Muslim matrimony app?"

Every decision — design, features, copy, timing — gets tested against this question.

---

# PART 2: BUSINESS MODEL

## Gender-Split Monetization

Women: free forever. To browse, to message, to do everything.
Men: free to browse 15 profiles per day. Must subscribe to message.

This is the most important product decision in the entire blueprint. Women are the scarce supply. Every matrimony platform suffers from male-heavy imbalance because women don't trust the environment. Making women pay adds friction to the scarce resource. Making men pay is culturally defensible — the man provides — and economically rational.

## Global Pricing by Purchasing Power

Price must represent the same economic burden regardless of country. The formula: approximately 0.7 to 1.2 percent of average monthly income per region. This makes NOOR accessible globally while maximizing revenue per market.

Tier 3 Ultra-Low covers India, Pakistan, Bangladesh, Indonesia, Nigeria, Egypt, Philippines. Monthly price: approximately $2.99 USD equivalent in local currency. Annual: $29.99 equivalent.

Tier 2 Low covers Turkey, Malaysia, Thailand, Mexico, Brazil, Vietnam. Monthly: $4.99. Annual: $44.99.

Tier 1 Standard covers USA, UK, Canada, Australia, Germany, France. Monthly: $9.99. Annual: $79.99.

Premium covers UAE, Saudi Arabia, Qatar, Kuwait, Singapore. Monthly: $6.99. Annual: $59.99. Premium Gulf pricing is lower than Western markets because the competitive landscape differs and trust building requires accessibility.

In India specifically: approximately Rs 249 per month or Rs 2,499 per year.

## Free Tier Limits

Free men can browse 15 profiles per day, send 3 interests per day, receive unlimited interests, and see who sent them an interest (name and city only, photo blurred).

Subscribed men get unlimited browsing, 20 interests per day, full messaging, see complete profiles of who liked them, advanced filters including distance and income, one profile boost per week.

Free women get 30 profiles per day browsing, 10 interests per day, unlimited messaging.

## Revenue Reality

Starting with India, Pakistan, and UK diaspora:
- 1,000 users: approximately 600 men, 150 paying at $2.99 = $449/month
- 5,000 users: approximately 3,000 men, 750 paying = $2,243/month
- 10,000 users: approximately 6,000 men, 1,500 paying = $4,485/month

Global expansion to 53,000 users across all tiers: approximately $35,000/month or $420,000/year.

Infrastructure cost stays under $75/month on Supabase Pro throughout this scale.

## Upgrade Path

Free Supabase tier holds until 800 users. Upgrade to Pro ($25/month) at 500 users. At that point, 75 paying subscribers generate Rs 18,000/month — more than enough to cover the Pro cost. One decision, not two.

---

# PART 3: GLOBAL SCOPE AND CULTURAL ADAPTATION

## Countries in Phase 1

Priority launch markets: India, Pakistan, Bangladesh, UK, USA, Canada, UAE, Saudi Arabia, Malaysia, Indonesia, Turkey, Egypt, Nigeria, Germany, France.

India is the primary market given the largest Muslim population outside Indonesia and the developer's base.

## Cultural Configuration Per Country

Each country has a configuration profile stored in the database that controls which features appear and how. Key variables:

Whether to show the sect field at all — some Gulf countries consider it divisive and prefer it hidden. Whether to display a sub-sect field. Whether guardian/wali contact is optional, encouraged, or mandatory. Whether income discussion is culturally acceptable on the profile. What pricing tier applies. What language defaults to. Whether RTL layout is needed. What the local currency is for income brackets.

Saudi Arabia and UAE require wali contact before a profile goes live. Pakistan and India treat it as strongly recommended but optional. Western markets treat it as optional with no pressure.

### Country Configuration Matrix

| Country     | Sect Visible | Sub-Sect | Wali        | Income OK | Pricing Tier | Default Lang | RTL  | Currency |
|-------------|:----------:|:--------:|:-----------:|:---------:|:------------:|:------------:|:----:|:--------:|
| India       | Yes        | Yes      | Recommended | Yes       | Tier 3       | English      | No   | INR      |
| Pakistan    | Yes        | Yes      | Recommended | Yes       | Tier 3       | Urdu         | Yes  | PKR      |
| Bangladesh  | Yes        | No       | Recommended | Yes       | Tier 3       | English      | No   | BDT      |
| UK          | Yes        | Yes      | Optional    | Yes       | Tier 1       | English      | No   | GBP      |
| USA         | Yes        | Yes      | Optional    | Yes       | Tier 1       | English      | No   | USD      |
| Canada      | Yes        | Yes      | Optional    | Yes       | Tier 1       | English      | No   | CAD      |
| UAE         | No         | No       | Mandatory   | Yes       | Premium      | Arabic       | Yes  | AED      |
| Saudi Arabia| No         | No       | Mandatory   | No        | Premium      | Arabic       | Yes  | SAR      |
| Malaysia    | Yes        | No       | Recommended | Yes       | Tier 2       | Malay        | No   | MYR      |
| Indonesia   | Yes        | No       | Recommended | Yes       | Tier 3       | Indonesian   | No   | IDR      |
| Turkey      | Yes        | No       | Optional    | Yes       | Tier 2       | Turkish      | No   | TRY      |
| Egypt       | Yes        | No       | Recommended | Yes       | Tier 3       | Arabic       | Yes  | EGP      |
| Nigeria     | Yes        | No       | Recommended | Yes       | Tier 3       | English      | No   | NGN      |
| Germany     | Yes        | Yes      | Optional    | Yes       | Tier 1       | German       | No   | EUR      |
| France      | Yes        | No       | Optional    | Yes       | Tier 1       | French       | No   | EUR      |

## Language Support

Phase 1 supports eight languages: English (default, LTR), Arabic (RTL), Urdu (RTL), French (LTR), German (LTR), Turkish (LTR), Indonesian (LTR), Malay (LTR).

RTL support must be built into the architecture from day one. It cannot be retrofitted. Every layout must use directional padding (start/end, not left/right), directional alignment, and directional icons. Arabic and Urdu users experience a fully mirrored interface — navigation arrows flip, text aligns right, layouts reverse.

### Localization File Structure

```
lib/
  l10n/
    app_en.arb          # English — source of truth
    app_ar.arb          # Arabic
    app_ur.arb          # Urdu
    app_fr.arb          # French
    app_de.arb          # German
    app_tr.arb          # Turkish
    app_id.arb          # Indonesian
    app_ms.arb          # Malay
    l10n.yaml           # Flutter gen-l10n config
```

All user-facing strings must use Flutter's `AppLocalizations`. No hardcoded strings anywhere. String keys follow the convention: `screenName_elementType_description`. Example: `onboarding_label_fullName`, `discovery_button_sendInterest`, `chat_placeholder_typeMessage`.

Plural handling uses ICU MessageFormat syntax in ARB files. Date and number formatting uses `intl` package with locale-aware formatters.

## Distance and Location

Profiles have precise coordinates (from their city selection, not GPS). The discovery feed can show distance — "8 km away" or "Same city" — using geospatial calculation. Users can filter by distance radius: same city, within 50km, within 100km, same country, anywhere.

Diaspora mode is a special toggle for users living abroad who want to match with people from their home country. An Indian Muslim in London with diaspora mode on can specifically search for profiles in India or other UK-based Indians.

### Distance Calculation

Distance is calculated using PostGIS on `geography(Point, 4326)` via `ST_Distance` (meters). Each profile stores coordinates from the selected city's coordinates. The discovery query filters by `ST_DWithin(a.location, b.location, radius_meters)` with a GiST index on geography for efficient lookups.

---

# PART 4: ARCHITECTURE OVERVIEW

## Technology Stack

| Layer              | Technology       | Plan     | Why This Choice                                      |
|--------------------|------------------|----------|------------------------------------------------------|
| Frontend           | Flutter 3.x      | Free     | Single codebase, Android + iOS, RTL built-in         |
| Auth (OTP)         | Firebase Auth     | Free*    | 10K phone verifications/month free                   |
| Database           | Supabase (PG 15)  | Free→Pro | Full Postgres, RLS, Realtime, Edge Functions, Storage|
| File Storage       | Supabase Storage  | Free→Pro | 1GB free, 100GB on Pro, CDN transforms               |
| Realtime           | Supabase Realtime | Free→Pro | WebSocket channels for chat, presence                |
| Serverless Logic   | Supabase Edge Fn  | Free     | Deno-based, runs close to DB, no cold start          |
| Subscriptions      | RevenueCat        | Free*    | <$2.5K MTR free, handles all store logic             |
| Push Notifications | OneSignal         | Free     | Unlimited pushes, timezone-aware scheduling          |
| Analytics          | PostHog           | Free*    | 1M events/month free, privacy-first                  |
| Crash Reporting    | Sentry            | Free*    | 5K events/month free                                 |
| Health Monitoring  | UptimeRobot       | Free     | 50 monitors, 5-min intervals                         |
| Admin Panel        | Custom Web (React)| Free     | Simple SPA, hosted on Supabase or Vercel free tier   |

*Free within expected Phase 1 usage.

## System Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                         FLUTTER APP                             │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────────┐   │
│  │ Auth Flow │  │Discovery │  │   Chat   │  │ Subscription │   │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘  └──────┬───────┘   │
│       │              │             │                │           │
│  ┌────┴──────────────┴─────────────┴────────────────┴───────┐  │
│  │              Supabase Client SDK (supabase_flutter)       │  │
│  └────┬──────────────┬─────────────┬────────────────┬───────┘  │
└───────┼──────────────┼─────────────┼────────────────┼──────────┘
        │              │             │                │
   ┌────▼────┐   ┌─────▼────┐  ┌────▼─────┐   ┌─────▼──────┐
   │Supabase │   │Supabase  │  │Supabase  │   │ Supabase   │
   │  Auth   │   │ PostgREST│  │ Realtime │   │Edge Function│
   │(+Firebase│  │ (REST API│  │(WebSocket│   │  (Deno)    │
   │  OTP)   │   │  to DB)  │  │ Channels)│   │            │
   └────┬────┘   └─────┬────┘  └────┬─────┘   └─────┬──────┘
        │              │             │                │
   ┌────▼──────────────▼─────────────▼────────────────▼──────┐
   │                   PostgreSQL 15 Database                 │
   │  ┌─────────┐  ┌─────────┐  ┌──────────┐  ┌──────────┐  │
   │  │  Users  │  │Profiles │  │ Messages │  │ Interests│  │
   │  │  Table  │  │  Table  │  │  Table   │  │  Table   │  │
   │  └─────────┘  └─────────┘  └──────────┘  └──────────┘  │
   │  ┌─────────────────────────────────────────────────┐    │
   │  │          Row Level Security (RLS)               │    │
   │  │     + PostGIS + pg_cron + pgcrypto              │    │
   │  └─────────────────────────────────────────────────┘    │
   └─────────────────────────────────────────────────────────┘

External Services:
  ┌────────────┐  ┌────────────┐  ┌──────────┐  ┌───────────┐
  │ RevenueCat │  │  OneSignal  │  │ PostHog  │  │  Sentry   │
  │(Subs/IAP)  │  │   (Push)   │  │(Analytics│  │ (Crashes) │
  └──────┬─────┘  └──────┬─────┘  └────┬─────┘  └─────┬─────┘
         │               │              │               │
    Webhook to       SDK from        SDK from       SDK from
    Edge Function    Flutter App     Flutter App    Flutter App
```

## Authentication Flow — Detailed

```
┌──────────┐    ┌──────────────┐    ┌─────────────┐    ┌──────────┐
│  User    │    │ Firebase Auth│    │  Supabase   │    │ Supabase │
│ (Flutter)│    │   (OTP)      │    │Edge Function│    │   Auth   │
└────┬─────┘    └──────┬───────┘    └──────┬──────┘    └────┬─────┘
     │                 │                   │                │
     │ 1. Enter phone  │                   │                │
     ├────────────────►│                   │                │
     │                 │                   │                │
     │ 2. SMS OTP sent │                   │                │
     │◄────────────────┤                   │                │
     │                 │                   │                │
     │ 3. Enter OTP    │                   │                │
     ├────────────────►│                   │                │
     │                 │                   │                │
     │ 4. Firebase     │                   │                │
     │    ID Token     │                   │                │
     │◄────────────────┤                   │                │
     │                 │                   │                │
     │ 5. Send Firebase ID Token           │                │
     ├─────────────────────────────────────►│                │
     │                 │                   │                │
     │                 │    7. Verify token │                │
     │                 │    with Firebase   │                │
     │                 │◄──────────────────┤                │
     │                 │    8. Token valid  │                │
     │                 │──────────────────►│                │
     │                 │                   │                │
     │                 │                   │ 8. Create/find │
     │                 │                   │    user, issue │
     │                 │                   │    Supabase JWT│
     │                 │                   ├───────────────►│
     │                 │                   │                │
     │                 │                   │ 9. Supabase    │
     │                 │                   │    session     │
     │                 │                   │◄───────────────┤
     │                 │                   │                │
     │ 10. Return Supabase access_token    │                │
     │     + refresh_token                 │                │
     │◄────────────────────────────────────┤                │
     │                 │                   │                │
     │ 11. All subsequent API calls use Supabase JWT        │
     ├──────────────────────────────────────────────────────►│
```

### Edge Function: `firebase-auth-exchange`

This Edge Function is the bridge between Firebase Auth and Supabase Auth. It:

1. Receives the Firebase ID token from the Flutter app.
2. Verifies the token against Firebase's public keys (fetched and cached).
3. Extracts the phone number from the verified token claims.
4. Checks if a Supabase user with that phone number exists.
5. Verifies if the incoming Login Request uses an unrecognized Device ID. If the hardware is new and the user account is older than 30 days, the Session is abruptly paused pending secondary verification (Date of Birth or custom PIN). This acts as a circuit-breaker against telecommunications recycling numbers leading to Account Takeovers.
6. If the account does not exist, creates a new Supabase user with the phone as the identifier.
6. Utilizes `supabase.auth.admin.generateLink` to create a magic link or native session, avoiding manual JWT signatures.
7. Returns the generated Supabase session to the client natively.
8. The Flutter app stores these tokens securely and uses them for all subsequent API calls.

**Security**: The Firebase project ID is verified in the token claims. Tokens from other Firebase projects are rejected. Using native Supabase auth admin methods avoids generating raw JWTs manually, closing token refresh and rotation vulnerabilities.

## Data Regions

Phase 1: single region, Mumbai (ap-south-1). Lowest latency for India, Pakistan, Gulf. Adequate for global use.

Phase 2 expansion triggers: add London (eu-west-2) when EU/UK users exceed 10,000. Add Virginia (us-east-1) when North America users exceed 10,000. Add Singapore (ap-southeast-1) when Southeast Asia exceeds 10,000.

---

# PART 5: USER ROLES

## Profile Owner

The person seeking marriage. Creates their own profile, controls their own search. Can pause their profile (hide from search while keeping data). Can set photo privacy. Controls their own guardian settings.

### Permissions Matrix

| Action                    | Profile Owner | Guardian (Phase 2) | Admin   |
|---------------------------|:------------:|:-------------------:|:-------:|
| Create profile            | ✅           | ✅                  | ❌      |
| Edit own profile          | ✅           | ✅ (restricted)     | ✅      |
| View discovery feed       | ✅           | ✅                  | ❌      |
| Send interest             | ✅           | ✅                  | ❌      |
| Accept/decline interest   | ✅           | ✅                  | ❌      |
| Send messages             | ✅           | ✅                  | ❌      |
| View messages             | ✅           | ✅ (copy)           | ✅      |
| Change photo privacy      | ✅           | ❌                  | ✅      |
| Pause profile             | ✅           | ❌                  | ✅      |
| Delete account            | ✅           | ❌                  | ✅      |
| Approve/reject photos     | ❌           | ❌                  | ✅      |
| Suspend accounts          | ❌           | ❌                  | ✅      |
| View reports              | ❌           | ❌                  | ✅      |
| Send broadcast            | ❌           | ❌                  | ✅      |
| Access admin panel        | ❌           | ❌                  | ✅      |

## Guardian / Wali

A parent or guardian who manages a profile on behalf of their child. In Gulf markets this is sometimes mandatory. In South Asian markets it is common and encouraged.

The guardian has their own login. They receive copies of all incoming interests and messages. They can respond on behalf of the candidate. They can restrict what the candidate can edit on the profile.

The candidate also has their own login but with limited edit access when guardian mode is active.

This is a Day One data model. The full guardian UI ships in Phase 2.

### Guardian Data Model (Day One)

The `profiles` table includes:
- `guardian_phone` — encrypted phone number of the guardian
- `guardian_name` — guardian's display name
- `guardian_relationship` — enum: father, mother, brother, sister, uncle, aunt, other
- `guardian_mode` — enum: none, passive (receives copies), active (can respond)
- `guardian_user_id` — nullable FK to users table (linked when guardian creates their own account in Phase 2)

## Administrator

Internal moderation role. Separate login via email and password (not phone). Cannot be accessed from the mobile app — only from the admin web panel. Bypasses all data access restrictions. Reviews profile photos, handles reports, manages suspended accounts.

### Admin Roles (Extensible)

| Role          | Photo Review | Report Review | User Suspend | Broadcast | Analytics | Super Admin |
|---------------|:----------:|:------------:|:-----------:|:---------:|:---------:|:-----------:|
| moderator     | ✅         | ✅           | ❌          | ❌        | ❌        | ❌          |
| admin         | ✅         | ✅           | ✅          | ✅        | ✅        | ❌          |
| super_admin   | ✅         | ✅           | ✅          | ✅        | ✅        | ✅          |

Admin actions are logged in an `admin_audit_log` table with: admin_id, action_type, target_user_id, details (JSONB), timestamp.

---

# PART 6: COMPLETE ONBOARDING FLOW

## Design Principles

Progress bar visible at every step. Back button always available. Data saved at each step — if the user closes the app and returns, they resume where they left off. Optional fields are clearly marked. The flow adapts based on the user's country — fields appear, are hidden, or change based on cultural configuration.

### Technical Implementation

Onboarding state is managed via a `profiles.onboarding_step` integer column (0–14). Each step writes partial data to the `profiles` table. The Flutter app checks this value on launch — if < 14, the user is routed to onboarding at the correct step. A `ProfileOnboardingCubit` manages the local state and syncs to Supabase on each "Next" tap.

```
OnboardingFlow (PageView with NeverScrollableScrollPhysics)
  ├── SplashBrandScreen        (step 0)
  ├── LegalGateScreen          (step 1)
  ├── PhoneVerificationScreen  (step 2 — handled by AuthCubit)
  ├── ProfileForWhomScreen     (step 3)
  ├── BasicIdentityScreen      (step 4)
  ├── IslamicIdentityScreen    (step 5 — culturally adaptive)
  ├── BackgroundScreen         (step 6)
  ├── IncomeScreen             (step 7 — region-aware)
  ├── FamilyScreen             (step 8)
  ├── AboutYourselfScreen      (step 9)
  ├── PartnerPreferencesScreen (step 10)
  ├── PhotoUploadScreen        (step 11)
  ├── ProfilePreviewScreen     (step 12)
  └── PendingReviewScreen      (step 13 → step 14 on admin approval)
```

## Screen 1: Splash and Brand

The NOOR Arabic letterform (نور) appears with a light-emanating animation. The English wordmark "NOOR" fades in below. The tagline "Begin with bismillah" appears. Two buttons: Create Profile (gold, primary) and Sign In (outlined, secondary). Total splash duration approximately 2.5 seconds before buttons appear.

### Animation Specification

```
Timeline:
  0ms    — Screen appears, dark background (#0A0A0F)
  0ms    — Arabic letterform نور at 0% opacity, scale 0.8
  300ms  — نور fades to 100% opacity, scales to 1.0 (ease-out-cubic, 600ms)
  600ms  — Light rays emanate from letterform center (6 rays, 45° apart)
           Each ray: 0→80% opacity, 0→120px length, staggered 50ms apart
  900ms  — Light rays fade to 0% opacity over 400ms
  1000ms — "NOOR" wordmark fades in below (0→100% opacity, 400ms)
  1400ms — Tagline "Begin with bismillah" fades in (0→100% opacity, 300ms)
  2000ms — Buttons slide up from bottom (translateY 40→0, 400ms, ease-out)
  2500ms — Everything settled, interactive
```

## Screen 2: Legal Gate

Terms of Service summary in plain language with a language toggle. Privacy Policy link. Two mandatory checkboxes: age confirmation (18 or older) and terms agreement. Cannot proceed without both checked. Consent is logged with timestamp.

### Consent Logging

A `user_consents` table stores:
- `user_id` (FK to users)
- `consent_type` — enum: terms_of_service, privacy_policy, age_verification
- `version` — string, e.g. "1.0.0" (allows re-consent when ToS changes)
- `granted_at` — timestamp
- `ip_address` — text (for legal compliance)
- `app_version` — text

## Screen 3: Phone Verification

Country code auto-detected from SIM card. User enters phone number. OTP sent via Firebase. Six-digit input with auto-advance between digits. Resend available after 60 seconds. After successful verification, the backend creates a Supabase account and returns a session. The entire exchange happens invisibly to the user — they just see "verifying..." then proceed.

### Phone Input Validation Rules

- Strip all non-digit characters except leading +
- Validate length per country code (India: 10 digits, UK: 10-11, US: 10, etc.)
- Rate limit: max 3 OTP requests per phone number per hour
- **Security**: Must implement Firebase App Check (Play Integrity API / reCAPTCHA Enterprise) to prevent bot-net OTP exhaustion.
- Firebase `verifyPhoneNumber` with `autoRetrievedSmsCodeForTesting` in debug builds
- Use `SmsAutoFill` for Android automatic OTP detection
- Haptic feedback on each digit entry

## Screen 4: Profile For Whom

Two options: "Myself — I am looking for a spouse" or "My son or daughter — I am a parent or guardian." In countries where wali is mandatory (Saudi, UAE), if the user selects "Myself," they are still required to provide a guardian contact before the profile goes live.

## Screen 5: Basic Identity

Full name (first and last). Date of birth with a date picker — anyone under 18 is blocked with a kind message. Gender: Male or Female only (matrimony context). City selection from a searchable dropdown populated from the cities database, filtered by country. Country auto-fills from city selection but can be changed.

### City Search Implementation

The city dropdown uses a `TextField` with debounced (300ms) search. The query hits a Supabase RPC function:

```sql
CREATE OR REPLACE FUNCTION search_cities(search_term text, country_filter text DEFAULT NULL)
RETURNS TABLE(id uuid, name text, name_local text, country_code text, lat double precision, lng double precision)
AS $$
BEGIN
  RETURN QUERY
  SELECT c.id, c.name, c.name_local, c.country_code, c.latitude, c.longitude
  FROM cities c
  WHERE c.search_vector @@ to_tsquery('simple', trim(search_term) || ':*')
    AND (country_filter IS NULL OR c.country_code = country_filter)
  ORDER BY ts_rank(c.search_vector, to_tsquery('simple', trim(search_term) || ':*')) DESC
  LIMIT 20;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;
```

## Screen 6: Islamic Identity (Culturally Adaptive)

This screen adapts based on the user's country. In markets where sect display is enabled: Sunni, Shia, Prefer not to say, or Other. If Sunni is selected, an optional sub-sect field appears: Hanafi, Shafi'i, Maliki, Hanbali, Salafi, Ahle Hadith, Deobandi, Barelvi, Other. In markets where sect is configured as hidden, this entire section is skipped.

Universal fields: deen level (Practicing, Moderate, Cultural Muslim — each with a tooltip explaining what it means in plain language). Whether they pray five times daily. For women: hijab (Always, Sometimes, No, Prefer not to say). For men: beard (Yes, No, Prefer not to say).

### Adaptive Logic

```dart
// In IslamicIdentityScreen.build()
final countryConfig = context.read<CountryConfigCubit>().state;

if (countryConfig.showSect) {
  // Show sect selector
  if (selectedSect == Sect.sunni && countryConfig.showSubSect) {
    // Show sub-sect selector
  }
}
// Universal fields always shown
// deen_level, prays_five_daily
// Gender-conditional: hijab (women), beard (men)
```

## Screen 7: Background and Education

Education level, adapted to local systems. Field of study (optional). Profession with auto-suggest. Employment status: employed, self-employed, student, or not working. An education rank is assigned internally (1 through 7) even though the displayed label is flexible text — this enables "minimum education" filtering later.

### Education Rank Mapping

| Rank | Label (English)         | Label (Urdu)            | Label (Arabic)        |
|:----:|-------------------------|-------------------------|-----------------------|
| 1    | Below Secondary         | ثانوی سے کم             | أقل من الثانوية       |
| 2    | Secondary / O-Level     | میٹرک / او لیول         | ثانوية                |
| 3    | Higher Secondary / A-Level | انٹرمیڈیٹ / اے لیول  | ثانوية عليا           |
| 4    | Diploma / Associate     | ڈپلوما                  | دبلوم                 |
| 5    | Bachelor's Degree       | بیچلرز ڈگری             | بكالوريوس             |
| 6    | Master's Degree         | ماسٹرز ڈگری             | ماجستير               |
| 7    | Doctorate / PhD         | ڈاکٹریٹ / پی ایچ ڈی   | دكتوراه               |

## Screen 8: Income (Region-Aware)

Income brackets loaded dynamically from the database for the user's country. Pakistan shows PKR brackets. USA shows USD brackets. Saudi shows SAR brackets. Marking income is optional. Visibility can be set to: hidden entirely, show bracket only to all, or show exact amount only after mutual interest. In cultures where income discussion is taboo, this screen is presented very softly with an easy skip.

### Income Bracket Examples

| Tier | Country  | Bracket 1       | Bracket 2       | Bracket 3       | Bracket 4       | Bracket 5         |
|------|----------|:---------------:|:---------------:|:---------------:|:---------------:|:-----------------:|
| 1    | India    | < ₹3 Lakh/yr    | ₹3–6 Lakh       | ₹6–12 Lakh      | ₹12–25 Lakh     | > ₹25 Lakh        |
| 2    | Pakistan | < PKR 50K/mo    | PKR 50–100K      | PKR 100–200K     | PKR 200–500K     | > PKR 500K         |
| 3    | USA      | < $30K/yr       | $30–60K          | $60–100K         | $100–200K        | > $200K            |
| 4    | UAE      | < AED 8K/mo     | AED 8–15K        | AED 15–30K       | AED 30–60K       | > AED 60K          |
| 5    | UK       | < £20K/yr       | £20–35K          | £35–60K          | £60–100K         | > £100K            |

## Screen 9: Family Background

Family type: nuclear, joint, or extended. Sibling count. Eldest child yes or no. Parents' marital status: together, separated, divorced, father deceased, mother deceased, both deceased. Family's city or region of origin. Previously married: no, divorced, or widowed. If previously married, whether they have children and how many.

## Screen 10: About Yourself

Bio with a 300-character limit and a live counter. Placeholder text reads "Describe yourself with honesty and dignity." The bio field actively filters phone numbers, social media handles, and external links — these are rejected on submission with a clear message explaining why. Interests as multi-select chips, maximum 6. Languages spoken as multi-select.

### Content Filter Regex

```dart
class ContentFilter {
  static final _phoneRegex = RegExp(r'(\+?\d[\d\s\-]{7,}\d)');
  static final _emailRegex = RegExp(r'[\w.+-]+@[\w-]+\.[\w.]+');
  static final _urlRegex = RegExp(r'(https?://|www\.)\S+');
  static final _socialRegex = RegExp(
    r'(@[\w.]+|(?:instagram|insta|snap|snapchat|whatsapp|telegram|'
    r'facebook|fb|twitter|tiktok|linkedin)[\s.:/@]*[\w.]+)',
    caseSensitive: false,
  );

  static FilterResult check(String text) {
    if (_phoneRegex.hasMatch(text)) return FilterResult.phoneDetected;
    if (_emailRegex.hasMatch(text)) return FilterResult.emailDetected;
    if (_urlRegex.hasMatch(text)) return FilterResult.urlDetected;
    if (_socialRegex.hasMatch(text)) return FilterResult.socialDetected;
    return FilterResult.clean;
  }
}
```

### Predefined Interest Tags

Organized by category for the chip selector:

- **Faith**: Quran recitation, Islamic lectures, Dawah, Voluntary fasting, Tahajjud, Umrah/Hajj
- **Lifestyle**: Cooking, Travel, Fitness, Gardening, Volunteering, Photography
- **Learning**: Reading, Technology, Science, History, Languages, Writing
- **Creative**: Calligraphy, Art, Poetry, Graphic design, Crafts
- **Sports**: Cricket, Football, Swimming, Hiking, Martial arts, Cycling
- **Social**: Community work, Teaching, Mentoring, Family gatherings

## Screen 11: Partner Preferences

Age range with a dual slider (default: own age ±5 years, min: 18, max: 60). Location preference: same city, same country, open to abroad, or diaspora mode. Sect preference (same as mine, any, or specific). Deen level preference. Minimum education preference (uses education rank). Openness to previously married partners, widowed partners, and partners with children.

## Screen 12: Photo Upload (Automated Gate)

Minimum one photo required. Maximum four.

Local AI Scan: Before upload, the app uses google_mlkit_face_detection (On-Device/Free). If no face is detected or multiple faces are found, the upload is blocked with a clear error.

Proof of Life: One slot is reserved for a "Verification Selfie." This slot disables the gallery and forces the user to use the live camera.

Processing: Photos are compressed and stripped of metadata on-device before upload.

Privacy: Women set photos to public or mutual-only.

### Photo Processing Pipeline (On-Device)

```
User selects image from gallery/camera
  │
  ├── 1. Face Detection (google_mlkit_face_detection)
  │     └── If no face detected → Show error: "Please use a photo where your face is clearly visible"
  │     └── If multiple faces → Warn: "Group photos cannot be your primary photo"
  │
  ├── 2. Resize (flutter_image_compress)
  │     └── Max width: 800px
  │     └── Max height: 1000px
  │     └── Maintain aspect ratio
  │
  ├── 3. Compress
  │     └── Format: WebP
  │     └── Quality: 82%
  │     └── Target: < 250KB
  │     └── keepExif: false (CRITICAL: Explicitly ensure geographic metadata stripping)
  │     └── If still > 250KB after 82%, reduce quality to 70%
  │
  ├── 4. Upload to Supabase Storage
  │     └── Bucket: profile-photos
  │     └── Path: {user_id}/{uuid}.webp
  │     └── Content-Type: image/webp
  │
  └── 5. Insert row in photos table
        └── profile_id, storage_path, order_index
        └── admin_approved: false
        └── nsfw_cleared: false (set by async scan)
```

## Screen 13: Profile Preview

An exact rendering of how other users will see this profile. Every section visible. An "Edit" button navigates back to any specific section. A "Submit Profile" button sends it for review.

## Screen 14: Welcome to NOOR

Since the profile is auto-verified by AI, there is no waiting period to be "Live."

Messaging Message: A soft notification informs the user: "Your profile is now live! To keep the community safe, new members have a 48-hour probation period before they can send chat messages. You can browse and send Interests immediately."

---

# PART 7: PROFILE ANATOMY

## What Every User Sees

First name and last name initial only (never full last name until mutual interest). Age calculated from date of birth — never the actual birthdate. City and country. Sect and deen level. General education level and profession — not employer name. Height. Bio. Interests. Languages. Primary photo (or a dignified placeholder if photos are set to private). Photo count indicator.

## What Unlocks After Mutual Interest

Full last name. Additional locked photos. Income bracket. Full family background details. Previously married and children information. Family origin city.

## What Is Never Shown Publicly

Phone number. Exact date of birth. Guardian contact details. Government ID. Precise coordinates.

## Completeness Score

An internal score from 0 to 100 shown only to the profile owner. It influences feed ranking — more complete profiles rank higher.

### Score Calculation (Database Function)

```sql
CREATE OR REPLACE FUNCTION trigger_update_completeness()
RETURNS trigger AS $$
DECLARE
  score integer := 0;
  photo_count integer;
  bio_length integer;
BEGIN
  -- Primary photo approved: 25 points
  SELECT COUNT(*) INTO photo_count
  FROM photos
  WHERE profile_id = NEW.id
    AND admin_approved = true
    AND nsfw_cleared = true
    AND order_index = 0;
  IF photo_count > 0 THEN score := score + 25; END IF;

  -- Bio with min 50 characters: 15 points
  SELECT LENGTH(bio) INTO bio_length
  FROM profiles WHERE id = NEW.id;
  IF bio_length >= 50 THEN score := score + 15; END IF;

  -- Islamic fields complete: 15 points
  IF EXISTS (
    SELECT 1 FROM profiles
    WHERE id = NEW.id
      AND deen_level IS NOT NULL
      AND prays_five_daily IS NOT NULL
  ) THEN score := score + 15; END IF;

  -- Education and profession: 10 points
  IF EXISTS (
    SELECT 1 FROM profiles
    WHERE id = NEW.id
      AND education_level IS NOT NULL
      AND profession IS NOT NULL
  ) THEN score := score + 10; END IF;

  -- Family background: 10 points
  IF EXISTS (
    SELECT 1 FROM profiles
    WHERE id = NEW.id
      AND family_type IS NOT NULL
      AND parents_status IS NOT NULL
  ) THEN score := score + 10; END IF;

  -- Partner preferences set: 10 points
  IF EXISTS (
    SELECT 1 FROM profile_preferences
    WHERE profile_id = NEW.id
      AND preferred_age_min IS NOT NULL
  ) THEN score := score + 10; END IF;

  -- Second photo: 8 points
  SELECT COUNT(*) INTO photo_count
  FROM photos
  WHERE profile_id = NEW.id
    AND admin_approved = true
    AND nsfw_cleared = true;
  IF photo_count >= 2 THEN score := score + 8; END IF;

  -- Income range provided: 4 points
  IF EXISTS (
    SELECT 1 FROM profiles
    WHERE id = NEW.id AND income_bracket IS NOT NULL
  ) THEN score := score + 4; END IF;

  -- Languages listed: 3 points
  IF EXISTS (
    SELECT 1 FROM profiles
    WHERE id = NEW.id AND languages IS NOT NULL AND array_length(languages, 1) > 0
  ) THEN score := score + 3; END IF;

  NEW.completeness_score := score;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE TRIGGER update_profile_score
  BEFORE UPDATE ON profiles
  FOR EACH ROW 
  WHEN (OLD.* IS DISTINCT FROM NEW.*)
  EXECUTE FUNCTION trigger_update_completeness();
```

The nudge shown to the user: "Profiles with 80 percent or higher completeness receive three times more interests."

---

# PART 8: CORE SCREENS

## Discovery Feed

Vertical scroll feed of editorial profile cards. Not a swipe interface. Not a grid. One card at a time, scrolling down like an editorial magazine.

Each card is portrait orientation (3:4 ratio), full-bleed with a multi-stop gradient overlay from transparent at the top to near-opaque at the bottom. Name in the display serif font, age and city below. Two chips showing sect and deen level. A "Send Interest" button and a bookmark icon.

If a woman has set photos to private, the card shows a dignified silhouette placeholder with a gold ring border and the text "4 photos · visible after acceptance."

Verified users have a small teal badge in the top corner of their photo.

The header shows the NOOR wordmark on the left and a notification bell with a badge on the right. Below the header, a horizontal scrollable row of filter chips: All, Near Me, Sect, Deen, Age.

Free users see a counter: "12 profiles remaining today."

Every 10th profile in the feed is slightly outside the user's stated preferences, labeled subtly: "Someone you might connect with." This prevents rigid filter bubbles and helps during the cold-start period when supply is thin.

### Feed Pagination Implementation

```dart
// Cursor-based pagination — no offset drift, no duplicates
class DiscoveryFeedCubit extends Cubit<DiscoveryFeedState> {
  Future<void> loadNextPage() async {
    final response = await _supabase.rpc('get_discovery_feed', params: {
      'p_viewer_id': _userId,
      'p_cursor_score': state.lastScore,
      'p_cursor_id': state.lastId,
      'p_page_size': 10,
      'p_filters': state.activeFilters.toJson(),
    });
    // Append to existing profiles, update cursor
  }
}
```

```sql
-- Discovery Pool Materialized View (Performance Scalability Fix)
-- Pre-joins standard geographic and profile data to prevent real-time 'Feed Crash' 
-- from monolithic queries with thousands of concurrent users.
CREATE MATERIALIZED VIEW discovery_pool AS
SELECT 
  p.id AS profile_id,
  p.user_id,
  p.gender,
  p.visibility,
  p.onboarding_step,
  p.first_name,
  LEFT(p.last_name, 1) AS last_name_initial,
  EXTRACT(YEAR FROM age(p.date_of_birth))::integer AS age,
  c.name AS city_name,
  p.country_code,
  c.id AS city_id,
  p.sect::text,
  p.deen_level::text,
  p.profession,
  p.bio,
  p.static_rank_score AS rank_score,
  p.last_active_at,
  p.location,
  ST_Y(p.location::geometry) AS lat,
  ST_X(p.location::geometry) AS lng,
  p.photo_privacy::text,
  p.is_verified,
  p.education_rank,
  p.date_of_birth,
  p.approved_at,
  p.is_boosted,
  p.boost_expires_at,
  (SELECT COUNT(*)::integer FROM photos ph WHERE ph.profile_id = p.id AND ph.admin_approved AND ph.nsfw_cleared) AS photo_count,
  (SELECT CASE WHEN p.photo_privacy = 'public' THEN ph.storage_path ELSE NULL END FROM photos ph WHERE ph.profile_id = p.id AND ph.order_index = 0 AND ph.admin_approved AND ph.nsfw_cleared LIMIT 1) AS photo_url,
  pr.diaspora_mode,
  pr.open_to_diaspora,
  pr.preferred_countries,
  pr.preferred_age_min,
  pr.preferred_age_max,
  pr.min_education_rank,
  pr.deen_preference
FROM profiles p
JOIN cities c ON p.city_id = c.id
JOIN profile_preferences pr ON p.id = pr.profile_id
WHERE p.visibility = 'visible' AND p.onboarding_step >= 14;

CREATE UNIQUE INDEX idx_discovery_pool_id ON discovery_pool(profile_id);
CREATE INDEX idx_discovery_pool_location ON discovery_pool USING GIST (location);
CREATE INDEX idx_discovery_pool_rank ON discovery_pool(rank_score DESC, profile_id DESC);

-- Refresh materialized view daily
SELECT cron.schedule('refresh_discovery_pool_daily', '30 2 * * *', $$REFRESH MATERIALIZED VIEW CONCURRENTLY discovery_pool;$$);

-- Discovery feed RPC with cursor pagination querying the Discovery Pool
CREATE OR REPLACE FUNCTION get_discovery_feed(
  p_viewer_id uuid,
  p_cursor_score double precision DEFAULT NULL,
  p_cursor_id uuid DEFAULT NULL,
  p_page_size integer DEFAULT 10,
  p_filters jsonb DEFAULT '{}'::jsonb
)
RETURNS TABLE(
  profile_id uuid,
  first_name text,
  last_name_initial text,
  age integer,
  city_name text,
  country_code text,
  sect text,
  deen_level text,
  profession text,
  bio text,
  photo_url text,
  photo_count integer,
  photo_privacy text,
  is_verified boolean,
  distance_km double precision,
  rank_score double precision
) AS $$
DECLARE
  user_sub_status text;
  viewer_profile profiles%ROWTYPE;
  viewer_prefs profile_preferences%ROWTYPE;
  max_km int := LEAST(COALESCE((p_filters->>'max_distance_km')::int, 20000), 20000);
  active_recently boolean := COALESCE((p_filters->>'active_recently')::boolean, FALSE);
BEGIN
  SELECT subscription_status INTO user_sub_status FROM users WHERE id = p_viewer_id;

  IF user_sub_status != 'active' AND p_page_size > 15 THEN
      RAISE EXCEPTION 'Page size limits strictly exceeded for underlying free tier requests';
  END IF;

  SELECT * INTO viewer_profile FROM profiles WHERE user_id = p_viewer_id;
  SELECT * INTO viewer_prefs FROM profile_preferences WHERE profile_id = viewer_profile.id;

  IF viewer_profile.visibility = 'suspended' THEN
      RAISE EXCEPTION 'Account is suspended. Action forbidden.';
  END IF;

  RETURN QUERY
  SELECT
    dp.profile_id,
    dp.first_name,
    dp.last_name_initial,
    dp.age,
    dp.city_name,
    dp.country_code,
    dp.sect,
    dp.deen_level,
    dp.profession,
    dp.bio,
    dp.photo_url,
    dp.photo_count,
    dp.photo_privacy,
    dp.is_verified,
    dp.lat,
    dp.lng,
    dp.rank_score
  FROM discovery_pool dp
  WHERE dp.user_id != p_viewer_id
    AND dp.gender != viewer_profile.gender
    AND NOT EXISTS (SELECT 1 FROM blocks b
      WHERE (b.blocker_id = p_viewer_id AND b.blocked_id = dp.user_id)
         OR (b.blocker_id = dp.user_id AND b.blocked_id = p_viewer_id))
    AND (
      (viewer_prefs.diaspora_mode = TRUE 
       AND (viewer_prefs.preferred_countries IS NULL OR dp.country_code = ANY(viewer_prefs.preferred_countries))
       AND dp.open_to_diaspora = TRUE)
      OR (viewer_prefs.diaspora_mode = FALSE AND (max_km IS NULL OR (viewer_profile.location IS NOT NULL AND dp.location IS NOT NULL AND ST_DWithin(dp.location, viewer_profile.location, max_km * 1000))))
    )
    AND (
      NOT active_recently OR (dp.last_active_at > NOW() - INTERVAL '7 days')
    )
    AND (
      p_cursor_score IS NULL
      OR (dp.rank_score < p_cursor_score)
      OR (dp.rank_score = p_cursor_score AND dp.profile_id < p_cursor_id)
    )
  ORDER BY dp.rank_score DESC, dp.profile_id DESC
  LIMIT p_page_size;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;
```

## Profile Detail

Opening with a full-screen hero photo taking up about 55 percent of the screen. As the user scrolls down, the content slides over the photo with a subtle parallax effect — the photo moves slower than the text, creating depth.

Multiple photos swipe horizontally with dot indicators. Tapping a photo opens a full-screen viewer.

Back button top left. Share button top right. Three-dot menu for report and block.

Content sections below the photo, each with a small uppercase label in wide letter-spacing: About, Interests, Islamic Life, Education and Career, Family, Looking For.

The bio is displayed in italic display font — these are the person's own words and deserve the human, calligraphic treatment.

Interests appear as outlined gold chips. Information fields appear in two-column cards with the field name in small muted text above the value.

A compatibility indicator shows how many of the profile owner's stated preferences match the viewer's profile — "You match 4 of their 5 preferences."

A sticky bottom bar is always visible during scrolling: a bookmark button on the left, a gold "Send Interest" button filling the rest.

### Parallax Implementation

```dart
class ProfileDetailScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: MediaQuery.of(context).size.height * 0.55,
          pinned: true,
          stretch: true,
          flexibleSpace: FlexibleSpaceBar(
            stretchModes: const [StretchMode.zoomBackground],
            background: PhotoCarousel(photos: profile.photos),
          ),
        ),
        SliverToBoxAdapter(
          child: ProfileContentSections(profile: profile),
        ),
      ],
    );
  }
}
```

## Interest Send Ceremony

When a user taps "Send Interest," something special happens. This is not a toast notification. This is a moment of intention — expressing interest in a potential spouse deserves ceremony.

A gold ring expands outward and fades. Six gold particles radiate from the center. A checkmark draws itself. The text "Interest Sent — May Allah bless this with goodness" fades in. The whole sequence takes less than two seconds.

### Ceremony Animation Specification

```
Timeline:
  0ms    — User taps "Send Interest" button
  0ms    — Full-screen semi-transparent overlay appears
  0ms    — Gold ring (stroke-width: 2px) at center, radius 0
  0-400ms — Ring expands to radius 60px (ease-out-cubic)
  200ms  — Ring begins fading (opacity 1→0 over 300ms)
  200ms  — 6 gold particles spawn at center
  200-600ms — Particles move outward 80px each at 60° intervals
             Each particle: 4px circle, opacity 1→0
  400ms  — Checkmark SVG begins drawing (stroke animation)
  400-700ms — Checkmark completes drawing (ease-in-out)
  700ms  — Text fades in below checkmark (0→100% opacity, 300ms)
  1800ms — Entire overlay fades out (300ms)
  2100ms — Return to previous state, button shows "Interest Sent ✓"
```

## Interests Screen

Two tabs: Received and Sent.

Received shows each incoming interest as a card with the sender's avatar, name, age, city, and when it was sent. Two action buttons: Accept (gold) and Decline (outlined). When accepted, the chat unlocks and a mutual interest is created. Pending interests automatically expire after 14 days.

Sent shows each outgoing interest with its status: Pending, Accepted, Declined, or Expired. The user can withdraw a pending interest silently.

### Interest Lifecycle State Machine

```
               ┌─────────┐
     send      │         │  14 days
  ───────────► │ PENDING ├─────────────► EXPIRED
               │         │
               └────┬────┘
                    │
              ┌─────┴──────┐
              │             │
         accept          decline
              │             │
              ▼             ▼
         ┌────────┐   ┌──────────┐
         │ACCEPTED│   │ DECLINED │
         └───┬────┘   └──────────┘
             │
             ▼
      ┌────────────┐
      │MATCH CREATED│ → Chat unlocked
      └────────────┘

  At any point while PENDING:
    sender can WITHDRAW → status = withdrawn (silent)
```

## Conversations

A list of all active conversations, sorted by most recent message. Conversations with unread messages have a gold left border and the sender's name appears in heavier weight. An unread count badge in gold shows the number.

Inside a conversation, sent messages appear in a subtle gold-tinted bubble on the right. Received messages appear in the surface color on the left. Both have slightly reduced radius on one corner — the one closest to the sender — giving a natural felt sense of direction without using literal message tails.

Timestamps are hidden by default and appear when a message is tapped.

Before the first message is sent, three suggested openers appear as horizontally scrollable cards in italic display font. Tapping one pre-fills the input. The user can edit before sending. These openers use Islamic greeting conventions.

### Suggested Conversation Openers

```
Category: Greeting
  "Assalamu Alaikum! I came across your profile and was genuinely impressed. May I introduce myself?"
  "Bismillah. Your profile caught my attention — especially [interest]. I would love to learn more about you."
  "Assalamu Alaikum. I believe we share similar values. Would you be open to getting to know each other?"

Category: Interest-Based (dynamically generated)
  "Assalamu Alaikum! I noticed you enjoy {shared_interest}. What draws you to it?"
  "Salam! A fellow {shared_interest} enthusiast — I'd love to hear your perspective on it."

Category: Deen-Based
  "Assalamu Alaikum! Your dedication to deen resonated with me. May Allah bless this conversation with goodness."
```

Messaging is text-only in Phase 1. No photos, no voice messages, no links.

Non-subscriber men who try to open a chat see: "Subscribe to unlock messaging. Women always message free on NOOR." The price shown is in their local currency.

### Real-Time Chat Architecture

```
Flutter App                          Supabase
    │                                   │
    │ 1. Subscribe to Broadcast channel │
    │    channel: 'match:{match_id}'    │
    ├──────────────────────────────────►│
    │                                   │
    │ 2. Send message via Broadcast     │
    │    (low latency, client-to-client)│
    ├──────────────────────────────────►│
    │               │                   │
    │               ▼                   │
    │  3. Async REST INSERT (archive)   │
    ├──────────────────────────────────►│
    │                                   │ 
    │ 4. Receive Broadcast event        │
    │◄──────────────────────────────────┤
    │                                   │
    │ 5. Update local UI                │
    │    (add bubble, scroll to bottom) │
```

Messages use Supabase Realtime Broadcast. The application utilizes a hybrid **Client-to-Client Broadcast Topology**. The Flutter app subscribes to its relevant channels and pushes messages via Broadcast for near-zero latency delivery. Simultaneously, it sends an async POST request to the `messages` table for permant historical storage. This permanently resolves any vulnerability to connection pool exhaustion and database event bottlenecks from maintaining millions of Postgres Change listeners.

**Offline message queue**: Messages sent while offline are stored in `sqflite` local database with status `queued`. A `ConnectivityCubit` watches network state. When connectivity returns, queued messages are sent in order and the local status is updated to `sent`.

## Search and Filters

A full-height bottom sheet with all available filters. Age range with a dual slider. City and country as multi-select searchable dropdowns. Sect and sub-sect. Deen level. Hijab and beard preferences. Minimum education. Employment type. Family type. Openness to divorced, widowed, and has-children partners. Distance radius: same city, 50km, 100km, same country, anywhere. Income range and active recently toggle are subscriber-only filters.

Name search allows first name plus city — never last name alone.

Up to 3 named filter presets can be saved.

### Name + City Search RPC

```sql
CREATE OR REPLACE FUNCTION search_profiles_by_name_city(p_viewer_id uuid, p_first_name text, p_city_id uuid)
RETURNS TABLE(profile_id uuid, first_name text, last_name_initial text, city_name text) AS $$
BEGIN
  RETURN QUERY
  SELECT p.id, p.first_name, LEFT(p.last_name,1), c.name
  FROM profiles p
  JOIN cities c ON p.city_id = c.id
  WHERE p.visibility = 'visible'
    AND p.onboarding_step >= 14
    AND p.user_id <> p_viewer_id
    AND p.first_name ILIKE p_first_name || '%'
    AND (p_city_id IS NULL OR p.city_id = p_city_id)
    AND NOT EXISTS (
      SELECT 1 FROM blocks b
      WHERE (b.blocker_id = p_viewer_id AND b.blocked_id = p.user_id)
         OR (b.blocker_id = p.user_id AND b.blocked_id = p_viewer_id)
    )
  ORDER BY p.first_name, p.id
  LIMIT 20;
END; $$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;
```

## My Profile Screen

Large hero photo with an edit overlay icon. Name and verification badges. A completeness bar in gold with the percentage and a specific next-step nudge below it. A Preview button showing exactly what others see. Tap any section to edit that section. A subscription status card. A 4-slot photo grid with drag-to-reorder.

## Subscription Screen

Clean single-purpose screen. Header: "Unlock NOOR." Subtext: "Women message free. Men subscribe to connect."

Two plan cards side by side: monthly and annual (labeled Best Value with a visual highlight). The price shown in the user's local currency. A clear list of what's included.

A single gold CTA button: "Subscribe — [price]/month." Below: Restore Purchase, Privacy Policy, Terms.

No upsell language. No fake urgency. No countdown timers.

### RevenueCat Integration

```dart
class SubscriptionService {
  static const _monthlyId = 'noor_monthly';
  static const _annualId = 'noor_annual';

  Future<void> initialize() async {
    await Purchases.setLogLevel(LogLevel.debug);
    final config = PurchasesConfiguration('revenuecat_public_api_key');
    await Purchases.configure(config);
  }

  Future<List<Package>> getOfferings() async {
    final offerings = await Purchases.getOfferings();
    return offerings.current?.availablePackages ?? [];
  }

  Future<bool> purchase(Package package) async {
    try {
      final result = await Purchases.purchasePackage(package);
      return result.customerInfo.entitlements.active.containsKey('premium');
    } on PurchasesErrorCode catch (e) {
      if (e == PurchasesErrorCode.purchaseCancelledError) return false;
      rethrow;
    }
  }

  Stream<CustomerInfo> get customerInfoStream =>
    Purchases.customerInfoStream;
}
```

## Settings

Organized into sections: Account (phone change, notifications by category, privacy controls, profile pause), Guardian (guardian phone, message mirror toggle), Safety (block list, report history), App (language from 8 options, version, rate app), Legal (ToS and Privacy Policy), Danger Zone (delete account with 30-day grace period explained, contact support). IMPORTANT: When an account is soft-deleted, the Flutter client MUST explicitly call `OneSignal.logout()` (or rely on an Edge Function) to prevent OneSignal ghost push notifications from haunting recycled telecom numbers.

---

# PART 9: TRUST AND SAFETY SYSTEM

## Verification Tiers (Automated)

Tier 1: Phone Verification — Mandatory for all.

Tier 2: AI Face Verification — Automated via Google ML Kit on-device. Ensures a real human face is present.

Tier 3: Proof of Life — Mandatory live camera selfie to prevent stolen/internet photos.

The 3-Report Auto-Ban
To replace manual moderation, NOOR uses Community Moderation.

If a profile receives 3 unique reports from different users for "Fake Profile" or "Inappropriate Content," the database trigger automatically sets visibility = 'suspended'.

The user is notified that their account is under review.


## Content Filtering

Bio and chat text are filtered for phone numbers, social media handles, and external URLs. These are rejected with a clear explanatory message. Use optimistic delivery. Insert the message immediately via Postgres (so the UI feels instant), and trigger an *asynchronous* background job to cleanly scan the text via an Edge Function/Queue. If the text violates policy, overwrite the `content` field directly via a server-side `UPDATE`. The client's Realtime listener will immediately see the `UPDATE` event payload and instantly redact the matching message live on screen. with "[contact info removed]" and the user receives a warning. Three such violations result in a 24-hour messaging suspension. External links are blocked entirely in chat.

### Chat Content Filter (Database Trigger)

```sql
-- Removed FUNCTION filter_message_content() for performance. Regex moved to app/edge.
-- CREATE OR REPLACE FUNCTION filter_message_content()
RETURNS trigger AS $$
DECLARE
  violation_count integer;
BEGIN
  -- Check for phone numbers
  IF NEW.content ~ '\+?\d[\d\s\-]{7,}\d' THEN
    NEW.content := '[contact info removed]';

    -- Count violations
    SELECT COUNT(*) INTO violation_count
    FROM content_violations
    WHERE user_id = NEW.sender_id
      AND created_at > NOW() - INTERVAL '24 hours';

    INSERT INTO content_violations (user_id, violation_type, original_content)
    VALUES (NEW.sender_id, 'phone_number', NEW.content);

    -- Suspension escalation handled by a separate trigger on content_violations
  END IF;

  -- Block URLs entirely
  IF NEW.content ~ '(https?://|www\.)\S+' THEN
    RAISE EXCEPTION 'Links are not allowed in messages for your safety.';
  END IF;

  -- Block social media handles
  IF NEW.content ~* '(@[\w.]+|(instagram|snapchat|whatsapp|telegram|facebook|twitter|tiktok)[\s.:/@]*[\w.]+)' THEN
    NEW.content := '[social media handle removed]';

    INSERT INTO content_violations (user_id, violation_type, original_content)
    VALUES (NEW.sender_id, 'social_media', NEW.content);
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- TRIGGER trg_filter_message_content REMOVED: String moderation via DB Regex creates massive insertion lock overhead.
-- CREATE TRIGGER trg_filter_message_content
  BEFORE INSERT ON messages
  FOR EACH ROW EXECUTE FUNCTION filter_message_content();
```

### Violation Escalation

```sql
-- Moved to Edge Function payload: escalate_messaging_suspension()
-- CREATE OR REPLACE FUNCTION escalate_messaging_suspension()
RETURNS trigger AS $$
DECLARE
  count_24h integer;
BEGIN
  SELECT COUNT(*) INTO count_24h
  FROM content_violations
  WHERE user_id = NEW.user_id
    AND created_at > NOW() - INTERVAL '24 hours';

  IF count_24h >= 3 THEN
    UPDATE users
    SET messaging_suspended_until = NOW() + INTERVAL '24 hours'
    WHERE id = NEW.user_id;
  END IF;

  RETURN NEW;
END; $$ LANGUAGE plpgsql;

CREATE TRIGGER trg_escalate_messaging_suspension
  AFTER INSERT ON content_violations
  FOR EACH ROW EXECUTE FUNCTION escalate_messaging_suspension();
```

## Reporting System

A report button is accessible from every profile (three-dot menu) and from within every conversation. Reporting a profile immediately hides that profile from the reporter. Three unique reports from different users triggers an automatic suspension pending admin review. Reporters receive notification of the resolution outcome.

### Report Reasons (Predefined)

```
- fake_profile: "This profile appears to be fake or impersonating someone"
- inappropriate_photos: "Photos contain inappropriate or offensive content"
- harassment: "This user is sending harassing or abusive messages"
- scam: "This user appears to be running a scam or asking for money"
- underage: "This user appears to be under 18"
- already_married: "This user is already married and misrepresenting themselves"
- offensive_bio: "Bio contains offensive or inappropriate language"
- other: "Other reason" (requires description)
```

### Auto-Suspension Trigger

```sql
CREATE OR REPLACE FUNCTION check_report_threshold()
RETURNS trigger AS $$
DECLARE
  report_count integer;
BEGIN
  SELECT COUNT(DISTINCT reporter_id) INTO report_count
  FROM reports
  WHERE reported_user_id = NEW.reported_user_id
    AND status = 'pending';

  IF report_count >= 3 THEN
    UPDATE profiles
    SET visibility = 'suspended', suspended_reason = 'auto_multiple_reports'
    WHERE user_id = NEW.reported_user_id;

    -- Notify admins
    INSERT INTO admin_notifications (type, message, related_user_id)
    VALUES ('auto_suspension', 'User auto-suspended after 3 reports', NEW.reported_user_id);
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_check_report_threshold
  AFTER INSERT ON reports
  FOR EACH ROW EXECUTE FUNCTION check_report_threshold();
```

## Blocking

Blocking is silent. The blocked person is not notified. They cannot find the blocker in search, their interests disappear, and the chat is removed from both sides. Both parties can still report each other independently.

## Anti-Fraud Measures

Daily interest caps are enforced at the database level — they cannot be bypassed by any client-side manipulation. Profile view spikes (more than 100 views in one hour) are flagged for review. New accounts cannot activate profile boosts in their first seven days.

### The Messaging Probation Period

To stop spam bots and professional scammers:

All new accounts enter a 48-hour Probation Period.

Can do: Browse feed, send Interests, receive Interests.
Cannot do: Send chat messages.

Logic: If user.created_at is less than 48 hours ago, the messages table trigger rejects the insert.

### Daily Interest Cap Enforcement

```sql
CREATE OR REPLACE FUNCTION enforce_interest_limits()
RETURNS trigger AS $$
DECLARE
  today_count integer;
  daily_limit integer;
  user_gender text;
  user_sub_status text;
  hours_since_approval double precision;
BEGIN
  SELECT gender, subscription_status INTO user_gender, user_sub_status
  FROM users WHERE id = NEW.sender_id; -- Specifically accepting loose race limit boundaries rather than imposing severe concurrency DEADLOCKS hitting user tables with FOR UPDATE.

  SELECT EXTRACT(EPOCH FROM (NOW() - p.approved_at)) / 3600.0
  INTO hours_since_approval
  FROM profiles p WHERE p.user_id = NEW.sender_id;

  -- Determine daily limit
  IF hours_since_approval < 168 THEN  -- First 7 days
    daily_limit := 3;
  ELSIF user_gender = 'female' THEN
    daily_limit := 10;
  ELSIF user_sub_status = 'active' THEN
    daily_limit := 20;
  ELSE
    daily_limit := 3;
  END IF;

  -- Count today's interests
  SELECT COUNT(*) INTO today_count
  FROM interests
  WHERE sender_id = NEW.sender_id
    AND created_at::date = CURRENT_DATE;

  IF today_count >= daily_limit THEN
    RAISE EXCEPTION 'Daily interest limit reached. You can send more interests tomorrow.';
  END IF;

  -- Prevent duplicate interests
  IF EXISTS (
    SELECT 1 FROM interests
    WHERE sender_id = NEW.sender_id
      AND receiver_id = NEW.receiver_id
      AND status IN ('pending', 'accepted')
  ) THEN
    RAISE EXCEPTION 'You have already sent an interest to this person.';
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_enforce_interest_limits
  BEFORE INSERT ON interests
  FOR EACH ROW EXECUTE FUNCTION enforce_interest_limits();
```

---

# PART 10: MATCHING AND DISCOVERY ALGORITHM

## Ranking Model

Filter exclusions remove ineligible profiles first. A composite score then orders remaining candidates:
- Filter Match: up to 40 points — hard blocks first, then bonuses for city and country proximity, education rank match, and deen match.
- Completeness: up to 20 points — `completeness_score / 5`.
- Recency: up to 20 points — active in last 24h: +20; 7d: +15; 30d: +8; older: +2.
- Compatibility: up to 15 points — symmetric preference match in both directions.
- Boost: up to 5 points — weekly subscriber boost window.

### Score Function

```sql
-- compute_global_rank_scores updates the rank centrally via pg_cron 
-- replacing on-the-fly 'Feed Crash' inline computations.
CREATE OR REPLACE FUNCTION compute_global_rank_scores()
RETURNS void AS 
BEGIN
  -- Base scoring logic applied globally to all visible profiles
  UPDATE profiles p
  SET static_rank_score = (
    -- Completeness
    COALESCE(p.completeness_score, 0) / 5.0 +
    -- Recency
    CASE
      WHEN p.last_active_at > NOW() - INTERVAL '1 day' THEN 20
      WHEN p.last_active_at > NOW() - INTERVAL '7 days' THEN 15
      WHEN p.last_active_at > NOW() - INTERVAL '30 days' THEN 8
      ELSE 2
    END +
    -- New profile boost
    CASE WHEN p.approved_at IS NOT NULL AND p.approved_at > NOW() - INTERVAL '7 days' THEN 10 ELSE 0 END +
    -- Weekly subscriber boost
    CASE WHEN p.is_boosted AND p.boost_expires_at > NOW() THEN 5 ELSE 0 END
  )
  WHERE p.visibility = 'visible';
END;
 LANGUAGE plpgsql SECURITY DEFINER;

-- Schedule nightly re-calculation
SELECT cron.schedule('compute_global_rank_scores_nightly', '0 2 * * *', SELECT compute_global_rank_scores(););
```

### Inactive Profile Management

```sql
-- Hide profiles when user is inactive for 30 days
CREATE OR REPLACE FUNCTION hide_inactive_profiles()
RETURNS void AS $$
BEGIN
  UPDATE profiles
  SET visibility = 'paused'
  WHERE visibility = 'visible'
    AND (last_active_at IS NULL OR last_active_at < NOW() - INTERVAL '30 days');
END;
$$ LANGUAGE plpgsql;

-- Schedule daily at 03:00
SELECT cron.schedule('hide_inactive_profiles_daily', '0 3 * * *', $$SELECT hide_inactive_profiles();$$);
```

### Diaspora Mode

When `profile_preferences.diaspora_mode = true`, distance filtering is replaced by preferred country filters. Discovery queries must check `preferred_countries` before distance calculations to avoid unnecessary geospatial work.

---

# PART 11: NOTIFICATION SYSTEM

## Timezone-Aware Delivery

Each user stores `timezone` and `quiet_hours_start`/`quiet_hours_end` (defaults 23:00–08:00). Notifications generated during quiet hours are queued for 08:00 local time.

### Tables

```sql
CREATE OR REPLACE FUNCTION checkout_notifications(batch_size int)
RETURNS TABLE (id uuid, user_id uuid, title text, body text) AS $$
BEGIN
  RETURN QUERY
  UPDATE notifications
  SET sent_at = NOW() 
  WHERE id IN (
    SELECT n.id FROM notifications n
    WHERE n.scheduled_at <= NOW() AND n.sent_at IS NULL
    ORDER BY n.scheduled_at ASC
    LIMIT batch_size
    FOR UPDATE SKIP LOCKED
  )
  RETURNING notifications.id, notifications.user_id, notifications.title, notifications.body;
END;
$$ LANGUAGE plpgsql;

CREATE TABLE notifications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  type text NOT NULL,
  title text NOT NULL,
  body text NOT NULL,
  deep_link text,
  scheduled_at timestamptz NOT NULL,
  sent_at timestamptz,
  read_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_notifications_user_sched ON notifications(user_id, scheduled_at);
```

### Queue Helper

```sql
CREATE OR REPLACE FUNCTION queue_notification(
  p_user_id uuid, p_type text, p_title text, p_body text, p_deep_link text DEFAULT NULL)
RETURNS void AS $$
DECLARE
  tz text;
  now_local time;
  deliver_at timestamptz;
BEGIN
  SELECT timezone INTO tz FROM users WHERE id = p_user_id;
  IF NOT EXISTS (SELECT 1 FROM pg_timezone_names WHERE name = tz) THEN
    tz := 'UTC';
  END IF;
  now_local := (NOW() AT TIME ZONE tz)::time;
  IF now_local >= time '23:00' OR now_local < time '08:00' THEN
    deliver_at := date_trunc('day', NOW() AT TIME ZONE tz) + interval '1 day' + time '08:00';
    deliver_at := (deliver_at AT TIME ZONE tz AT TIME ZONE 'UTC');
  ELSE
    deliver_at := NOW();
  END IF;
  INSERT INTO notifications (user_id, type, title, body, deep_link, scheduled_at)
  VALUES (p_user_id, p_type, p_title, p_body, p_deep_link, deliver_at);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;
```

### Dispatch Edge Function (OneSignal)

```
HTTP POST /edge/dispatch-notifications
  1. Fetch due notifications: scheduled_at <= now AND sent_at IS NULL LIMIT 500
  2. For each row:
     - Resolve device tokens for user
     - POST to OneSignal with title/body/deep link
     - On success, set sent_at = now
  3. Run every minute via cron
```

---

# PART 12: DATABASE STRUCTURE (DDL SKELETON)

### Extensions

```sql
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS pg_cron;
```

### Reference

```sql
CREATE TABLE countries (
  code text PRIMARY KEY,
  name text NOT NULL,
  dialing_code text NOT NULL,
  currency text NOT NULL,
  default_lang text NOT NULL,
  rtl boolean NOT NULL DEFAULT false,
  show_sect boolean NOT NULL DEFAULT true,
  show_sub_sect boolean NOT NULL DEFAULT false,
  wali_requirement text NOT NULL DEFAULT 'optional', -- optional|recommended|mandatory
  pricing_tier text NOT NULL
);

CREATE TABLE cities (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  name_local text,
  country_code text NOT NULL REFERENCES countries(code) ON DELETE CASCADE,
  latitude double precision NOT NULL,
  longitude double precision NOT NULL,
  timezone text NOT NULL,
  search_vector tsvector
);
CREATE INDEX idx_cities_country ON cities(country_code);
CREATE INDEX idx_cities_search ON cities USING GIN (search_vector);

CREATE OR REPLACE FUNCTION cities_searchvector_trigger()
RETURNS trigger AS $$
BEGIN
  NEW.search_vector := to_tsvector('simple', coalesce(NEW.name,'') || ' ' || coalesce(NEW.name_local,''));
  RETURN NEW;
END; $$ LANGUAGE plpgsql;
-- Note: Disable trg_cities_search in production. Cities are static, rebuilding static tsvector over geodata on updates creates heavy GIN lock contention.
-- CREATE TRIGGER trg_cities_search BEFORE INSERT OR UPDATE
ON cities FOR EACH ROW EXECUTE FUNCTION cities_searchvector_trigger();
```

### Core

```sql
CREATE TABLE users (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  phone text UNIQUE NOT NULL,
  country_code text NOT NULL,
  gender text NOT NULL CHECK (gender IN ('male','female')),
  preferred_language text NOT NULL DEFAULT 'en',
  timezone text NOT NULL DEFAULT 'UTC',
  subscription_status text NOT NULL DEFAULT 'none', -- none|active|grace
  subscription_expires_at timestamptz,
  messaging_suspended_until timestamptz,
  deleted_at timestamptz,
  deletion_status text NOT NULL DEFAULT 'active', -- active|pending_deletion|purged
  last_billing_event_ts bigint DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE OR REPLACE FUNCTION cascade_soft_delete()
RETURNS trigger AS $$
BEGIN
  IF NEW.deleted_at IS NOT NULL AND OLD.deleted_at IS NULL THEN
    -- Hide the profile immediately
    UPDATE profiles SET visibility = 'paused' WHERE user_id = NEW.id;
    -- Expire any pending interests involving this user
    UPDATE interests SET status = 'expired' 
    WHERE status = 'pending' AND (sender_id = NEW.id OR receiver_id = NEW.id);
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_cascade_soft_delete
  AFTER UPDATE OF deleted_at ON users
  FOR EACH ROW EXECUTE FUNCTION cascade_soft_delete();

CREATE TABLE profiles (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  static_rank_score integer DEFAULT 0,
  user_id uuid UNIQUE NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  first_name text NOT NULL,
  last_name text NOT NULL,
  date_of_birth date NOT NULL,
  gender text NOT NULL,
  country_code text NOT NULL REFERENCES countries(code),
  city_id uuid REFERENCES cities(id),
  location geography(Point,4326),
  sect text,
  sub_sect text,
  deen_level text,
  prays_five_daily boolean,
  hijab text,
  beard text,
  education_level text,
  education_rank int,
  profession text,
  income_bracket int,
  family_type text,
  parents_status text,
  previously_married text,
  children_count int,
  languages text[],
  bio text,
  photo_privacy text NOT NULL DEFAULT 'public', -- public|mutual_only
  visibility text NOT NULL DEFAULT 'auto_verified', -- auto_verified | visible | paused | suspended
  suspended_reason text,
  onboarding_step int NOT NULL DEFAULT 0,
  completeness_score int,
  guardian_phone_encrypted bytea,
  guardian_key_version text NOT NULL DEFAULT 'v1',
  guardian_name text,
  guardian_relationship text,
  guardian_mode text NOT NULL DEFAULT 'none',
  guardian_user_id uuid REFERENCES users(id) ON DELETE SET NULL,
  is_verified boolean NOT NULL DEFAULT false,
  is_boosted boolean NOT NULL DEFAULT false,
  boost_expires_at timestamptz,
  approved_at timestamptz,
  last_active_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_profiles_location ON profiles USING GIST (location);
CREATE INDEX idx_profiles_visibility ON profiles(visibility);
CREATE INDEX idx_profiles_last_active ON profiles(last_active_at);
CREATE INDEX idx_profiles_rank ON profiles(static_rank_score DESC, id DESC);

-- Ensure profiles.gender matches users.gender and handle gender pivots
CREATE OR REPLACE FUNCTION handle_profile_gender_pivot()
RETURNS trigger AS $$
BEGIN
  IF TG_OP = 'UPDATE' AND NEW.gender IS DISTINCT FROM OLD.gender THEN
    -- Expire pending interests instantly
    UPDATE interests SET status = 'expired' 
    WHERE status = 'pending' AND (sender_id = NEW.id OR receiver_id = NEW.id);
    
    -- Flag matches for review automatically
    INSERT INTO admin_audit_log (admin_id, action_type, target_user_id, details)
    VALUES (NEW.id, 'gender_pivot_detected', NEW.id, '{"action": "interests_expired", "matches_flagged": true}');
  END IF;
  RETURN NEW;
END; $$ LANGUAGE plpgsql;

CREATE TRIGGER trg_handle_gender_pivot
  AFTER UPDATE OF gender ON users
  FOR EACH ROW EXECUTE FUNCTION handle_profile_gender_pivot();

CREATE OR REPLACE FUNCTION enforce_profile_gender()
RETURNS trigger AS $$
BEGIN
  SELECT gender INTO NEW.gender FROM users WHERE id = NEW.user_id;
  RETURN NEW;
END; $$ LANGUAGE plpgsql;

CREATE TRIGGER trg_enforce_profile_gender
  BEFORE INSERT OR UPDATE OF user_id, gender ON profiles
  FOR EACH ROW EXECUTE FUNCTION enforce_profile_gender();

CREATE TABLE profile_preferences (
  profile_id uuid PRIMARY KEY REFERENCES profiles(id) ON DELETE CASCADE,
  preferred_age_min int,
  preferred_age_max int,
  preferred_city_ids uuid[],
  preferred_countries text[],
  sect_preference text,
  deen_preference text,
  min_education_rank int,
  open_to_divorced boolean,
  open_to_widowed boolean,
  open_to_has_children boolean,
  max_distance_km int,
  diaspora_mode boolean NOT NULL DEFAULT false,
  open_to_diaspora boolean NOT NULL DEFAULT false
);

ALTER TABLE profile_preferences 
ADD CONSTRAINT max_preferred_cities CHECK (array_length(preferred_city_ids, 1) <= 50),
ADD CONSTRAINT max_preferred_countries CHECK (array_length(preferred_countries, 1) <= 20);
```

### Activity

```sql
CREATE TABLE photos (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  profile_id uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  storage_path text NOT NULL,
  status text NOT NULL DEFAULT 'pending_upload', -- pending_upload|active
  order_index int NOT NULL DEFAULT 0,
  admin_approved boolean NOT NULL DEFAULT false,
  nsfw_cleared boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX idx_photos_primary ON photos(profile_id, order_index);

-- Note: trg_enforce_photo_quota has been removed.
-- Enforcing quotas inside a BEFORE INSERT trigger creates a bypass vulnerability
-- where a malicious client fetches unlimited Pre-Signed URLs and uploads to Storage
-- but never inserts the tracking row in Postgres.
-- INSTEAD: The Edge Function that generates the Pre-Signed URL MUST:
-- 1. Check current photo count (if >= 4, return 403 Forbidden).
-- 2. Generate the Pre-Signed Upload URL.
-- 3. INSERT INTO photos (profile_id, storage_path, status) VALUES (..., 'pending_upload').
-- 4. Return the URL to the client.

CREATE TABLE interests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  sender_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  receiver_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  status text NOT NULL DEFAULT 'pending', -- pending|accepted|declined|expired|withdrawn
  created_at timestamptz NOT NULL DEFAULT now(),
  expires_at timestamptz NOT NULL DEFAULT (now() + interval '14 days')
);
CREATE UNIQUE INDEX uq_interest_pair ON interests(
  LEAST(sender_id, receiver_id), 
  GREATEST(sender_id, receiver_id)
) WHERE status IN ('pending', 'accepted');
CREATE INDEX idx_interests_sender_day ON interests(sender_id, created_at);
CREATE INDEX idx_interests_receiver_status ON interests(receiver_id, status, created_at);

CREATE TABLE matches (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_a uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  user_b uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX uq_match_pair ON matches(LEAST(user_a,user_b), GREATEST(user_a,user_b));

CREATE TABLE messages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  match_id uuid NOT NULL REFERENCES matches(id) ON DELETE CASCADE,
  sender_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  receiver_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  content text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  read_at timestamptz,
  deleted_by_a boolean NOT NULL DEFAULT false,
  deleted_by_b boolean NOT NULL DEFAULT false
);
CREATE INDEX idx_messages_match_time ON messages(match_id, created_at);

-- Probation Period Trigger: Blocks messaging for first 48 hours
CREATE OR REPLACE FUNCTION enforce_probation_period()
RETURNS trigger AS $$
DECLARE
  user_created_at timestamptz;
BEGIN
  SELECT created_at INTO user_created_at FROM users WHERE id = NEW.sender_id;

  IF user_created_at > (NOW() - INTERVAL '48 hours') THEN
    RAISE EXCEPTION 'Your account is in a 48-hour security probation period. You will be able to send messages soon.';
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_enforce_probation
BEFORE INSERT ON messages
FOR EACH ROW EXECUTE FUNCTION enforce_probation_period();

-- Auto-create match on accepted interest
CREATE OR REPLACE FUNCTION create_match_on_accept()
RETURNS trigger AS $$
BEGIN
  IF NEW.status = 'accepted' THEN
    INSERT INTO matches (user_a, user_b)
    SELECT LEAST(NEW.sender_id, NEW.receiver_id), GREATEST(NEW.sender_id, NEW.receiver_id)
    ON CONFLICT (LEAST(user_a,user_b), GREATEST(user_a,user_b)) DO NOTHING;
  END IF;
  RETURN NEW;
END; $$ LANGUAGE plpgsql;

CREATE TRIGGER trg_create_match_on_accept
  AFTER UPDATE OF status ON interests
  FOR EACH ROW
  WHEN (OLD.status IS DISTINCT FROM NEW.status AND NEW.status = 'accepted')
  EXECUTE FUNCTION create_match_on_accept();
```

### Moderation and Admin

```sql
CREATE TABLE reports (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  reporter_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  reported_user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  reason text NOT NULL,
  description text,
  status text NOT NULL DEFAULT 'pending', -- pending|actioned|dismissed
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE OR REPLACE FUNCTION sever_ties_on_block()
RETURNS trigger AS $$
BEGIN
  DELETE FROM matches WHERE (user_a = NEW.blocker_id AND user_b = NEW.blocked_id) OR (user_b = NEW.blocker_id AND user_a = NEW.blocked_id);
  DELETE FROM interests WHERE (sender_id = NEW.blocker_id AND receiver_id = NEW.blocked_id) OR (sender_id = NEW.blocked_id AND receiver_id = NEW.blocker_id);
  RETURN NEW;
END; $$ LANGUAGE plpgsql;

CREATE TRIGGER trg_sever_ties_on_block
AFTER INSERT ON blocks
FOR EACH ROW EXECUTE FUNCTION sever_ties_on_block();

CREATE TABLE blocks (
  blocker_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  blocked_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (blocker_id, blocked_id)
);

CREATE TABLE admin_audit_log (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  admin_id uuid NOT NULL,
  action_type text NOT NULL,
  target_user_id uuid,
  details jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);
```

### Support and Compliance

```sql
CREATE TABLE content_violations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  violation_type text NOT NULL, -- phone_number|social_media|url
  original_content text,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_content_violations_user_time ON content_violations(user_id, created_at);

CREATE TABLE admin_notifications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  type text NOT NULL,
  message text NOT NULL,
  related_user_id uuid,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE user_consents (
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  consent_type text NOT NULL, -- terms_of_service|privacy_policy|age_verification
  version text NOT NULL,
  granted_at timestamptz NOT NULL DEFAULT now(),
  ip_address text,
  app_version text,
  PRIMARY KEY (user_id, consent_type, version)
);

CREATE TABLE notification_prefs (
  user_id uuid PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  new_interest boolean NOT NULL DEFAULT true,
  interest_accepted boolean NOT NULL DEFAULT true,
  new_message boolean NOT NULL DEFAULT true,
  profile_approved boolean NOT NULL DEFAULT true,
  interest_expiring boolean NOT NULL DEFAULT true,
  inactive_nudge boolean NOT NULL DEFAULT true,
  boost_available boolean NOT NULL DEFAULT true,
  quiet_start time NOT NULL DEFAULT time '23:00',
  quiet_end time NOT NULL DEFAULT time '08:00'
);

-- Helper to set guardian phone using pgcrypto and Key Versioning (KMS Strategy)
CREATE OR REPLACE FUNCTION set_guardian_phone(p_profile_id uuid, p_phone text)
RETURNS void AS $$
DECLARE
  v_secret text;
  v_key_name text := 'guardian_key_v1'; -- Active rotating key fetched from vault
BEGIN
  SELECT decrypted_secret INTO v_secret FROM vault.decrypted_secrets WHERE name = v_key_name;
  UPDATE profiles
  SET guardian_phone_encrypted = pgp_sym_encrypt(p_phone, v_secret),
      guardian_key_version = 'v1'
  WHERE id = p_profile_id;
END; $$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;
```

### Admin Auth (Optional Minimal)

```sql
CREATE TABLE admins (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  email text UNIQUE NOT NULL,
  password_hash text NOT NULL,
  role text NOT NULL CHECK (role IN ('moderator','admin','super_admin')),
  created_at timestamptz NOT NULL DEFAULT now()
);
```

### Scheduled Jobs (pg_cron)

```sql
-- Expire pending interests hourly
SELECT cron.schedule('expire_interests_hourly', '0 * * * *',
$$
UPDATE interests SET status = 'expired'
WHERE status = 'pending' AND expires_at < now();
$$);

-- Clean old notifications daily
SELECT cron.schedule('clean_notifications_daily', '30 2 * * *',
$$
DELETE FROM notifications WHERE sent_at IS NOT NULL AND scheduled_at < now() - interval '30 days';
$$);

-- Purge deleted accounts daily
CREATE TABLE storage_cleanup_queue (
  user_id uuid PRIMARY KEY,
  status text DEFAULT 'pending',
  created_at timestamptz DEFAULT now()
);

CREATE OR REPLACE FUNCTION queue_storage_cleanup() RETURNS trigger AS $$
BEGIN
  INSERT INTO storage_cleanup_queue (user_id) VALUES (OLD.id);
  RETURN OLD;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER clean_storage_on_user_delete
AFTER DELETE ON users
FOR EACH ROW EXECUTE FUNCTION queue_storage_cleanup();

-- Purge deleted accounts daily via Secure Webhook/Edge Function (Transactional Outbox)
-- DO NOT USE pg_cron for direct user deletions natively. It causes "Zombie Auth".
-- Process: users are marked deletion_status = 'pending_deletion'.
-- An Edge Function MUST use the supabase-admin client to call `supabase.auth.admin.deleteUser(uid)`.
-- ONLY after Auth API returns 200 OK does it delete the user from public.users natively!
SELECT cron.schedule('trigger_purge_deleted_accounts', '15 3 * * *',
$$
  -- Using pg_net extension to POST to Edge Function to handle administrative drops natively.
  SELECT net.http_post(
      url:='https://project-ref.supabase.co/functions/v1/admin-purge-deleted-users',
      body:='{}'::jsonb
  );
$$);
```
---

# PART 13: DATA ACCESS RULES (RLS)

## Profiles

```sql
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

-- Read visible profiles, or own profile
CREATE POLICY profiles_read ON profiles
FOR SELECT USING (
  user_id = auth.uid() OR visibility = 'visible'
);

-- Insert own profile
CREATE POLICY profiles_insert ON profiles
FOR INSERT WITH CHECK (user_id = auth.uid());

-- Update only own profile
CREATE POLICY profiles_update ON profiles
FOR UPDATE USING (user_id = auth.uid())
WITH CHECK (user_id = auth.uid());
```

## Photos

Helper:
```sql
CREATE OR REPLACE FUNCTION can_view_photo(p_viewer uuid, p_owner_profile uuid)
RETURNS boolean AS $$
BEGIN
  IF p_viewer IS NULL THEN RETURN false; END IF;
  IF EXISTS (SELECT 1 FROM profiles WHERE id = p_owner_profile AND user_id = p_viewer) THEN
    RETURN true;
  END IF;
  IF EXISTS (
    SELECT 1 FROM profiles pr
    WHERE pr.id = p_owner_profile 
      AND pr.photo_privacy = 'public'
      AND pr.visibility IN ('visible', 'pending_review')
  ) THEN
    RETURN true;
  END IF;
  IF EXISTS (
    SELECT 1 FROM matches m
    JOIN profiles a ON a.user_id = m.user_a
    JOIN profiles b ON b.user_id = m.user_b
    WHERE (m.user_a = p_viewer AND b.id = p_owner_profile)
       OR (m.user_b = p_viewer AND a.id = p_owner_profile)
  ) THEN
    RETURN true;
  END IF;
  RETURN false;
END; $$ LANGUAGE plpgsql STABLE;
```

Policy:
```sql
ALTER TABLE photos ENABLE ROW LEVEL SECURITY;
CREATE POLICY photos_read ON photos
FOR SELECT USING (
  admin_approved AND nsfw_cleared
  AND can_view_photo(auth.uid(), profile_id)
);
CREATE POLICY photos_insert ON photos
FOR INSERT WITH CHECK (
  EXISTS (SELECT 1 FROM profiles p WHERE p.id = profile_id AND p.user_id = auth.uid())
);
```

## Interests and Messages

```sql
ALTER TABLE interests ENABLE ROW LEVEL SECURITY;
CREATE POLICY interests_rw ON interests
USING (sender_id = auth.uid() OR receiver_id = auth.uid())
WITH CHECK (sender_id = auth.uid());

ALTER TABLE matches ENABLE ROW LEVEL SECURITY;
CREATE POLICY matches_read ON matches
USING (
  user_a = auth.uid() OR 
  user_b = auth.uid() OR
  EXISTS (
    SELECT 1 FROM profiles 
    WHERE (user_id = matches.user_a OR user_id = matches.user_b) 
    AND guardian_user_id = auth.uid()
  )
);

ALTER TABLE messages ENABLE ROW LEVEL SECURITY;
CREATE POLICY messages_rw ON messages
USING (
  sender_id = auth.uid() OR receiver_id = auth.uid()
)
WITH CHECK (
  sender_id = auth.uid()
);
```

## Blocks Enforcement

All discovery queries already exclude blocked pairs. Additionally, enforce in RLS for defensive depth by adding `NOT EXISTS` subqueries in policies where feasible.

---

# PART 14: SUBSCRIPTION ENFORCEMENT

## Database Gate for Messaging

```sql
CREATE OR REPLACE FUNCTION assert_messaging_allowed()
RETURNS trigger AS $$
DECLARE
  g text;
  sub text;
  expires timestamptz;
  suspended_until timestamptz;
BEGIN
  SELECT gender, subscription_status, subscription_expires_at, messaging_suspended_until
  INTO g, sub, expires, suspended_until
  FROM users WHERE id = NEW.sender_id;

  IF suspended_until IS NOT NULL AND suspended_until > NOW() THEN
    RAISE EXCEPTION 'Messaging suspended until %', suspended_until;
  END IF;

  IF g = 'male' THEN
    IF sub = 'active' THEN
      RETURN NEW;
    END IF;
    IF sub = 'grace' AND expires IS NOT NULL AND expires > NOW() - INTERVAL '24 hours' THEN
      RETURN NEW;
    END IF;
    RAISE EXCEPTION 'Subscribe to unlock messaging. Women always message free on NOOR.';
  END IF;
  RETURN NEW;
END; $$ LANGUAGE plpgsql;

CREATE TRIGGER trg_assert_messaging_allowed
BEFORE INSERT ON messages
FOR EACH ROW EXECUTE FUNCTION assert_messaging_allowed();
```

## RevenueCat Webhook (Edge)

```
POST /edge/revenuecat-webhook
  - Verify signature
  - Map event: initial_purchase, renewal, cancellation, expiration, billing_issue, refund
  - Check if incoming webhook event_timestamp_ms > users.last_billing_event_ts (if false: IGNORE/DROP to prevent race conditions downgrading accounts)
  - Update users.subscription_status, subscription_expires_at, and last_billing_event_ts
  - Only apply 24h grace specifically on `billing_issue` events from RevenueCat. Never fail-open 'grace' status on timeouts or unknown webhook errors to prevent malicious free tier bypass.
```

---

# PART 15: STORAGE AND PHOTO PRIVACY POLICIES

## Bucket: profile-photos

```sql
-- Storage RLS
ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;

-- Direct INSERT policy for storage_insert_profile_photos REMOVED.
-- To completely eradicate bucket exhaustion vulnerabilities allowing users to bypass database limits locally, direct bucket uploads must be fully deactivated natively.
-- All photo workloads must request Pre-Signed Upload URLs independently generated via 
-- Edge Functions only after evaluating their quota natively within Postgres.

-- CRITICAL SECURITY REQUIREMENT: get-signed-url Edge Function
-- The Edge Function issuing Pre-Signed URLs MUST implement Strict Rate Limiting (e.g., using Redis/Upstash).
-- Limit to maximum 100 URL requests per hour per authenticated UID.
-- Loopers exceeding the threshold must be flagged for "Mass Data Scraping" and auto-banned 
-- to protect the platform's core photo privacy mechanisms.

-- Read policy for storage_select_profile_photos REMOVED
-- SELECT is disabled entirely natively on Storage Objects. Do not evaluate PL/pgSQL subqueries in Storage RLS to prevent connection pool exhaustion.
-- Instead, Edge Functions or dedicated proxy instances must issue short-lived Signed URLs for approved requests.
```

---

# PART 16: PERFORMANCE TARGETS

- Feed opens < 1s on 4G; profile detail < 800ms; chat delivery < 400ms.
- Use skeleton loaders across discovery, detail, and lists; avoid global spinners.
- Cache last 20 viewed profiles and last 50 messages per conversation locally; queue offline actions with retries.
- Thumbnails 20 KB, card-size 55 KB, detail 180 KB via CDN transforms.

---

# PART 17: COLD START STRATEGY

- Pre-launch waitlist in English and Hindi/Urdu; collect 300+ profiles via form and manually onboard.
- Join and observe 15–20 matrimony groups; contribute value; softly introduce NOOR.
- Instagram cadence: 3 posts/week; design-led, value-first, success-story oriented.
- Soft launch to 100 internal testers; target 500 completed profiles before public.
- Public launch when two cities have supply; aim for 1,000 completed profiles in 30 days.

---

# PART 18: PHASED FEATURE ROADMAP

- Phase 1 (MVP): core onboarding, automated AI photo gate, discovery, interests, text chat (with 48h probation), RevenueCat, community-based reporting (3-report ban), push, block/report, settings, analytics, crashes.
- Phase 2: full guardian UI, ID verification, weekly boost, advanced filter presets, visible compatibility score, referrals, in-app notification center, admin bulk tools.
- Phase 3: iOS build, family account linking, success stories, short video intro, community seminars, scholar endorsement badge.
- Phase 4: diaspora deep push, full Urdu/Arabic copy, verified matchmaker tier, partner APIs.

---

# PART 19: OPERATIONAL WATCH-OUTS

- Android OTP deep link reliability; battery optimization exemptions and explicit status UI.
- App Store review risk; emphasize matrimony and guardian features, never use dating vocabulary.
- RevenueCat webhook delays; fail-open and monitor fallback counters.
- Timezone pushes; enforce quiet hours and local scheduling.
- RTL from day one; directional padding/alignment; test chat and navigation in RTL.
- Education rank numeric backbone; never rely on text comparison for filtering.
- City search vector trigger; seed and verify on fresh DB.

---

# PART 20: PRIVACY AND COMPLIANCE

- Never expose phone numbers, exact DOB, guardian contacts, IDs, or precise coordinates.
- User controls: photo privacy, last active visibility, pause profile, export data, 30-day delete grace.
- Third-party disclosures: Firebase (OTP), RevenueCat (anonymous entitlements), OneSignal (device token), PostHog (anonymous events), Sentry (crash traces).
- Under-18 hard block in app and DB.
- Store classification as Lifestyle/Matrimony, not Dating.

---

# PART 21: ADMIN OPERATIONS

- Web-only admin with email/password; queues for photos and reports; actions logged to `admin_audit_log`.
- Broadcasts by segment with preview; daily metrics for registrations, DAU, M/F ratio, conversion, revenue, active cities, report categories, avg completeness.

---

# PART 22: REVENUE PROJECTIONS BY MARKET

- India Tier 3 (₹249/mo): 3,000 men, 750 paying → ≈ $2,240/mo.
- Pakistan Tier 3 (Rs 299/mo): 1,800 men, 450 paying → ≈ $480/mo.
- UK Tier 1 (£7.99/mo): 1,200 men, 300 paying → ≈ $3,040/mo.
- Combined Year 1: $8K–$12K conservative; up to ~$35K at 53K users; infra $25–$75/mo.

---

# PART 23: PRE-BUILD CHECKLIST

- Domains, Firebase Auth (phone), Supabase (ap-south-1), Play Console, RevenueCat, OneSignal, PostHog, Dynamic Links, Sentry, UptimeRobot, Instagram.
- Securely store service keys; never in code.
- Waitlist site and profile intake form live.

---

# PART 24: BUILD ORDER

1. Supabase schema, indexes, triggers, RLS, cron jobs; seed countries/cities/income.
2. Firebase OTP → Supabase session exchange Edge Function.
3. Flutter project with design tokens and RTL-aware theme.
4. Auth screens and deep link callback.
5. 14-step onboarding with cultural adaptation and resume.
6. Discovery feed with cursor pagination and skeleton loaders.
7. Profile detail, interest ceremony.
8. Interests lifecycle.
9. Chat with realtime and offline queue.
10. Subscription with server enforcement.
11. Settings, notifications, block/report.
12. Admin web panel for photo/report queues.

---

# PART 25: COLD START IN INDIA

- Channels: Facebook groups, WhatsApp city communities, Instagram, YouTube reviews, masjid boards.
- Success-story engine with consent; each authentic story drives meaningful signups.

---

# APPENDIX: ALL RESOLVED ISSUES (SUMMARY)

- Seven critical: indexes, realtime limits, RLS block logic, photo privacy, server-side subscriptions, interest expiry, match validation.
- High: admin performance, soft delete grace, rate limiting, storage bucket RLS, webhook race, guardian phone encryption, cursor pagination, auto match creation.
- Medium: offline queue, income type, deep link validation, name search index, PostHog privacy, gender immutability, NSFW timing, RTL layout, backups, health check.
- Low: naming, timestamps, API versioning, completeness optimization, notification retention.
- Global: pricing tiers, geospatial matching, timezone awareness, RTL, multi-region.

*Bismillah — this is the complete, build-ready edition.*
