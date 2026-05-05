# NOOR — Project Audit Report

**Date:** May 4, 2026
**Project:** NOOR (نور) — Premium Muslim Matrimony App
**Framework:** Flutter (Dart)
**Version:** 1.0.0+1

---

## Table of Contents

1. [Overview](#overview)
2. [Critical Security Issues](#1-critical-security-issues)
3. [Bugs](#2-bugs)
4. [Architecture Issues](#3-architecture-issues)
5. [Code Quality](#4-code-quality)
6. [Missing Features](#5-missing-features)
7. [Priority Matrix](#6-priority-matrix)
8. [Recommended Action Plan](#7-recommended-action-plan)

---

## Overview

NOOR is a Flutter-based Muslim matrimony application featuring:

- **Auth:** Phone-based OTP verification (mock)
- **Onboarding:** 10-12 step flow with guardian branch
- **Discovery:** Swipe/feed with filters and daily interest limits
- **Chat:** Mock messaging system
- **Subscription:** Gender-based free access for women, paid for men
- **Localization:** 8 languages (en, ar, ur, ms, id, tr, de, fr) with RTL support
- **State Management:** flutter_bloc with 10 cubits

### Tech Stack

| Category | Technology |
|----------|------------|
| Framework | Flutter (SDK >=3.3.0) |
| State Management | flutter_bloc + equatable |
| Navigation | go_router |
| Backend (planned) | Supabase |
| Localization | flutter_localizations + intl |
| Utilities | shared_preferences, image_picker, flutter_image_compress |
| Animations | flutter_animate, cached_network_image |

### Project Structure

```
lib/
├── core/
│   ├── config/          # App configuration
│   ├── cubits/          # 10 BLoC cubits (auth, chat, discovery, etc.)
│   ├── mock/            # Hardcoded mock data
│   ├── models/          # Data models
│   ├── router/          # GoRouter configuration
│   ├── services/        # Bookmark + filter preset services
│   ├── theme/           # Theme, colors, typography, dimensions
│   ├── utils/           # Utility functions
│   └── widgets/         # Reusable widgets
├── features/
│   ├── home/            # Home screen + sub-screens
│   └── onboarding/      # 12 onboarding screens
└── main.dart            # Entry point
```

---

## 1. Critical Security Issues

### 1.1 API Key Exposed in `opencode.json`
- **File:** `opencode.json:7`
- **Issue:** DeepSeek API key `sk-8bfa9b49524d4c149116568c0ca38c63` is hardcoded in plaintext
- **Risk:** Committed to version control, exposed to anyone with repo access
- **Fix:** Add `opencode.json` to `.gitignore`, use environment variables or `.env` file

### 1.2 Hardcoded Supabase Placeholder Credentials
- **File:** `lib/core/config/app_config.dart`
- **Issue:** Supabase URL and Anon Key hardcoded as `YOUR_PROJECT` / `YOUR_ANON_KEY`
- **Risk:** Will likely be committed to version control; Supabase anon keys are public but should still be managed properly
- **Fix:** Use `--dart-define` at build time or `flutter_dotenv`

### 1.3 Mock OTP Accepts Any 6-Digit Code
- **File:** `lib/core/cubits/auth/auth_cubit.dart`
- **Issue:** Any 6-digit code is accepted when `kOtpVerificationMockEnabled = true`
- **Risk:** If this flag leaks to production, any attacker could log in as any user
- **Fix:** Gate mock mode behind `kDebugMode` only; never ship in release builds

### 1.4 No Rate Limiting on Authentication
- **File:** `lib/core/cubits/auth/auth_cubit.dart`
- **Issue:** No OTP rate limiting, retry caps, or cooldown periods
- **Risk:** Brute force attacks on phone numbers
- **Fix:** Add client-side exponential backoff and retry limits

### 1.5 No JWT/Session Token Validation
- **File:** `lib/core/cubits/auth/auth_cubit.dart`
- **Issue:** `checkSessionStatus()` does not validate token expiry or implement refresh logic
- **Risk:** Stale/expired sessions treated as valid
- **Fix:** Implement proper token refresh via Supabase `refreshSession()`

---

## 2. Bugs

### 2.1 Timer Memory Leak in InterestsCubit
- **File:** `lib/core/cubits/interests/interests_cubit.dart`
- **Issue:** `Timer.periodic` started for checking expired interests but never cancelled on cubit close
- **Impact:** Memory leak and potential crash from accessing closed cubit state
- **Fix:** Override `onClose()` and call `_expirationCheckTimer?.cancel()`

### 2.2 Discovery Feed Unbounded Growth
- **File:** `lib/core/cubits/discovery/discovery_feed_cubit.dart`
- **Issue:** `_loadInitialProfiles` and `loadMoreProfiles` append profiles using `List.from(current) + newBatch` with no cap
- **Impact:** Memory leak and UI degradation as list grows indefinitely
- **Fix:** Implement maximum pool size or "no more profiles" state

### 2.3 Chat Race Condition
- **File:** `lib/core/cubits/chat/chat_cubit.dart`
- **Issue:** `sendMessage()` uses `await Future.delayed` and directly mutates `_messages[conversationId]` without synchronization
- **Impact:** Rapid sends cause message ordering issues or lost messages
- **Fix:** Use immutable state updates via `emit()`

### 2.4 Filter Application Order Bug
- **Files:** `lib/core/cubits/discovery/discovery_feed_cubit.dart`, `lib/core/services/filter_preset_service.dart`
- **Issue:** Filters applied AFTER mock pool extension via `_extendMockProfiles()`, producing inconsistent results
- **Fix:** Apply filters to base pool first, then extend only the filtered result

### 2.5 Block/Report State Not Propagating to Chat
- **File:** `lib/features/home/screens/chat_screen.dart`
- **Issue:** When a user is blocked, the chat cubit does not receive the update; existing conversations remain accessible
- **Fix:** Emit state update from `BlockReportCubit` that `ChatCubit` listens to

### 2.6 Gender-Based Subscription Edge Case
- **File:** `lib/features/subscription/screens/subscription_screen.dart`
- **Issue:** `currentUserGender != UserGender.female` grants free access; null gender may default incorrectly
- **Fix:** Handle null gender explicitly, default to requiring subscription

---

## 3. Architecture Issues

### 3.1 No Repository Layer
- **Issue:** Cubits handle both state management AND data fetching directly
- **Impact:** Violates Single Responsibility Principle; hard to swap mock/real implementations
- **Fix:** Introduce repository abstractions:
  ```dart
  abstract class AuthRepository { Future<AuthResult> verifyOtp(String otp); }
  class MockAuthRepository implements AuthRepository { ... }
  class SupabaseAuthRepository implements AuthRepository { ... }
  ```

### 3.2 No Dependency Injection
- **Issue:** All cubits and services are instantiated directly in `main.dart`
- **Impact:** Hard to test; cumbersome to swap implementations
- **Fix:** Adopt `get_it` + `injectable` or migrate to `riverpod`

### 3.3 Tight Coupling to Mock Data
- **Issue:** Cubits directly import and use mock data from `lib/core/mock/`
- **Impact:** Cannot switch to real API without rewriting cubits
- **Fix:** Inject repositories; keep mock data behind repository implementations

### 3.4 No Centralized Error Handling
- **Issue:** Cubits emit `Error` states but no error type hierarchy or user-friendly mapping
- **Impact:** Inconsistent error UX across the app
- **Fix:** Create sealed class `AppError` with subtypes (NetworkError, AuthError, ValidationError, etc.)

### 3.5 Navigation Logic Scattered
- **Issue:** GoRouter config is centralized but navigation triggers scattered across cubits and widgets
- **Fix:** Centralize navigation in a `NavigatorService` or use router redirects based on state

---

## 4. Code Quality

### 4.1 Missing `const` Constructors
- **Location:** Throughout `lib/features/` and `lib/core/widgets/`
- **Impact:** Unnecessary widget rebuilds and degraded performance
- **Fix:** Enable `prefer_const_constructors` lint rule

### 4.2 Magic Numbers
- **Location:** `discovery_feed_cubit.dart`, `subscription_screen.dart`, and others
- **Examples:** `500`, `1000`, `25`, `10` appear inline without explanation
- **Fix:** Extract to named constants at the top of each file

### 4.3 Deeply Nested Widget Trees
- **Location:** Multiple screen files in `lib/features/`
- **Impact:** 10+ levels of nesting harms readability and performance
- **Fix:** Extract sub-widgets into separate components

### 4.4 Strings Not Localized
- **Location:** Multiple screens
- **Issue:** Hardcoded English strings exist alongside l10n system
- **Fix:** Migrate all hardcoded strings to ARB files in `lib/l10n/`

### 4.5 Repeated `Future.delayed` Pattern
- **Location:** All cubits
- **Issue:** Every async operation uses `await Future.delayed(const Duration(milliseconds: 500))`
- **Fix:** Abstract into a configurable `MockNetworkSimulator` service

### 4.6 Massive Mock Data Files
- **Location:** `lib/core/mock/mock_profiles.dart`, `lib/core/mock/mock_interests.dart`
- **Issue:** Large hardcoded mock datasets bloat the codebase
- **Fix:** Move mock data to JSON asset files; load at runtime

---

## 5. Missing Features

| Feature | Status | Recommendation |
|---------|--------|----------------|
| Unit/Widget Tests | None | Start with cubit unit tests |
| Real Supabase Integration | All mock | Implement repositories with Supabase |
| Real-Time Sync (Chat/Interests) | Polling/mock | Supabase Realtime subscriptions |
| Push Notifications | Mock only | FCM/APNs integration |
| Image Upload/Cropping | Static placeholders | `image_picker` + Supabase Storage |
| Offline Mode | None | `connectivity_plus` + caching |
| Analytics | None | Firebase Analytics or Mixpanel |
| CI/CD Pipeline | None | GitHub Actions or Codemagic |
| Accessibility (a11y) | None | Semantic labels, screen reader testing |
| Loading State Consistency | Inconsistent | Standardize `LoadingOverlay` or `ShimmerLoading` |

---

## 6. Priority Matrix

| Priority | Category | Count | Key Actions |
|----------|----------|-------|-------------|
| **P0 — Critical** | Security | 5 | Secrets management, OTP gate, rate limiting, token refresh |
| **P1 — High** | Bugs | 6 | Timer leak, feed cap, chat race, filter order, block propagation |
| **P1 — High** | Architecture | 5 | Repository layer, DI, error handling, state persistence |
| **P2 — Medium** | Code Quality | 6 | `const` constructors, extract mocks, localization, magic numbers |
| **P2 — Medium** | Missing Features | 5 | Tests, realtime, push notifications, analytics, CI/CD |
| **P3 — Low** | General | 5 | Accessibility, loading consistency, asset optimization |

---

## 7. Recommended Action Plan

### Phase 1: Security & Critical Fixes (Week 1)
- [ ] Add `opencode.json` to `.gitignore`
- [ ] Move API keys to `--dart-define` or `.env`
- [ ] Gate mock OTP behind `kDebugMode`
- [ ] Fix timer memory leak in `InterestsCubit`
- [ ] Cap discovery feed profile list

### Phase 2: Architecture Refactor (Weeks 2-3)
- [ ] Introduce repository layer (Auth, Discovery, Chat, Interests)
- [ ] Set up `get_it` for dependency injection
- [ ] Create centralized error handling (`AppError` sealed class)
- [ ] Fix chat race condition with immutable state updates

### Phase 3: Code Quality & Testing (Weeks 3-4)
- [ ] Add `const` constructors throughout
- [ ] Migrate hardcoded strings to ARB files
- [ ] Extract sub-widgets from deeply nested screens
- [ ] Write unit tests for all cubits
- [ ] Write widget tests for critical screens

### Phase 4: Real Integration (Weeks 5-6)
- [ ] Implement Supabase auth (real OTP, session management)
- [ ] Set up Supabase Realtime for chat and interests
- [ ] Add image upload to Supabase Storage
- [ ] Integrate FCM for push notifications

### Phase 5: Polish & CI/CD (Week 7+)
- [ ] Add analytics (onboarding drop-off, subscription conversion)
- [ ] Set up GitHub Actions for lint, test, build
- [ ] Accessibility audit and fixes
- [ ] Performance profiling and optimization
