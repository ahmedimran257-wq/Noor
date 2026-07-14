# SILARAH Design System Specification

Welcome to the design specification for **SILARAH**. This document serves as the single source of truth for the design language, styling tokens, typography, dimensions, components, and motion guidelines used throughout the codebase.

---

## 1. DESIGN DNA & PHILOSOPHY
SILARAH is designed around the concept of **Quiet Luxury**. Premium design is characterized by precision, whitespace, and restraint, rather than flashy patterns.
*   **Vibe:** A serene, premium "private gallery" feel rather than a generic template or a crowded social network.
*   **Identity Tagline:** *"Begin with bismillah"* — anchoring the experience in custom and tradition.
*   **Whitespace:** Used as a first-class feature to allow layout breathing room.

---

## 2. COLOR PALETTE
We avoid using pure blacks or harsh primary colors. Every color is calibrated to provide soft contrast and depth in dark mode.

| Token Name | Hex Value / Value | Purpose & Usage |
| :--- | :--- | :--- |
| **Primary Palette** | | |
| `obsidianNight` | `#0A0A0F` | Default main screen background. Deep blue-black. |
| `obsidianDeep` | `#1A1A2F` | Base background color for the radial splash gradient. |
| `champagneGold` | `#C5A059` | Accent color, used sparingly: CTAs, active states, verified indicators. |
| `pearlWhite` | `#F5F5F7` | Primary text. Soft muted white (Apple-style) to prevent eye strain. |
| `slateMist` | `#8E8E93` | Secondary text, captions, hints, and default icon colors. |
| **Surface & Semantic** | | |
| `surfaceGlass` | `rgba(255, 255, 255, 0.04)` | Main surface background (cards/overlays) for glassmorphism. |
| `surfaceGlassHover` | `rgba(255, 255, 255, 0.07)` | Slightly brighter surface for interactive/hover states. |
| `inputSurface` | `rgba(255, 255, 255, 0.05)` | Dedicated input field fill (provides subtle structure). |
| `cardBorder` | `rgba(255, 255, 255, 0.08)` | Thin, crisp border defining card bounds instead of shadows. |
| `goldBorder` | `rgba(197, 160, 89, 0.40)` | Active borders, selected items, verified ring borders. |
| `goldGlow` | `rgba(197, 160, 89, 0.15)` | Glowing highlight for active indicators and focus rings. |
| `verifiedTeal` | `#2DCDA9` | Verified badge. A muted teal (not neon green). |
| `softCoral` / `errorRed` | `#E67E7E` | Muted semantic color for errors, warnings, and deletes. |
| **Derived & Utility** | | |
| `messageBubbleReceived` | `#1C1C24` | Grey-black bubble color for incoming chat messages. |
| `progressBarBase` | `rgba(142, 142, 147, 0.20)` | Inactive segment of onboarding progress bars. |
| `divider` | `rgba(255, 255, 255, 0.06)` | Barely visible dividers. |
| **Card Gradients** | | |
| `cardGradientTop` | `rgba(10, 10, 15, 0.00)` | Top section of the photo overlay gradient (fully transparent). |
| `cardGradientMid` | `rgba(10, 10, 15, 0.30)` | Mid section of the photo overlay gradient (30% opacity). |
| `cardGradientBottom`| `rgba(10, 10, 15, 1.00)` | Bottom section of the photo overlay (opaque, text safety shield). |

---

## 3. TYPOGRAPHY SYSTEM
SILARAH utilizes a **Dual Font-Pairing Strategy** to evoke an editorial, high-end magazine feel.

1.  **Heading Font:** `Playfair Display` (Elegant Serif)
    *   *Usage:* Screen titles, user profiles, tagline, and bios (in italic style to represent authentic voice).
2.  **Body Font:** `Inter` (Clean Geometric Sans-Serif)
    *   *Usage:* Body copy, chips, buttons, labels, and text inputs.

### Type Scale

| Element | Font Family | Size | Weight | Line Height | Color | Spacing / Style |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Screen Title** | Playfair Display | `28px` | Bold (700) | `1.2` | `pearlWhite` | `0.5px` |
| **User Name** | Playfair Display | `24px` | SemiBold (600) | `1.25` | `pearlWhite` | `0.2px` |
| **Bio (Italic)** | Playfair Display | `17px` | Regular (400) | `1.6` | `pearlWhite` | Italic, `0.1px` |
| **Tagline** | Playfair Display | `16px` | Regular (400) | `1.4` | `slateMist` | Italic |
| **Wordmark Logo** | Inter | `22px` | ExtraBold (800) | Default | `champagneGold` | `2.0px` Tracking |
| **Section Label** | Inter | `11px` | Medium (500) | `1.2` | `slateMist` | UPPERCASE, `1.5px` |
| **Body Text** | Inter | `15px` | Regular (400) | `1.5` | `pearlWhite` | `0.0px` |
| **Body Muted** | Inter | `15px` | Regular (400) | `1.5` | `slateMist` | `0.0px` |
| **Body Medium** | Inter | `15px` | Medium (500) | `1.5` | `pearlWhite` | `0.0px` |
| **Card Location** | Inter | `14px` | Regular (400) | `1.3` | `pearlWhite` (85%)| `0.0px` |
| **Caption** | Inter | `13px` | Regular (400) | `1.4` | `slateMist` | `0.0px` |
| **Caption Medium** | Inter | `13px` | Medium (500) | `1.4` | `pearlWhite` | `0.0px` |
| **Chip Label** | Inter | `12px` | Medium (500) | Default | `pearlWhite` | `0.2px` |
| **Primary Button** | Inter | `16px` | SemiBold (600) | `1.0` | `obsidianNight` | `0.2px` |
| **Secondary Button** | Inter | `16px` | SemiBold (600) | `1.0` | `champagneGold` | `0.2px` |
| **Ghost Button** | Inter | `16px` | Medium (500) | `1.0` | `pearlWhite` | `0.2px` |
| **Input Label** | Inter | `13px` | Regular (400) | Default | `slateMist` | `0.0px` |
| **Input Text** | Inter | `15px` | Regular (400) | `1.4` | `pearlWhite` | `0.0px` |

*Note: For non-Latin locales (e.g., Arabic, Urdu), fallback serif typography is dynamically resolved at a `1.4` line height.*

---

## 4. GEOMETRY & SPACING
A strict layout structure ensures visual consistency and touch-friendly interactive targets.

### Spacing & Margins
*   **Standard Margin:** `24px` horizontal padding on all layout containers.
*   **Touch Target Size:** `48px` minimum width/height for any tap actions (navigation, icon buttons).
*   **Layout Grid (8pt scale):** Spacing options must adhere strictly to the scale: `2px`, `4px`, `6px`, `8px`, `10px`, `12px`, `14px`, `16px`, `20px`, `24px`, `28px`, `32px`, `40px`, `48px`, `56px`, `64px`, `80px`.

### Corner Radii
*   **Large Cards / Bottom Sheets:** `24px` (creates a soft, contemporary silhouette).
*   **Buttons / Text Inputs:** `12px` (structured and professional — **never** use pill/circular shapes).
*   **Chips / Tags:** `8px`.
*   **Indicators / Badges:** `4px`.

### Border Widths
*   **Default Card/Widget Border:** `1px` (`borderThin`).
*   **Focus State Border:** `2px` (`borderFocus`).

### Aspect Ratio
*   **Main Discovery Cards:** `3:4` portrait ratio.

---

## 5. CORE ATOMIC COMPONENTS

### A. Button System
*   **Primary Button (The Main Action):**
    *   *Dimensions:* Height: `56px`, Border Radius: `12px`.
    *   *Colors:* Background: solid `champagneGold` | Text Label: `obsidianNight`.
    *   *Rule:* No gradients. Press action triggers a scale transition down to `0.97` (with no ink/ripple effect).
*   **Secondary Button (Alternative Options):**
    *   *Dimensions:* Height: `56px` (or `44px` for secondary dialog options), Border Radius: `12px`.
    *   *Colors:* Background: `transparent` | Border: `1px solid champagneGold` | Text Label: `champagneGold`.
*   **Ghost Button (Muted/Dismiss Actions):**
    *   *Dimensions:* Height: `56px`, Border Radius: `12px`.
    *   *Colors:* Background: `transparent` | Border: `none` | Text Label: `pearlWhite`.

### B. Input System
*   **Text Field:**
    *   *Background:* `inputSurface` (rgba(255, 255, 255, 0.05)) fill.
    *   *Border:* `1px outline border` (`cardBorder`) by default.
    *   *Focus State:* Transitions to `2px solid champagneGold` outline border with a soft gold glow overlay.
    *   *Padding:* Horizontal padding `16px`, vertical padding `16px` (adjusts to `20px` for single-line inputs).
*   **OTP Verification Field:**
    *   *Layout:* 6 distinct input boxes aligned horizontally with spacing.
    *   *Styles:* Full underline border. Muted `slateMist` when inactive, turning to `champagneGold` on focus. Large text (`24px` Playfair Display style) showing entered digit or a bullet placeholder (`·`).

### C. SILARAH Profile Card (The Discovery Engine)
*   *Ratio:* `3:4` Portrait container.
*   *Edges:* `24px` corner radius with `1px cardBorder`.
*   *Overlay:* Vertical gradient starting at top (transparent) through middle (`30% obsidian`) to bottom (`100% obsidian`) to guarantee white text readability.
*   *Layout:* User details (Name in `Playfair Display 24px`, Location in `Inter 14px`) positioned at the bottom left with verified indicators and badge counters.

### D. Skeleton Loaders (Shimmer)
*   *Animation:* Smooth left-to-right linear transition using a gradient (from `slateMist` to `obsidianNight`).
*   *Duration:* `1500ms` cycle.

---

## 6. MOTION MANIFESTO & TRANSITIONS
Linear movements are strictly forbidden; all motion must mimic real-world inertia.

*   **"The Reveal" (Ease Out Cubic):**
    *   *Duration:* `250ms` (internally scales up to `500ms` for complex screen layouts).
    *   *Usage:* Entry of elements, bottom sheets rising.
*   **"The Transition" (Ease In Out Quart):**
    *   *Duration:* `180ms` (internally up to `300ms`).
    *   *Usage:* State changes, tab switching, and chip updates.
*   **"The Tactile Pop" (Ease Out Back / Elastic Out):**
    *   *Duration:* `350ms` (internally up to `800ms`).
    *   *Usage:* Micro-interactions like bookmarks, checking boxes, or verified badges.
*   **Button Press Scale:**
    *   *Duration:* `100ms`.
    *   *Action:* Snappy scale reduction down to `0.97` on press, returning to `1.0` on release.
*   **The "Unfolding" Page Transition:**
    *   *Duration:* `250ms`.
    *   *Action:* Screen entry fades from `0` to `1` opacity while moving upward from `Offset(0, 0.02)` (approx. 10–20px shift) to `Offset.zero`.

### The Interest Ceremony ("The Magic Moment")
This is a custom-animated dialog overlay that dims the background to `80% opacity black` and plays the following timeline sequence:
1.  **0-400ms:** Gold ring at the center expands from radius `0` to `60px` (Ease Out Cubic) + light haptic vibration.
2.  **200-500ms:** Ring fades out (opacity `1` → `0`).
3.  **200-600ms:** 6 gold particles spawn at center and burst outward `80px` in a circular shape + fade out.
4.  **400-700ms:** Gold checkmark draws itself in the center (Segment 1 completes at 35% progress, Segment 2 completes at 100%) + medium haptic vibration.
5.  **700-1000ms:** Text tagline *"May Allah bless this with goodness"* fades in below.
6.  **1800-2100ms:** Entire overlay fades out and closes.

---

## 7. DESIGN "HARD RULES"
*   **NO Pure Black:** Always use `obsidianNight` (`#0A0A0F`) to keep depth.
*   **NO Pill-Shaped Buttons:** Always use the `12px` rounded rectangle.
*   **NO Heavy Drop Shadows:** Fills are kept near-invisible; definition comes from sharp `1px` borders.
*   **NO Generic Bold Icons:** Icons should be thin-stroke, minimalist (Phosphor/Lucide style) with medium size (`20px`) or large size (`24px`).
*   **NO Pop-ups / Dialog Alerts:** For user choices, always slide modal Bottom Sheets up from the bottom with `Reveal` curves.
*   **NO Button Gradients:** Primary actions are solid `champagneGold` with dark text. Muted secondary actions use borders.
