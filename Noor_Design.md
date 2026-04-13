This is the NOOR Design Blueprint.

To ensure this doesn't feel like a "coded app" or a "generic template," we are following the philosophy of Quiet Luxury. Premium design is not about adding gold glitter and sparkles; it is about precision, whitespace, and restraint.

If a dating app is a "neon-lit club," NOOR is a "private gallery."

MODULE 1: THE DESIGN DNA (The Foundation)
1. The "Quiet Luxury" Color Palette

We avoid "Trophy Gold" (which looks cheap). We use muted, deep, and sophisticated tones.

Primary Palette (Dark Mode Default)

Obsidian Night (#0A0A0F): The main background. Not pure black, but a deep midnight blue-black. This creates depth and feels expensive.

Champagne Gold (#C5A059): The accent color. Used sparingly for CTAs, verified badges, and the "Interest Ceremony." It represents light and value.

Pearl White (#F5F5F7): Primary text. A soft, muted white (Apple-style) to reduce eye strain and feel softer than stark white.

Slate Mist (#8E8E93): Secondary text. Used for labels, muted info, and hints.

Surface & Semantic

Surface Glass (rgba(255, 255, 255, 0.05)): Used for cards and overlays to create a "glassmorphism" effect.

Verified Teal (#2DCDA9): A muted teal, not neon green, for verification badges.

Soft Coral (#E67E7E): A dignified error color, not a harsh red.

2. The Typography System (The "Editorial" Feel)

We use a Font Pairing strategy to make the app feel like a high-end magazine or a wedding invitation.

The Heading Font: Playfair Display (Serif)

Vibe: Prestigious, timeless, elegant.

Usage: User names, Screen titles, "Bismillah" tagline, Bios (Italic).

Weight: Semi-Bold (600) or Bold (700).

The Body Font: Inter or Plus Jakarta Sans (Geometric Sans-Serif)

Vibe: Modern, clean, professional.

Usage: Bios, labels, settings, chat messages.

Weight: Regular (400) for body, Medium (500) for labels.

Typography Scale
| Element | Font | Size | Weight | Letter Spacing | Color |
| :--- | :--- | :--- | :--- | :--- | :--- |
| Screen Title | Playfair | 28px | Bold | 0.5px | Pearl White |
| User Name | Playfair | 24px | SemiBold | 0.2px | Pearl White |
| Section Label| Inter | 11px | Medium | 1.5px (UPPER) | Slate Mist |
| Body Text | Inter | 15px | Regular | 0.0px | Pearl White |
| Bio (Italic) | Playfair | 17px | Italic | 0.0px | Pearl White |

3. Geometry & Space (The "Breath")

The Grid: Standard 24px horizontal margin. Premium apps use whitespace as a feature.

Corner Radius:

Large Cards: 24px (Soft, modern).

Buttons/Inputs: 12px (Professional. NO pill-shapes, which look too casual/social media).

The Shadows: Zero heavy shadows. No black blur. Instead, use a 1px border of rgba(255, 255, 255, 0.1) on cards. This creates a "sharp" edge that feels high-end.

MODULE 2: ATOMIC COMPONENTS
1. The Button System

A. Primary Button (The Action)

BG: Champagne Gold (#C5A059) | Text: Obsidian Night (#0A0A0F).

Radius: 12px | Height: 56px.

Effect: Subtle scale down (0.97) on press. No ripple effect.

B. Secondary Button (The Alternative)

BG: Transparent | Border: 1px solid #C5A059.

Text: Champagne Gold (#C5A059).

C. Ghost Button (The Quiet Action)

BG: Transparent | Border: None.

Text: Pearl White (#F5F5F7).

2. The "NOOR Card" (The Discovery Engine)

The most critical component. It must look like a luxury portfolio cover.

Ratio: 3:4 Portrait.

Border: 1px solid rgba(255, 255, 255, 0.1).

Gradient Overlay: A multi-stop gradient from Transparent (Top) 
→
→
 30% Obsidian (Middle) 
→
→
 100% Obsidian (Bottom). This ensures white text is readable over any photo.

Layout: Name (Playfair 24px) and Location (Inter 14px) placed bottom-left.

3. The Input System

BG: Surface Glass (rgba(255, 255, 255, 0.05)).

Border: Bottom border only (1px solid Slate Mist).

Focus State: Bottom border transitions to 2px Champagne Gold.

MODULE 3: SCREEN-BY-SCREEN SPEC
1. The Onboarding Journey

Vibe: A calm conversation, not a form.

Layout: Background: Obsidian Night. A thin 2px progress bar at the top (Slate Mist 
→
→
 fills with Gold).

The Splash: The Arabic letterform (نور) glows in the center. Background has a subtle radial gradient (#1A1A2F 
→
→
 #0A0A0F).

2. The Discovery Feed

The Motion: As the user scrolls, the center card is scale: 1.0 and cards above/below are scale: 0.95. This creates a "Focus" effect.

Header: Playfair wordmark "NOOR" centered. Thin-stroke icons (Lucide/Phosphor).

3. Profile Detail (The Portfolio)

Hero Section: Photo takes up 55% of the screen.

Parallax: As the user scrolls up, the photo moves at 0.5x speed, content moves at 1.0x.

Bio: Playfair Display, Italic, 17px, with wide line-height (1.6) to feel like a handwritten letter.

4. The Interest Ceremony (The Magic Moment)

This is not a screen; it is an Event.

The Dim: Screen dims to rgba(0,0,0,0.8).

The Animation: A gold ring expands from the center 
→
→
 shatters into 6 gold particles 
→
→
 a checkmark draws itself.

The Text: "May Allah bless this with goodness" fades in.

The Haptics: Light tap on ring expansion 
→
→
 Medium tap on checkmark.

5. Conversations

Bubbles:

Sender: Surface Glass with a thin Gold border.

Receiver: Soft muted grey-black.

Input: Minimalist field. No "Send" button—only a Gold arrow icon that appears when typing starts.

MODULE 4: THE MOTION MANIFESTO

No linear animations. Everything must have weight and momentum.

1. The Core Easing

The "Reveal" (Curves.easeOutCubic): For elements entering the screen. Fast start, soft landing. (300-500ms).

The "Transition" (Curves.easeInOutQuart): For state changes (e.g., chip color). (200-300ms).

The "Tactile Pop" (Curves.elasticOut): For micro-interactions (heart icon, checkmark). (600-800ms).

2. Global Transitions

The "Unfolding" Effect: Instead of a standard slide-in, new screens fade in (opacity 0 $\rightarrow$ 1) while simultaneously shifting upwards (offset 20px $\rightarrow$ 0px).

3. Micro-Interactions

Button Press: Scale 1.0 
→
→
 0.97 
→
→
 1.0 (100ms). Feels like a physical button.

Chip Selection: Scale 1.0 
→
→
 1.05 
→
→
 1.0.

Loading: No spinning wheels. Use Shimmer Effects (Slate Mist 
→
→
 Obsidian Night gradient moving left to right).

DESIGN "HARD RULES" (To prevent the mess)

NO Pure Black: Always use Obsidian Night (#0A0A0F).

NO Pill-Shaped Buttons: Use the 12px rounded rectangle.

NO Heavy Shadows: Use 1px borders.

NO Generic Icons: Use thin-stroke icons only.

NO Pop-ups: Use Bottom Sheets that slide up with Curves.easeOutCubic.

NO Gradients in Buttons: Use solid Champagne Gold.