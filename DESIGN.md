---
name: LingoRoad Design System
colors:
  surface: '#fbf9f9'
  surface-dim: '#dbdad9'
  surface-bright: '#fbf9f9'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#f5f3f3'
  surface-container: '#efeded'
  surface-container-high: '#e9e8e7'
  surface-container-highest: '#e3e2e2'
  on-surface: '#1b1c1c'
  on-surface-variant: '#5c403a'
  inverse-surface: '#303031'
  inverse-on-surface: '#f2f0f0'
  outline: '#907068'
  outline-variant: '#e5beb5'
  surface-tint: '#b62400'
  primary: '#b22300'
  on-primary: '#ffffff'
  primary-container: '#da3711'
  on-primary-container: '#fffbff'
  inverse-primary: '#ffb4a3'
  secondary: '#5f5e5e'
  on-secondary: '#ffffff'
  secondary-container: '#e2dfde'
  on-secondary-container: '#636262'
  tertiary: '#5b5c5c'
  on-tertiary: '#ffffff'
  tertiary-container: '#737575'
  on-tertiary-container: '#fcfcfc'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#ffdad2'
  primary-fixed-dim: '#ffb4a3'
  on-primary-fixed: '#3d0600'
  on-primary-fixed-variant: '#8b1900'
  secondary-fixed: '#e5e2e1'
  secondary-fixed-dim: '#c8c6c5'
  on-secondary-fixed: '#1b1c1c'
  on-secondary-fixed-variant: '#474746'
  tertiary-fixed: '#e2e2e2'
  tertiary-fixed-dim: '#c6c6c7'
  on-tertiary-fixed: '#1a1c1c'
  on-tertiary-fixed-variant: '#454747'
  background: '#fbf9f9'
  on-background: '#1b1c1c'
  surface-variant: '#e3e2e2'
typography:
  headline-xl:
    fontFamily: Hanken Grotesk
    fontSize: 32px
    fontWeight: '700'
    lineHeight: 40px
    letterSpacing: -0.02em
  headline-lg:
    fontFamily: Hanken Grotesk
    fontSize: 24px
    fontWeight: '700'
    lineHeight: 32px
  headline-md:
    fontFamily: Hanken Grotesk
    fontSize: 20px
    fontWeight: '600'
    lineHeight: 28px
  body-lg:
    fontFamily: Hanken Grotesk
    fontSize: 18px
    fontWeight: '400'
    lineHeight: 28px
  body-md:
    fontFamily: Hanken Grotesk
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
  label-lg:
    fontFamily: Hanken Grotesk
    fontSize: 14px
    fontWeight: '600'
    lineHeight: 20px
    letterSpacing: 0.01em
  label-sm:
    fontFamily: Hanken Grotesk
    fontSize: 12px
    fontWeight: '500'
    lineHeight: 16px
  headline-lg-mobile:
    fontFamily: Hanken Grotesk
    fontSize: 22px
    fontWeight: '700'
    lineHeight: 28px
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  base: 4px
  xs: 8px
  sm: 12px
  md: 16px
  lg: 24px
  xl: 32px
  margin-mobile: 20px
  gutter-mobile: 16px
---

## Brand & Style
The design system is engineered to create a focused, high-energy learning environment for Vietnamese students. The brand personality is **Professional yet Approachable**, bridging the gap between serious education and casual daily habit. 

The visual style is **Corporate / Modern** with a friendly lean, utilizing a flat aesthetic that prioritizes content clarity over decorative flair. By avoiding gradients and complex textures, the UI ensures maximum legibility and fast scanning—critical for language learners who may be processing unfamiliar vocabulary. The emotional response should be one of confidence, momentum, and clarity.

## Colors
The palette is built on a high-contrast foundation to facilitate one-handed mobile use. 
- **Primary (#F24822):** Derived from the logo, this energetic orange-red is reserved for the most critical actions (CTAs), progress highlights, and interactive states.
- **Surface:** A pure white (#FFFFFF) background provides a sterile, distraction-free canvas for learning.
- **Typography:** Deep Charcoal/Black (#212121) is used for body text and headers to ensure AA/AAA accessibility compliance.
- **Accents:** A soft Neutral Grey (#F5F5F5) is used for secondary card backgrounds and input fields to maintain visual hierarchy without adding noise.

## Typography
This design system utilizes **Hanken Grotesk** for its precise yet soft geometric forms, which feel modern and inviting. 

The type scale is intentionally generous to accommodate Vietnamese diacritics without crowding. Headlines use a bold weight to anchor the page, while body text remains at a minimum of 16px to ensure readability on mobile devices. Letter spacing is slightly tightened for large headlines and slightly opened for small labels to maintain legibility across all scales.

## Layout & Spacing
The layout follows a **Fluid Grid** model optimized for vertical mobile scrolling. 
- **Grid:** A 4-column layout for mobile with 20px outer margins and 16px gutters.
- **Rhythm:** An 8pt linear scaling system is used for all internal component padding and vertical rhythm (8, 16, 24, 32).
- **Safe Areas:** Generous bottom padding is applied to all screens to ensure primary action buttons remain clear of the device's home indicator and are easily reachable with the thumb.

## Elevation & Depth
Depth is conveyed through **Tonal Layers** and extremely **Ambient Shadows**. 
- **Surface:** The base layer is pure white.
- **Cards:** Elevated elements use a subtle shadow (0px 4px 12px, 4% opacity black) to separate them from the background without creating visual clutter.
- **Interactive:** Active or pressed states do not use shadows but rather a subtle scale-down (98%) or a slight shift in background tint to maintain the "flat" design philosophy.
- **Logo Context:** On screens where the logo requires high impact, a solid dark background (#212121) is used as a container to make the orange-red mark pop.

## Shapes
The shape language is defined as **Rounded**, balancing professional structure with friendly approachability. 
- **Standard UI (Inputs/Buttons):** 8px (0.5rem) radius for a modern feel.
- **Container UI (Cards):** 24px (1.5rem) radius to create a soft, welcoming container for lesson content.
- **Status/Chips:** Pill-shaped (full radius) for quick visual categorization.

## Components
- **Buttons:** Primary buttons use the #F24822 background with white text, 16px vertical padding, and bold labels. Secondary buttons use a #F5F5F5 background with charcoal text.
- **Cards:** Large 24px corner radius. They should include 24px internal padding to ensure content feels focused and breathable.
- **Input Fields:** 8px radius with a 1px #E0E0E0 border. On focus, the border transitions to 2px primary orange-red.
- **Chips:** Small, pill-shaped tags used for categories (e.g., "Grammar", "Vocabulary"). Use light gray backgrounds with dark text.
- **Progress Bars:** Use a thick 8px height with fully rounded ends. The track is light gray, and the progress fill is the primary orange-red.
- **Icons:** 24px bounding box, 2px stroke weight, line-based style. Ensure consistent rounded caps and joins to match the typography.